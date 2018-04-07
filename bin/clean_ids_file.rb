# frozen_string_literal: true

require 'csv'
require 'pry'

# Clean out dead IDs from an id-to-uuid mapping file

(map_filename = ARGV.first) || abort("Usage: #{$PROGRAM_NAME} <filename>")
mapping = CSV.table(map_filename)

source = CSV.table(map_filename.sub('-ids.csv', '.csv'))
source_ids = source.map { |r| r[:id] }.uniq.sort

map_ids = mapping.map { |r| r[:id] }.uniq.sort

can_remove = (map_ids - source_ids).to_set

abort 'Nothing to clean' if can_remove.empty?

header = mapping.headers.to_csv
data   = mapping.reject { |r| can_remove.include? r[:id] }.map(&:to_csv).join

File.write(map_filename, header + data)
