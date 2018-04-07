# frozen_string_literal: true

require 'pry'
require 'colorize'
require 'csv'
require 'slop'

#-----------------------------------------------------------------------
# Look for (and optionally remove) duplicates from a Reconciliation file
#-----------------------------------------------------------------------

opts = Slop.parse! do
  on 'd', 'delete', 'delete the duplicates?', argument: :optional
end

def csv_load(filename)
  CSV.table(filename, converters: nil)
end

(filename = ARGV.first || 'sources/reconciliation/wikidata.csv') || abort("Usage: #{$PROGRAM_NAME} <reconciliation file>")
unless File.exist? filename
  warn "No such file: #{filename} in #{Dir.pwd}"
  exit # don't error, so we can run this in a loop
end

data = csv_load(filename)
by_wdid = data.group_by { |r| r[:id] }
by_uuid = data.group_by { |r| r[:uuid] }

too_many_wdid = by_uuid.select { |_, rs| rs.count > 1 }
if too_many_wdid.any?
  puts 'Mutliple IDs:'
  too_many_wdid.each do |uuid, rs|
    puts "  #{uuid}: → #{rs.map { |r| r[:id] }.join(', ')}"
  end
end

too_many_uuid = by_wdid.select { |_, rs| rs.count > 1 }
if too_many_uuid.any?
  puts 'Mutliple UUIDs:'
  too_many_uuid.each do |wdid, rs|
    puts "  #{wdid}: → #{rs.map { |r| r[:uuid] }.join(', ')}"
  end
end

if too_many_wdid.any? || too_many_uuid.any?
  if opts.delete?
    warn "Rewriting #{filename}"
    bad_wdids = Set.new too_many_uuid.keys
    bad_uuids = Set.new too_many_wdid.keys
    header = data.headers.to_csv
    clean = data.reject { |r| bad_uuids.include?(r[:uuid]) || bad_wdids.include?(r[:id]) }.map(&:to_csv).join
    File.write(filename, header + clean)
  else
    warn 'use --delete to clean these up'
  end
end
