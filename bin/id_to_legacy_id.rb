# frozen_string_literal: true

require 'json'
require 'pry'
require 'colorize'
require 'csv'

POPOLO = 'ep-popolo-v1.0.json'
CSVOUT = 'sources/manual/legacy-ids.csv'
HEADER = "id,legacy\n"

json = JSON.parse(File.read(POPOLO), symbolize_names: true)
rows = json[:persons].map { |p| [p[:id], p[:identifiers].find { |i| i[:scheme] == 'everypolitician_legacy' }[:identifier]].to_csv }.join

FileUtils.mkpath(File.dirname(CSVOUT))
File.write(CSVOUT, HEADER + rows)
