#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pry'
require 'csv'

# Generate a Wikidata mapping file from the existing Popolo
# (Useful if we're changing how reconciliation works, and want to
# pre-seed with existing data)

def json_from(json_file)
  JSON.parse(File.read(json_file), symbolize_names: true)
end

(file = ARGV.first) || abort("Usage: #{$PROGRAM_NAME} <popolo file>")
@popolo = json_from(file)

def wikidata_id(person)
  return if person[:identifiers].empty?

  (wd = person[:identifiers].find { |i| i[:scheme] == 'wikidata' }) || return
  wd[:identifier]
end

rows = @popolo[:persons].map { |p| [wikidata_id(p), p[:id]] }.reject { |r| r.first.nil? }.sort_by(&:last)

puts %w[id uuid].to_csv
rows.each { |r| puts r.to_csv }
