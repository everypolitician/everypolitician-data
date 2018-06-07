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
    reconciliation = Pathname.new('sources') + area_instructions.first.i(:merge)[:reconciliation_file]
    mapping = CSV.parse(reconciliation.read, headers: true, header_converters: :symbol).map { |r| [r[:id], r.to_h] }.to_h

    @INSTRUCTIONS.sources_of_type('membership').each do |src|
      a_ids = src.as_table.map { |r| r[:area_id] || r[:area].to_s.idify }.uniq

      known_areas_in_source = a_ids & mapping.keys
      data = known_areas_in_source.map do |id|
        [id, mapping[id][:uuid] ||= SecureRandom.uuid]
      end.to_h
      src.area_mapfile.rewrite(data)
    end

    ::CSV.open(reconciliation, 'w') do |csv|
      csv << %i[id wikidata]
      mapping.each_value { |h| csv << [h[:uuid] || h[:id], h[:wikidata]] }
    end
  end
end
