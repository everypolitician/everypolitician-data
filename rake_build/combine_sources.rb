require 'sass'
require_relative '../lib/wikidata_lookup'
require_relative '../lib/matcher'
require_relative '../lib/reconciliation'
require_relative '../lib/remotesource'
require_relative '../lib/source'

class OcdId
  attr_reader :ocd_ids
  attr_reader :overrides
  attr_reader :area_ids

  def initialize(ocd_ids, overrides, fuzzy)
    @ocd_ids = ocd_ids
    @overrides = overrides
    @fuzzy = fuzzy
    @area_ids = {}
  end

  def from_name(name)
    area_ids[name] ||= area_id_from_name(name)
  end

  private

  def area_id_from_name(name)
    area = override(name) || finder(name)
    return if area.nil?
    warn "  Matched Area %s to %s" % [ name.yellow, area[:name].to_s.green ] unless area[:name].include? " #{name} "
    area[:id]
  end

  def override(name)
    override_id = overrides[name]
    return if override_id.nil?
    { name: name, id: override_id }
  end

  def finder(name)
    if fuzzy?
      fuzzer.find(name.to_s, must_match_at_least_one_word: true)
    else
      ocd_ids.find { |i| i[:name] == name }
    end
  end

  def fuzzy?
    @fuzzy
  end

  def fuzzer
    @fuzzer ||= FuzzyMatch.new(ocd_ids, read: :name)
  end
