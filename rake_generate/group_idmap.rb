# frozen_string_literal: true

require 'csv'
require 'everypolitician/popolo'
require 'pathname'

#-----------------------------------------------------------------------
# Generate a idmap/group/ file for each membership source, based on the
# Wikidata ID map. Each group that has been matched to a Wikidata ID
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
  task :groupidmaps do
    group_instructions = @INSTRUCTIONS.sources_of_type('group') or next
    # TODO: these should really be available from Source::Group
    wikidata = Pathname.new('sources') + group_instructions.first.i(:create)[:source]
    mapping = CSV.parse(wikidata.read, headers: true, header_converters: :symbol).map { |r| [r[:id], r.to_h] }.to_h

    @INSTRUCTIONS.sources_of_type('membership').each do |src|
      gids = src.as_table.map { |r| r[:group_id] || r[:group].to_s.idify }.uniq

      known_groups_in_source = gids & mapping.keys
      data = known_groups_in_source.map do |id|
        [id, mapping[id][:uuid] ||= SecureRandom.uuid]
      end.to_h
      src.group_mapfile.rewrite(data)
    end

    ::CSV.open(wikidata, 'w') do |csv|
      csv << %i[id wikidata]
      mapping.each_value { |h| csv << [h[:uuid] || h[:id], h[:wikidata]] }
    end
  end
end
