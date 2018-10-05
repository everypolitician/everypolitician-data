# frozen_string_literal: true

require 'sass'
require 'require_all'

require_rel '../lib'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

namespace :merge_members do
  desc 'Combine Sources'
  task MERGED_CSV => 'fetch_sources:fetch_missing' do
    combine_sources
  end

  def combine_sources
    all_headers = (%i[id uuid] + @SOURCES.map(&:fields)).flatten.uniq

    merged_rows = []

    # First get all the `membership` rows
    @INSTRUCTIONS.sources_of_type('membership').each do |source|
      warn "Add memberships from #{source.filename}".green
      merged_rows = source.merged_with(merged_rows)
    end

    # Then merge with sources of plain Person data (i.e Person or Wikidata)
    @SOURCES.select(&:person_data?).each do |source|
      warn "Merging with #{source.filename}".green
      merged_rows = source.merged_with(merged_rows)
      warn source.warnings.to_a.join("\n") if source.warnings.any?
      all_headers |= source.additional_headers.to_a
    end

    # Gender information from Gender-Balance.org
    @INSTRUCTIONS.sources_of_type('gender').each do |source|
      warn "Adding GenderBalance results from #{source.filename}".green
      merged_rows = source.merged_with(merged_rows)
      if source.warnings.any?
        warn 'GenderBalance Mismatches'
        warn source.warnings.to_a.join("\n")
      end
    end

    # OCD IDs -> names
    @INSTRUCTIONS.sources_of_type('ocd-names').each do |source|
      warn "Adding OCD names from #{source.filename}".green
      merged_rows = source.merged_with(merged_rows)
      if source.warnings.any?
        warn 'OCD ID issues'
        warn source.warnings.to_a.join("\n")
      end
    end

    # Any local corrections in manual/corrections.csv
    @INSTRUCTIONS.sources_of_type('corrections').each do |source|
      warn "Applying local corrections from #{source.filename}".green
      merged_rows = source.merged_with(merged_rows)
      if source.warnings.any?
        warn 'Corrections Problems'
        warn source.warnings.to_a.join("\n")
      end
    end

    # TODO: add this as a Source
    legacy_id_file = 'sources/manual/legacy-ids.csv'
    if File.exist? legacy_id_file
      legacy = CSV.table(legacy_id_file, converters: nil).reject { |r| r[:legacy].to_s.empty? }.group_by { |r| r[:id] }

      all_headers |= %i[identifier__everypolitician_legacy]

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
