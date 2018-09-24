#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pry'
require 'csv'
require 'colorize'

# Use the output of the position-filter interface to regenerate the JSON

def json_from(json_file)
  JSON.parse(File.read(json_file), symbolize_names: true)
end

(file = ARGV.shift) || abort("Usage: echo CSV | #{$PROGRAM_NAME} <filter file>")
json = json_from(file)
%i[self other_legislatures cabinet executive party other].each { |i| json[:include][i] ||= [] }

csv = Hash[ARGF.readlines.map { |l| l.chomp.split(',') }]

section_for = lambda do |r|
  (res = csv[r[:id]]) || return
  return json[:exclude][:self] if res == 'Self (skip)'
  return json[:include][:other] if res == 'Exclude'
  return json[:include][:self] if res == 'Self (keep)'
  return json[:include][:other_legislatures] if res == 'Other Legislature'
  return json[:include][:cabinet] if res == 'Cabinet'
  return json[:include][:executive] if res == 'Other Executive'
  return json[:include][:party] if res == 'Party'
  return json[:include][:other] if res == 'Other'

  raise "Unknown button: #{res}"
end

json[:unknown][:unknown].to_a.each do |r|
  if section = section_for.call(r)
    section << r
  end
end
json[:unknown].delete :unknown

File.write(file, JSON.pretty_generate(json))
