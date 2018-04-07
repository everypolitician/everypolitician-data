# frozen_string_literal: true

require 'json'
require 'pry'
require 'colorize'
require 'set'

def json_from(json_file)
  JSON.parse(File.read(json_file), symbolize_names: true)
end

def json_write(file, json)
  File.write(file, JSON.pretty_generate(json))
end

seen = Set.new
Dir['*/*/meta.json'].each do |file|
  country = file.split('/').first.tr('_', ' ')
  json = json_from(file)
  wd = json[:wikidata]
  if wd.nil?
    warn "\tNo wikidata for #{country} #{json[:name]}".yellow
  elsif wd == 'FFF'
    url = 'http://www.google.com/search?q=wikipedia+%s+%s&btnI' % [country, json[:name]]
    puts %(open "%s") % url.tr(' ', '+')
  else
    warn "Duplicate https://www.wikidata.org/wiki/#{wd}".red if seen.include? wd
    seen << wd
  end
end