end

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

  # We re-fetch any file that is missing, or, if REBUILD_SOURCE is set,
  # any file that matches that.
  def _should_refetch(file)
    return true unless File.exist?(file)
    return false unless ENV['REBUILD_SOURCE']
    return file.include? ENV['REBUILD_SOURCE']
  end

  def fetch_missing
    @recreatable.each do |i|
      RemoteSource.instantiate(i).regenerate if _should_refetch(i[:file])
    end
  end

  @warnings = Set.new
  def warn_once(str)
    @warnings << str
  end

  def output_warnings(header)
    warn ['', header, @warnings.to_a, '', ''].join("\n") if @warnings.any?
    @warnings = Set.new
  end

  # http://codereview.stackexchange.com/questions/84290/combining-csvs-using-ruby-to-match-headers
  def combine_sources

    # Make sure all instructions have a `type`
    if (no_type = instructions(:sources).find { |src| src[:type].to_s.empty? })
      raise "Missing `type` in #{no_type} file"
    end

    sources = instructions(:sources).map { |s| Source::Base.instantiate(s) }
    all_headers = (%i(id uuid) + sources.map { |s| s.fields }).flatten.uniq

    merged_rows = []

    # First get all the `membership` rows, and either merge or concat
    sources.select(&:is_memberships?).each do |src|
      warn "Add memberships from #{src.filename}".green
      
      incoming_data = src.as_table
      id_map = src.id_map

      if merge_instructions = src.merge_instructions.first
        reconciler = Reconciler.new(merge_instructions)
        raise "Can't reconciler memberships with a Reconciliation file yet" unless reconciler.filename

        if ENV['GENERATE_RECONCILIATION_INTERFACE'] && reconciler.triggered_by?(ENV['GENERATE_RECONCILIATION_INTERFACE'])
          filename = reconciler.generate_interface!(merged_rows, incoming_data.uniq { |r| r[:id] })
          abort "Created #{filename} — please check it and re-run".green 
        end

        pr = reconciler.previously_reconciled
        abort "No reconciliation data. Rerun with GENERATE_RECONCILIATION_INTERFACE=#{reconciler.trigger_name}" if pr.empty?
        pr.each { |r| id_map[r[:id]] = r[:uuid] } 
      end

      incoming_data.each do |row|
        # Assume that incoming data has no useful uuid column
        row[:uuid] = id_map[row[:id]] ||= SecureRandom.uuid
        merged_rows << row.to_hash
      end

      src.write_id_map_file! id_map
    end

    # Then merge with Biographical data files

    sources.select(&:is_bios?).each do |src|
      warn "Merging with #{src.filename}".green

      incoming_data = src.as_table

      abort "No merge instructions for #{src.filename}" if (approaches = src.merge_instructions).empty?
      if merge_instructions = approaches.first
        reconciler = Reconciler.new(merge_instructions)

        if reconciler.filename
          if ENV['GENERATE_RECONCILIATION_INTERFACE'] && reconciler.triggered_by?(ENV['GENERATE_RECONCILIATION_INTERFACE'])
            filename = reconciler.generate_interface!(merged_rows, incoming_data.uniq { |r| r[:id] })
            abort "Created #{filename} — please check it and re-run".green 
          end

          pr = reconciler.previously_reconciled
          abort "No reconciliation data. Rerun with GENERATE_RECONCILIATION_INTERFACE=#{reconciler.trigger_name}" if pr.empty?
          matcher = Matcher::Reconciled.new(merged_rows, merge_instructions, pr)
        else 
          matcher = Matcher::Exact.new(merged_rows, merge_instructions)
        end

        unmatched = []
        incoming_data.each do |incoming_row|

          incoming_row[:identifier__wikidata] ||= incoming_row[:id] if src.i(:type) == 'wikidata'

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
              # In general, we take the first value we see — other than short dates
              # TODO: have a 'clobber' flag (or list of values to trust the latter source for)

              to_ignore = (merge_instructions[:patch] || {})[:ignore].to_a.map(&:to_sym).to_set
              incoming_row.keys.reject { |h| h == :id || to_ignore.include?(h) }.each do |h|
                next if incoming_row[h].to_s.empty?

                # If we didn't have anything before, take the new version
                if existing_row[h].to_s.empty? || existing_row[h].to_s.downcase == 'unknown'
                  existing_row[h] = incoming_row[h] 
                  next
                end

                # These are _expected_ to be different on a term-by-term basis
                next if %i(term group group_id area area_id).include? h

                # Can't do much yet with these ones…
                next if %i(source given_name family_name).include? h

                # Accept multiple values for multi-lingual names
                if h.to_s.start_with? 'name__'
                  existing_row[h] += ";" + incoming_row[h]
                  next
                end

                # TODO accept multiple values for :website, etc.
                next if %i(website).include? h

                # Accept values from multiple sources for given fields
                if %i(email twitter facebook image).include? h
                  existing_row[h] = [existing_row[h], incoming_row[h]].join(';').split(';').map(&:strip).uniq(&:downcase).join(';')
                  next
                end

                # If we have the same as before (case insensitively), that's OK
                next if existing_row[h].downcase == incoming_row[h].downcase

                # Accept more precise dates
                if h.to_s.include?('date') 
                  if incoming_row[h].include?(existing_row[h])
                    existing_row[h] = incoming_row[h] 
                    next
                  end
                  # Ignore less precise dates
                  next if existing_row[h].include?(incoming_row[h])
                end

                # Store alternate names for `other_names`
                if h == :name
                  all_headers |= [:alternate_names] 
                  existing_row[:alternate_names] ||= nil
                  existing_row[:alternate_names] = [existing_row[:alternate_names], incoming_row[:name]].compact.join(";")
                  next
                end

                warn_once "  ☁ Mismatch in #{h} for #{existing_row[:uuid]} (#{existing_row[h]}) vs #{incoming_row[h]} (for #{incoming_row[:id]})"
              end

            end
          else
            unmatched << incoming_row
          end
        end

        warn "* %d of %d unmatched".magenta % [unmatched.count, incoming_data.count] if unmatched.any?
        unmatched.sample(10).each do |r|
          warn "\t#{r.to_hash.reject { |k,v| v.to_s.empty? }.select { |k, v| %i(id name).include? k } }"
        end 
        output_warnings("Data Mismatches")
        incoming_data = unmatched
      end
    end

    # Gender information from Gender-Balance.org
    if gb = sources.find { |src| src.type.downcase == 'gender' }
      warn "Adding GenderBalance results from #{gb.filename}".green 

      min_selections = 5   # accept gender if at least this many votes
      vote_threshold = 0.8 # and at least this ratio of votes were for it

      gb_votes = gb.as_table.reject { |r| (r[:total] -= r[:skip]) < min_selections }.group_by { |r| r[:uuid] }
      gb_score = 0
      gb_added = 0

      merged_rows.group_by { |r| r[:uuid] }.select { |id, rs| gb_votes.key? id }.each do |id, rs|
        r = rs.first
        votes = gb_votes[id].first

        # Has something score at least 80% of votes?
        winner = %w(male female other).find { |g| (votes[g.to_sym].to_f / votes[:total].to_f) >= vote_threshold } or begin
          # No need for a warning if we've since got the gender info from another source
          warn "  Unclear gender vote pattern: #{votes.to_hash}" unless r[:gender]
          next
        end
        gb_score += 1

        # Warn if our results are different from another source
        if r[:gender] && (r[:gender] != winner)
          warn_once "    ☁ Mismatch for #{r[:uuid]} #{r[:name]} (Was: #{r[:gender]} | GB: #{winner})"
          next
        end

        next if r[:gender]
        r[:gender] = winner
        gb_added += 1
      end
      output_warnings("GenderBalance Mismatches")
      warn "  ⚥ data for #{gb_score}; #{gb_added} added\n".cyan 
    end

    # Map Areas
    if area = sources.find { |src| src.type.downcase == 'ocd' }
      warn "Adding OCD areas from #{area.filename}".green
      ocds = area.as_table.group_by { |r| r[:id] }

      if area.generate == 'area'
        merged_rows.each do |r|
          if ocds.key?(r[:area_id])
            r[:area] = ocds[r[:area_id]].first[:name]
          elsif r[:area_id].to_s.empty?
            warn_once "    No area_id given for #{r[:uuid]}"
          else
            # :area_id was given but didn't resolve to an OCD ID.
            warn_once "    Could not resolve area_id #{r[:area_id]} for #{r[:uuid]}"
          end
        end
        output_warnings("OCD ID issues")

      else
        # Generate IDs from names
        overrides_with_string_keys = Hash[area.overrides.map { |k, v| [k.to_s, v] }]
        fuzzy = (area.merge_instructions.first || {})[:fuzzy]
        ocd_ids = OcdId.new(area.as_table, overrides_with_string_keys, fuzzy)

        merged_rows.select { |r| r[:area_id].nil? }.each do |r|
          area = ocd_ids.from_name(r[:area])
          if area.nil?
            warn_once "  No area match for #{r[:area]}"
            next
          end
          r[:area_id] = area
        end
        output_warnings('Unmatched areas')
      end
    end

    # Any local corrections in manual/corrections.csv
    if corrs = sources.find { |src| src.type.downcase == 'corrections' }
      warn "Applying local corrections from #{corrs.filename}".green
      corrs.as_table.each do |correction|
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


    # TODO add this as a Source
    legacy_id_file = 'sources/manual/legacy-ids.csv'
    if File.exist? legacy_id_file
      legacy = CSV.table(legacy_id_file, converters: nil).reject { |r| r[:legacy].to_s.empty? }.group_by { |r| r[:id] }

      all_headers |= %i(identifier__everypolitician_legacy)

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
