# frozen_string_literal: true

require 'csv'
require 'everypolitician/popolo'
require 'pathname'

#-----------------------------------------------------------------------
# Generate a idmap/area/ file for each membership source, based on the
# Wikidata ID map. Each area that has been reconciled to a Wikidata ID
# will be given a new UUID.
#-----------------------------------------------------------------------

class String
  # from csv-to-popolo
  def idify
    return if to_s.empty?
    downcase.gsub(/\s+/, '_')
  end
end

namespace :generate do
  desc 'Generate idmap/group files from Wikidata mapping'
  task :areaidmaps do
    area_instructions = @INSTRUCTIONS.sources_of_type('area-wikidata') or next
    # TODO: these should really be available from Source::Area
    all_areas_file = Pathname.new('sources') + area_instructions.first.i(:merge)[:reconciliation_file]

    # This starts with id, wikidata
    all_areas_csv = CSV.parse(all_areas_file.read, headers: true, header_converters: :symbol)
    all_areas = all_areas_csv.map { |r| [r[:id], r.to_h] }.to_h

    @INSTRUCTIONS.sources_of_type('membership').each do |src|
      mem_areas = src.as_table.map { |r| r[:area_id] || r[:area].to_s.idify }.uniq

      previously_mapped = src.area_mapfile.mapping
      unmapped = mem_areas - previously_mapped.values

      can_map = unmapped & all_areas.keys
      newly_mapped = can_map.map do |id|
        [id, all_areas[id][:uuid] ||= SecureRandom.uuid]
      end.to_h
      src.area_mapfile.rewrite(previously_mapped.merge(newly_mapped))
    end

    header = %i[id uuid wikidata].to_csv
    rows = all_areas.each_value.map { |h| [h[:id], h[:uuid], h[:wikidata]].to_csv }
    all_areas_file.write(header + rows.join)
  end
end
