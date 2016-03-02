require 'sass'
require_relative '../lib/wikidata_lookup'
require_relative '../lib/matcher'
require_relative '../lib/reconciliation'
require_relative '../lib/fetcher'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

namespace :merge_sources do

  task :fetch_missing do
    fetch_missing
  end

  desc "Combine Sources"
  task 'sources/merged.csv' => :fetch_missing do
    combine_sources
  end

  @recreatable = instructions(:sources).find_all { |i| i.key? :create }
  CLOBBER.include FileList.new(@recreatable.map { |i| i[:file] })

  CLEAN.include 'sources/merged.csv'

  def _should_refetch(file)
    return true unless File.exist?(file)
    return false unless ENV['REBUILD_SOURCE']
    return file.include? ENV['REBUILD_SOURCE']
  end

  def fetch_missing
    @recreatable.each do |i|
      if _should_refetch(i[:file])
        c = i[:create]
        if c.key? :url
          Fetcher::URL.regenerate(i)
        elsif c[:type] == 'morph'
          Fetcher::Morph.regenerate(i)
        elsif c[:type] == 'parlparse'
          Fetcher::Parlparse.regenerate(i)
        elsif c[:type] == 'ocd'
          Fetcher::OCD.regenerate(i)
        elsif c[:type] == 'group-wikidata'
          Fetcher::Wikidata::Group.regenerate(i)
        elsif c[:type] == 'area-wikidata'
          Fetcher::Wikidata::Area.regenerate(i)
        elsif c[:type] == 'wikidata-raw'
          Fetcher::Wikidata::Raw.regenerate(i)
        elsif c[:type] == 'gender-balance'
          Fetcher::GenderBalance.regenerate(i)
        else
          raise "Don't know how to fetch #{i[:file]}" unless c[:type] == 'morph'
        end
      end
    end
  end

  REMAP = {
    area: %w(constituency region district place),
    area_id: %w(constituency_id region_id district_id place_id),
    biography: %w(bio blurb),
    birth_date: %w(dob date_of_birth),
    blog: %w(weblog),
    cell: %w(mob mobile cellphone),
    chamber: %w(house),
    death_date: %w(dod date_of_death),
    end_date: %w(end ended until to),
    executive: %w(post),
    family_name: %w(last_name surname lastname),
    fax: %w(facsimile),
    gender: %w(sex),
    given_name: %w(first_name forename),
    group: %w(party party_name faction faktion bloc block org organization organisation),
    group_id: %w( party_id faction_id faktion_id bloc_id block_id org_id organization_id organisation_id),
    image: %w(img picture photo photograph portrait),
    name: %w(name_en),
    patronymic_name: %w(patronym patronymic),
    phone: %w(tel telephone),
    source: %w(src),
    start_date: %w(start started from since),
    term: %w(legislative_period),
    website: %w(homepage href url site),
  }.each_with_object({}) { |(k, vs), mapped| vs.each { |v| mapped[v] = k } }

  def remap(str)
    REMAP[str.to_s] || str.to_sym
  end

  # http://codereview.stackexchange.com/questions/84290/combining-csvs-using-ruby-to-match-headers
  def combine_sources

    # Make sure all instructions have a `type`
    if (no_type = instructions(:sources).find { |src| src[:type].to_s.empty? })
      raise "Missing `type` in #{no_type} file"
    end

    # Build the master list of columns
    all_headers = instructions(:sources).find_all { |src|
      src[:type] != 'term'
    }. map { |src| src[:file] }.reduce([]) do |all_headers, file|
      header_line = File.open(file, &:gets)
      all_headers | CSV.parse_line(header_line).map { |h| remap(h.downcase) }
    end
    all_headers |= [:id]

    merged_rows = []

    # First get all the `membership` rows, and either merge or concat

    instructions(:sources).find_all { |src| src[:type].to_s.downcase == 'membership' }.each do |src|
      file = src[:file]
      puts "Add memberships from #{file}".magenta
      ids_file = file.sub(/.csv$/, '-ids.csv')
      id_map = {}
      if File.exists?(ids_file)
        id_map = Hash[CSV.table(ids_file, converters: nil).map { |r| [r[:id], r[:uuid]] }]
      end
      table = csv_table(file)

      # if we have any filters, apply them
      # Currently we just recognise a hash of k:v pairs to accept if matching
      # TODO: add 'reject' and more complex expressions
      filter = src.key?(:filter) ? ->(row) { src[:filter][:accept].all? { |k, v| row[k] == v } } : nil

      incoming_data = table.map do |row|
        next if filter and not filter.call(row)
        # If the row has no ID, we'll need something we can treate as one
        # This 'pseudo id' defaults to slugified 'name' unless provided 
        row[:id] ||= row[:name].downcase.gsub(/\s+/, '_') 
        row
      end.compact

      if merge_instructions = src[:merge]
        if merge_instructions.key? :reconciliation_file
          reconciliation_file = File.join('sources', merge_instructions[:reconciliation_file])
          previously_reconciled = File.exist?(reconciliation_file) ? CSV.table(reconciliation_file, converters: nil) : CSV::Table.new([])

          if ENV['GENERATE_RECONCILIATION_INTERFACE'] && reconciliation_file.include?(ENV['GENERATE_RECONCILIATION_INTERFACE'])
            html_file = reconciliation_file.sub('.csv', '.html')
            interface = Reconciliation::Interface.new(merged_rows, incoming_data.uniq { |r| r[:id] }, previously_reconciled, merge_instructions)
            FileUtils.mkdir_p(File.dirname(html_file))
            File.write(html_file, interface.html)
            abort "Created #{html_file} — please check it and re-run".green 
          end

          # If we have reconciliation data from a prior run, we can
          # use those IDs, otherwise we need to wait for reconciliation
          if previously_reconciled.any?
            previously_reconciled.each { |r| id_map[r[:id]] = r[:uuid] } 
          else 
            abort "No reconciliation data. Rerun with GENERATE_RECONCILIATION_INTERFACE=#{File.basename(reconciliation_file, '.csv')}"
          end
        else 
          abort "Don't know yet how to merge memberships without a reconciliation_file"
        end
      else
        # warn "No merge instructions — all new Memberships"
      end

      incoming_data.each do |row|
        # Assume that incoming data has no useful uuid column
        row[:uuid] = id_map[row[:id]] ||= SecureRandom.uuid
        merged_rows << row.to_hash
      end

      CSV.open(ids_file, 'w') do |csv|
        csv << [:id, :uuid]
        id_map.each { |id, uuid| csv << [id, uuid] }
      end
    end

    # Then merge with Person data files
    #   existing_field: the field in the existing data to match to
    #   incoming_field: the field in the incoming data to match with

    instructions(:sources).find_all { |src| %w(wikidata person).include? src[:type].to_s.downcase }.each do |pd|
      puts "Merging with #{pd[:file]}".magenta
      raise "No merge instructions" unless pd.key?(:merge)

      all_headers |= [:identifier__wikidata] if pd[:type] == 'wikidata'

      incoming_data = csv_table(pd[:file])

      approaches = pd[:merge].class == Hash ? [pd[:merge]] : pd[:merge]
      approaches.each_with_index do |merge_instructions, i|
        warn "  Match incoming #{merge_instructions[:incoming_field]} to #{merge_instructions[:existing_field]}"
        unless merge_instructions.key? :report_missing
          # By default only report people who are still unmatched at the end
          merge_instructions[:report_missing] = (i == approaches.size - 1)
        end

        if merge_instructions.key? :reconciliation_file
          reconciliation_file = File.join('sources', merge_instructions[:reconciliation_file])
          previously_reconciled = File.exist?(reconciliation_file) ? CSV.table(reconciliation_file, converters: nil) : CSV::Table.new([])

          if ENV['GENERATE_RECONCILIATION_INTERFACE'] && reconciliation_file.include?(ENV['GENERATE_RECONCILIATION_INTERFACE'])
            html_file = reconciliation_file.sub('.csv', '.html')
            interface = Reconciliation::Interface.new(merged_rows, incoming_data, previously_reconciled, merge_instructions)
            FileUtils.mkdir_p(File.dirname(html_file))
            File.write(html_file, interface.html)
            abort "Created #{html_file} — please check it and re-run".green 
          end

          # If we have reconciliation data from a prior run, we can
          # use that, otherwise we need to wait for reconciliation
          if previously_reconciled.any?
            matcher = Matcher::Reconciled.new(merged_rows, merge_instructions, previously_reconciled)
          else 
            abort "No reconciliation data. Rerun with GENERATE_RECONCILIATION_INTERFACE=#{File.basename(reconciliation_file, '.csv')}"
          end
        else 
          matcher = Matcher::Exact.new(merged_rows, merge_instructions)
        end

        unmatched = []
        incoming_data.each do |incoming_row|

          incoming_row[:identifier__wikidata] ||= incoming_row[:id] if pd[:type] == 'wikidata'

          # TODO factor this out to a Patcher again
          to_patch = matcher.find_all(incoming_row)
          if to_patch && !to_patch.size.zero?
            # Be careful to take a copy and not delete from the core list
            to_patch = to_patch.select { |r| r[:term].to_s == incoming_row[:term].to_s } if merge_instructions[:term_match]
            uids = to_patch.map { |r| r[:uuid] }.uniq
            if uids.count > 1
              warn "Error: trying to patch multiple people: #{uids.join('; ')}".red.on_yellow
              next
            end
            to_patch.each do |existing_row|
              # For now, only set values that are not already set (or are set to 'unknown')
              # TODO: have a 'clobber' flag (or list of values to trust the latter source for)
              incoming_row.keys.each do |h|
                existing_row[h] = incoming_row[h] if existing_row[h].to_s.empty? || existing_row[h].to_s.downcase == 'unknown'
              end

              # If the incoming data, however, has a different "name"
              # field, attach that as an alternate in `other_names`
              if (incoming_row[:name].to_s.downcase != existing_row[:name].to_s.downcase) && !incoming_row[:name].to_s.strip.empty? 
                all_headers |= [:alternate_names] 
                existing_row[:alternate_names] ||= nil
                existing_row[:alternate_names] = [existing_row[:alternate_names], incoming_row[:name]].compact.join(";")
              end
            end
          else
            warn "Can't match row to existing data: #{incoming_row.to_hash.reject { |k,v| v.to_s.empty? } }".red if merge_instructions[:report_missing]
            unmatched << incoming_row
          end
        end
        puts "* %d of %d unmatched".magenta % [unmatched.count, incoming_data.count]
        incoming_data = unmatched
      end
    end

    # Gender information from Gender-Balance.org
    if gb = instructions(:sources).find { |src| src[:type].to_s.downcase == 'gender' }
      min_selections = 5   # accept gender if at least this many votes
      vote_threshold = 0.8 # and at least this ratio of votes were for it

      gender = CSV.table(gb[:file], converters: nil).group_by { |r| r[:uuid] }
      gb_votes = Set.new

      # Only calculate the gender if we don't already have it
      # TODO: warn if the GB data differs from the pre-existing version
      merged_rows.each do |r|
        votes = (gender[ r[:uuid] ] or next).first
        next if votes[:total].to_i < min_selections
        winner = votes.reject { |k, _| %i(uuid total).include? k }.find { |k, v| (v.to_f / votes[:total].to_f) > vote_threshold } or begin
          warn "Unclear gender vote pattern: #{votes.to_hash}"
          next
        end
        next if winner.first == :skip
        if !r[:gender].to_s.empty? && r[:gender] != winner.first.to_s
          warn "Gender difference for #{r[:name]} (#{r[:uuid]}) — source: #{r[:gender]} | GB: #{winner.first.to_s}"
        end
        r[:gender] = winner.first.to_s 
        gb_votes.add r[:uuid]
      end
      puts "⚥ #{gb_votes.count}".cyan 
    end

    # Map Areas
    if area = instructions(:sources).find { |src| src[:type].to_s.downcase == 'area' }
      ocds = CSV.table(area[:file], converters: nil).group_by { |r| r[:id] }

      all_headers |= [:area, :area_id]

      if area[:generate] == 'area'
        merged_rows.each do |r|
          r[:area] = ocds[r[:area_id]].first[:name] rescue nil
        end

      else
        # Generate IDs from names
        # So far only tested with Australia, so super-simple logic.
        # TOOD: Expand this later

        fuzzer = FuzzyMatch.new(ocds.values.flatten(1), read: :name)
        finder = ->(r) { fuzzer.find(r[:area], must_match_at_least_one_word: true) }

        override = ->(name) {
          return unless area[:merge].key? :overrides
          return unless override_id = area[:merge][:overrides][name.to_sym]
          return '' if override_id.empty?
          binding.pry
          # FIXME look up in Hash instead
          # ocds.find { |o| o[:id] == override_id } or raise "no match for #{override_id}"
        }

        areas = {}
        merged_rows.each do |r|
          raise "existing Area ID: #{r[:area_id]}" if r.key? :area_id
          unless areas.key? r[:area]
            areas[r[:area]] = override.(r[:area]) || finder.(r)
            if areas[r[:area]].to_s.empty?
              warn "No area match for #{r[:area]}"
            else
              warn "Matched Area %s to %s" % [ r[:area].to_s.yellow, areas[r[:area]][:name].to_s.green ] unless areas[r[:area]][:name].include? " #{r[:area]} "
            end
          end
          next if areas[r[:area]].to_s.empty?
          r[:area_id] = areas[r[:area]][:id]
        end
      end
    end

    # Any local corrections in manual/corrections.csv
    corrections_file = 'sources/manual/corrections.csv'
    if File.exist? corrections_file
      CSV.table(corrections_file, converters: nil).each do |correction|
        rows = merged_rows.select { |r| r[:uuid] == correction[:uuid] } 
        if rows.empty?
          warn "Can't correct #{correction[:uuid]} — no such person"
          next
        end

        field = correction[:field].to_sym
        rows.each do |row|
          unless row[field] == correction[:old]
            warn "Can't correct #{correction[:uuid]}: #{field} is '#{row[field]} not '#{correction[:old]}'"
            next
          end
          row[field] = correction[:new]
        end
      end
    end


    legacy_id_file = 'sources/manual/legacy-ids.csv'
    if File.exist? legacy_id_file
      legacy = CSV.table(legacy_id_file, converters: nil).group_by { |r| r[:id] }

      all_headers << :identifier__everypolitician_legacy

      merged_rows.each do |row|
        if legacy.key? row[:uuid] 
          # TODO: row[:identifier__everypolitician_legacy] = legacy[ row[:uuid ] ].map { |i| i[:legacy] }.join ";"
          row[:identifier__everypolitician_legacy] = legacy[ row[:uuid ] ].first[:legacy] 
        end
      end
    end

    # No matter what 'id' columns we had, use the UUID as the final ID
    merged_rows.each { |row| row[:id] = row[:uuid] }

    # Then write it all out
    CSV.open("sources/merged.csv", "w") do |out|
      out << all_headers
      merged_rows.each { |r| out << all_headers.map { |header| r[header.to_sym] } }
    end

  end

end
