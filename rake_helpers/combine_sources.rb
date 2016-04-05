require 'sass'
require_relative '../lib/wikidata_lookup'
require_relative '../lib/matcher'
require_relative '../lib/reconciliation'
require_relative '../lib/remotesource'
require_relative '../lib/source'

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
    all_headers = (%i(id uuid) + sources.map { |s| s.fields }).flatten.uniq

    merged_rows = []

    # First get all the `membership` rows, and either merge or concat
    sources.select(&:is_memberships?).each do |src|
      warn "Add memberships from #{src.filename}".magenta
      
      incoming_data = src.filtered_table
      id_map = src.id_map

      # If the row has no ID, we'll need something we can treate as one
      # This 'pseudo id' defaults to slugified 'name' 
      # TODO: do this in `filtered_table`
      incoming_data.select { |r| r[:id].to_s.empty? }.each do |row|
        row[:id] = row[:name].downcase.gsub(/\s+/, '_') 
      end

      if merging = src.merge_instructions.first
        reconciler = Reconciler.new(merging)
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

    sources.select(&:is_bios?).each do |pd|
      warn "Merging with #{pd.filename}".magenta

      incoming_data = pd.as_table

      abort "No merge instructions for #{pd.filename}" if (approaches = pd.merge_instructions).empty?
      approaches.each_with_index do |merge_instructions, i|
        reconciler = Reconciler.new(merge_instructions)

        warn "  Match incoming #{reconciler.incoming_field} to #{reconciler.existing_field}"

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

          incoming_row[:identifier__wikidata] ||= incoming_row[:id] if pd.i(:type) == 'wikidata'

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
              incoming_row.keys.reject { |h| h == :id }.each do |h|
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

                # TODO accept multiple values for :image, :website, etc.
                next if %i(image website twitter facebook).include? h

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

        warn "* %d of %d unmatched".magenta % [unmatched.count, incoming_data.count]
        unmatched.sample(10).each do |r|
          warn "\t#{r.to_hash.reject { |k,v| v.to_s.empty? }.select { |k, v| %i(id name).include? k } }"
        end 
        output_warnings("Data Mismatches")
        incoming_data = unmatched
      end
    end

    # Gender information from Gender-Balance.org
    if gb = instructions(:sources).find { |src| src[:type].to_s.downcase == 'gender' }
      min_selections = 5   # accept gender if at least this many votes
      vote_threshold = 0.8 # and at least this ratio of votes were for it

      gender = CSV.table(gb[:file], converters: nil).group_by { |r| r[:uuid] }
      gb_votes = 0

      # Only calculate the gender if we don't already have it
      # TODO: warn if the GB data differs from the pre-existing version
      merged_rows.select { |r| r[:gender].to_s.empty? }.each do |r|
        votes = (gender[ r[:uuid] ] or next).first
        next if votes[:total].to_i < min_selections
        winner = votes.reject { |k, _| %i(uuid total).include? k }.find { |k, v| (v.to_f / votes[:total].to_f) > vote_threshold } or begin
          warn "Unclear gender vote pattern: #{votes.to_hash}"
          next
        end
        next if winner.first == :skip
        r[:gender] = winner.first.to_s 
        gb_votes += 1
      end
      warn "⚥ #{gb_votes}".cyan 
    end

    # Map Areas
    if area = instructions(:sources).find { |src| src[:type].to_s.downcase == 'ocd' }
      ocds = CSV.table(area[:file], converters: nil).group_by { |r| r[:id] }

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
