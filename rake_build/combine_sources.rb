require 'sass'
require_relative '../lib/wikidata_lookup'
require_relative '../lib/matcher'
require_relative '../lib/patcher'
require_relative '../lib/reconciliation'
require_relative '../lib/remotesource'
require_relative '../lib/source'
require_relative '../lib/gender_balancer'
require_relative '../lib/ocd_id'
require_relative '../lib/wikidata_area_lookup'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

namespace :merge_sources do
  task :fetch_missing => :no_duplicate_names do
    fetch_missing
  end

  task :no_duplicate_names do
    sources.map(&:pathname).uniq.map(&:basename).group_by { |b| b }.select { |_,bs| bs.count > 1 }.each do |base, _|
      abort "More than one source called #{base}"
    end
  end

  desc 'Combine Sources'
  task MERGED_CSV => :fetch_missing do
    combine_sources
  end

  @recreatable = instructions(:sources).select { |i| i.key? :create }
  CLOBBER.include FileList.new(@recreatable.map { |i| i[:file] })

  CLEAN.include MERGED_CSV

  # We re-fetch any file that is missing, or, if REBUILD_SOURCE is set,
  # any file that matches that.
  def _should_refetch(file)
    return true unless File.exist?(file)
    return false unless ENV['REBUILD_SOURCE']
    file.include? ENV['REBUILD_SOURCE']
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

  def sources
    @sources ||= instructions(:sources).map { |s| Source::Base.instantiate(s) }
  end

  def combine_sources
    all_headers = (%i(id uuid) + sources.map(&:fields)).flatten.uniq

    merged_rows = []

    # First get all the `membership` rows, and either merge or concat
    sources.select(&:is_memberships?).each do |src|
      warn "Add memberships from #{src.filename}".green

      incoming_data = src.as_table
      id_map = src.id_map

      if merge_instructions = src.merge_instructions
        reconciler = Reconciler.new(merge_instructions, ENV['GENERATE_RECONCILIATION_INTERFACE'], merged_rows, incoming_data)
        raise "Can't reconciler memberships with a Reconciliation file yet" unless reconciler.filename

        pr = reconciler.reconciliation_data rescue abort($!.to_s)
        pr.each { |r| id_map[r[:id]] = r[:uuid] }
      end

      # Generate UUIDs for any people we don't already know
      (incoming_data.map { |r| r[:id] }.uniq - id_map.keys).each do |missing_id|
        id_map[missing_id] = SecureRandom.uuid
      end
      src.write_id_map_file! id_map

      incoming_data.each do |row|
        # Assume that incoming data has no useful uuid column
        row[:uuid] = id_map[row[:id]]
        merged_rows << row.to_hash
      end

    end

    # Then merge with Biographical data files

    sources.select(&:is_bios?).each do |src|
      warn "Merging with #{src.filename}".green

      incoming_data = src.as_table

      abort "No merge instructions for #{src.filename}" unless merge_instructions = src.merge_instructions
      reconciler = Reconciler.new(merge_instructions, ENV['GENERATE_RECONCILIATION_INTERFACE'], merged_rows, incoming_data)

      if reconciler.filename
        pr = reconciler.reconciliation_data rescue abort($!.to_s)
        matcher = Matcher::Reconciled.new(merged_rows, merge_instructions, pr)
      else
        matcher = Matcher::Exact.new(merged_rows, merge_instructions)
      end

      unmatched = []
      incoming_data.each do |incoming_row|
        incoming_row[:identifier__wikidata] ||= incoming_row[:id] if src.i(:type) == 'wikidata'

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
            patcher = Patcher.new(existing_row, incoming_row, merge_instructions[:patch])
            existing_row = patcher.patched
            all_headers |= patcher.new_headers.to_a
            patcher.warnings.each { |w| warn_once w }
          end
        else
          unmatched << incoming_row
        end
      end

      warn '* %d of %d unmatched'.magenta % [unmatched.count, incoming_data.count] if unmatched.any?
      unmatched.sample(10).each do |r|
        warn "\t#{r.to_hash.reject { |_, v| v.to_s.empty? }.select { |k, _| %i(id name).include? k }}"
      end
      output_warnings('Data Mismatches')
      incoming_data = unmatched
    end

    # Gender information from Gender-Balance.org
    if gb = sources.find { |src| src.type.downcase == 'gender' }
      warn "Adding GenderBalance results from #{gb.filename}".green
      results = GenderBalancer.new(gb.as_table).results
      gb_score = gb_added = 0

      merged_rows.each do |r|
        (winner = results[r[:uuid]]) || next
        gb_score += 1

        # Warn if our results are different from another source
        if r[:gender]
          warn_once "    ☁ Mismatch for #{r[:uuid]} #{r[:name]} (Was: #{r[:gender]} | GB: #{winner})" if r[:gender] != winner
          next
        end

        r[:gender] = winner
        gb_added += 1
      end
      output_warnings('GenderBalance Mismatches')
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
        output_warnings('OCD ID issues')

      else
        # Generate IDs from names
        overrides_with_string_keys = Hash[area.overrides.map { |k, v| [k.to_s, v] }]
        lookup_class = area.fuzzy_match? ? OCD::Lookup::Fuzzy : OCD::Lookup::Plain
        ocd_ids = lookup_class.new(area.as_table, overrides_with_string_keys)

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

    if areas = sources.find { |src| src.type.downcase == 'wikidata-areas' }
      warn "Adding Wikidata areas from #{areas.filename}".green
      area_lookup = WikidataAreaLookup.new(areas.as_table)
      merged_rows.each do |r|
        r[:area_id] = area_lookup.find_by_name(r[:area])
        warn_once "  No area match for #{r[:area]}" if r[:area_id].nil?
      end
      output_warnings('Unmatched Wikidata areas')
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

    # TODO: add this as a Source
    legacy_id_file = 'sources/manual/legacy-ids.csv'
    if File.exist? legacy_id_file
      legacy = CSV.table(legacy_id_file, converters: nil).reject { |r| r[:legacy].to_s.empty? }.group_by { |r| r[:id] }

      all_headers |= %i(identifier__everypolitician_legacy)

      merged_rows.each do |row|
        if legacy.key? row[:uuid]
          # TODO: row[:identifier__everypolitician_legacy] = legacy[ row[:uuid ] ].map { |i| i[:legacy] }.join ";"
          row[:identifier__everypolitician_legacy] = legacy[row[:uuid]].first[:legacy]
        end
      end
    end

    # No matter what 'id' columns we had, use the UUID as the final ID
    merged_rows.each { |row| row[:id] = row[:uuid] }

    # Then write it all out
    CSV.open(MERGED_CSV, 'w') do |out|
      out << all_headers
      merged_rows.each { |r| out << all_headers.map { |header| r[header.to_sym] } }
    end
  end
end
