# frozen_string_literal: true

require 'deep_merge'

#-----------------------------------------------------------------------
# Transform the results from generic CSV-to-Popolo into EP-Popolo
#
#   - remove all Executive Memberships
#   - remove duplicated names
#   - merge legislature data from meta.json
#     - ensure all legislative memberships are on that
#   - merge term data from terms.csv
#-----------------------------------------------------------------------
namespace :transform do
  file POPOLO_JSON => :write
  CLEAN.include(POPOLO_JSON, 'final.json')

  task load: MERGED_JSON do
    @json = JSON.parse(MERGED_JSON.read, symbolize_names: true)
  end

  task :write do
    popolo_write(POPOLO_JSON, @json)
  end

  #---------------------------------------------------------------------
  # Rule: There must be a single legislature
  #---------------------------------------------------------------------
  task write: :ensure_legislature
  task ensure_legislature: :load do
    # Clean out legislative memberships
    @json[:memberships].delete_if { |m| m[:organization_id] == 'executive' }
    @json[:organizations].delete_if { |h| h[:classification] == 'executive' }

    legis = @json[:organizations].select { |h| h[:classification] == 'legislature' }
    raise "Legislature count = #{legis.count}" unless legis.count == 1

    @legislature = legis.first

    # Remake 'chamber' memberships to the full legislature
    @json[:organizations].select { |h| h[:classification] == 'chamber' }.each do |c|
      @json[:memberships].select { |m| m[:organization_id] == c[:id] }.each do |m|
        m[:organization_id] = @legislature[:id]
      end
    end
    @json[:organizations].delete_if { |h| h[:classification] == 'chamber' }
  end

  #---------------------------------------------------------------------
  # Set legislature data from meta.json file
  #---------------------------------------------------------------------
  task write: :name_legislature
  task name_legislature: :ensure_legislature do
    raise 'No meta.json file available' unless LEGISLATURE_META.exist?

    meta_info = json_load(LEGISLATURE_META)
    @legislature.merge! meta_info
    if @legislature.key?(:wikidata)
      (@legislature[:identifiers] ||= []) << {
        scheme:     'wikidata',
        identifier: @legislature.delete(:wikidata),
      }
    end

    # Switch the legislature ID everywhere it's used
    @json[:memberships].select { |m| m[:organization_id] == @legislature[:id] }.each do |m|
      m[:organization_id] = @legislature[:uuid]
    end
    @json[:posts].select { |m| m[:organization_id] == @legislature[:id] }.each do |m|
      m[:organization_id] = @legislature[:uuid]
    end
    @legislature[:id] = @legislature.delete :uuid
  end

  #---------------------------------------------------------------------
  # Merge with terms.csv
  #---------------------------------------------------------------------
  task write: :merge_termfile
  task merge_termfile: :ensure_legislature do
    terms = @INSTRUCTIONS.sources_of_type('term')
                         .flat_map { |src| src.to_popolo[:events] }
                         .each { |t| t[:organization_id] = @legislature[:id] }
                         .group_by { |t| t[:id] }

    @json[:events].each do |e|
      csv_terms = terms[e[:id]] or abort "No term information for #{e[:id]}"
      e.merge! csv_terms.first
    end
  end

  #---------------------------------------------------------------------
  # Don't include term end dates until they actually happen
  #---------------------------------------------------------------------
  task write: :no_future_end_dates
  task no_future_end_dates: :merge_termfile do
    today = Date.today
    @json[:events].select { |e| e[:classification] == 'legislative period' }.each do |t|
      next unless t[:end_date]

      if t[:end_date].length == 4
        warn "Imprecise end date (#{t[:end_date]}) for term #{t[:name]}"
        t.delete :end_date unless t[:end_date].to_i < today.year.to_i
      else
        d = Date.parse(t[:end_date]) rescue nil
        t.delete :end_date unless d && d < Date.today
      end
    end
  end

  #---------------------------------------------------------------------
  # Don't duplicate start/end dates into memberships needlessly
  #   and ensure they're within the term
  #---------------------------------------------------------------------
  task write: :tidy_memberships
  task tidy_memberships: :no_future_end_dates do
    @json[:memberships].each do |m|
      abort "No 'term' in #{m}" if m[:legislative_period_id].to_s.empty?
      e = @json[:events].find { |e| e[:id] == m[:legislative_period_id] } or abort "#{m[:legislative_period_id]} is not a known term (in #{m})"

      m.delete :start_date if m[:start_date].to_s.empty? || (!e[:start_date].to_s.empty? && m[:start_date].to_s <= e[:start_date].to_s)
      m.delete :end_date   if m[:end_date].to_s.empty?   || (!e[:end_date].to_s.empty?   && m[:end_date].to_s   >= e[:end_date].to_s)
    end
    duplicates = @json[:memberships].group_by { |m| m }.select { |_, ms| ms.size > 1 }.map(&:first)
    if duplicates.any?
      duplicates.each do |dupe|
        warn "Discarding duplicate membership: #{dupe}".yellow
      end
      @json[:memberships].uniq!
    end
  end

  #---------------------------------------------------------------------
  # Rule: Only current members should have contact info
  #---------------------------------------------------------------------
  task write: :remove_old_contact_info
  task remove_old_contact_info: :tidy_memberships do
    active_terms = @json[:events].select { |e| e[:classification] == 'legislative period' }
                                 .reject { |e| e.key?(:end_date) }
                                 .map { |e| e[:id] }
                                 .to_set
    active_members = @json[:memberships].select { |m| active_terms.include? m[:legislative_period_id] }
                                        .reject { |m| m.key?(:end_date) }
                                        .map { |e| e[:person_id] }
                                        .to_set

    unwanted_types = %w[email phone fax cell].to_set
    @json[:persons].reject { |p| active_members.include? p[:id] }.each do |p|
      p.delete :email
      p[:contact_details]&.delete_if { |c| unwanted_types.include? c[:type] }
      p.delete(:contact_details) if p[:contact_details]&.empty?
    end
  end

  #---------------------------------------------------------------------
  # Don't duplicate `name` or `name__en` into multilingual
  #---------------------------------------------------------------------
  task write: :fallback_names
  task fallback_names: :area_wikidata do
    # TODO: remove these from parties / elections / terms etc. too
    (@json[:persons] + @json[:areas]).reject { |p| p[:other_names].to_a.empty? }.each do |p|
      skip = Set.new([p[:name].downcase]) + p[:other_names].select { |n| n[:lang] == 'en' }.map { |n| n[:name].downcase }
      p[:other_names].delete_if { |n| n[:lang] != 'en' && skip.include?(n[:name].downcase) }
      p[:other_names].delete_if { |n| n[:lang] == 'en' && n[:name].downcase == p[:name].downcase }
      p.delete(:other_names) if p[:other_names].empty?
    end
  end

  #---------------------------------------------------------------------
  # Rule: Legislative Memberships must have `on_behalf_of`
  #---------------------------------------------------------------------
  def unknown_party
    if unknown = @json[:organizations].find { |o| o[:classification] == 'party' && o[:name].downcase == 'unknown' }
      unknown[:id] = 'party/_unknown' if unknown[:id].to_s.empty?
      return unknown
    end
    unknown = {
      classification: 'party',
      name:           'Unknown',
      id:             'party/_unknown',
    }
    @json[:organizations] << unknown
    unknown
  end

  task write: :ensure_behalf_of
  task ensure_behalf_of: :ensure_legislature do
    leg_ids = @json[:organizations].select { |o| %w[legislature chamber].include? o[:classification] }.map { |o| o[:id] }
    @json[:memberships].select { |m| m[:role] == 'member' && leg_ids.include?(m[:organization_id]) }.each do |m|
      m[:on_behalf_of_id] = unknown_party[:id] if m[:on_behalf_of_id].to_s.empty?
    end
  end

  #---------------------------------------------------------------------
  # Rule: Areas should be first class, not just embedded
  #---------------------------------------------------------------------
  task write: :check_no_embedded_areas
  task check_no_embedded_areas: :ensure_legislature do
    raise 'Memberships should not have embedded areas' if @json[:memberships].any? { |m| m.key? :area }
  end

  #---------------------------------------------------------------------
  # Remap gender to consistent format
  #---------------------------------------------------------------------
  task write: :remap_gender
  GENDER_MAP = {
    'male'   => %w[m male homme],
    'female' => ['f', 'female', 'femme', 'transgender female'],
    'other'  => %w[o other],
  }.freeze

  task remap_gender: :load do
    remap = Hash[GENDER_MAP.flat_map { |k, vs| vs.map { |v| [v, k] } }]
    @json[:persons].each do |p|
      next if p[:gender].to_s.empty?

      p[:gender] = remap[p[:gender].downcase.strip] || raise("Unknown gender: #{p[:gender]}")
    end
  end

  #---------------------------------------------------------------------
  # Add Election information
  #---------------------------------------------------------------------
  task write: :election_info
  task election_info: :load do
    @INSTRUCTIONS.sources_of_type('wikidata-elections').each do |src|
      @json[:events] += src.to_popolo[:events]
    end
  end

  #---------------------------------------------------------------------
  # Merge area wikidata information
  #---------------------------------------------------------------------
  task write: :area_wikidata
  task area_wikidata: :load do
    @INSTRUCTIONS.sources_of_type('area-wikidata').each do |src|
      src.to_popolo[:areas].each do |area|
        @json[:areas].select do |a|
          a[:type] == 'constituency' &&
            a[:id].split('/').last == area[:id].split('/').last
        end.each do |existing|
          DeepMerge.deep_merge!(area, existing, preserve_unmergeables: true)
        end
      end
    end
  end

  #---------------------------------------------------------------------
  # Merge group wikidata information
  #---------------------------------------------------------------------
  task write: :group_wikidata

  task check_group_ids: :load do
    missing_ids = @json[:organizations].select { |o| o[:id].to_s.empty? }
    if missing_ids.any?
      raise 'Missing organization ID for "%s"' %
            missing_ids.map { |o| o[:name] }.join('", "')
    end
  end

  task group_wikidata: :check_group_ids do
    @INSTRUCTIONS.sources_of_type('group').each do |src|
      src.to_popolo[:organizations].each do |org|
        matched = @json[:organizations].select do |o|
          o[:classification] == 'party' &&
            o[:id].split('/').last.downcase == org[:id].split('/').last.downcase
        end
        warn "Party #{org[:id]} not in Popolo" unless matched.any?
        matched.each do |existing|
          existing.merge!(org) do |key, old, new|
            key == :id ? old : new
          end
        end
      end
    end
  end
end
