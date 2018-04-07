# frozen_string_literal: true

require 'json'
require 'pry'
require 'colorize'

total = 0
date = ARGV.pop if ARGV.last =~ /\d{4}-\d{2}-\d{2}/

ARGV.each do |file|
  statements = 0
  @json = JSON.load(File.read(file), lambda do |h|
    statements += h.values.select { |v| v.class == String }.count if h.class == Hash
  end)
  wd = @json['persons'].partition { |p| (p['identifiers'] || []).find { |i| i['scheme'] == 'wikidata' } }
  stats = {
    file:        file,
    persons:     @json['persons'].count,
    wikidata:    wd.first.count,
    nowikidata:  wd.last.count,
    wikidata_pc: (wd.first.count * 100.to_f / @json['persons'].count),
    statements:  statements,
  }
  warn stats
  # puts "#{file}: #{statements} statements"
  total += statements
end

puts [date, ARGV.count, total].compact.join("\t")
