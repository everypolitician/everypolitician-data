#!/usr/bin/env ruby

# Displays the percentage of women/men in the most recent term across all legislatures.

require 'json'
require 'csv'

countries = JSON.parse(open('countries.json').read, symbolize_names: true)

female = 0
male = 0

countries.each do |country|
  country[:legislatures].each do |legislature|
    term = legislature[:legislative_periods].first
    csv = CSV.read(term[:csv], headers: true, header_converters: :symbol).map(&:to_hash).uniq { |row| row[:id] }
    female += csv.count { |row| row[:gender] == 'female' }
    male += csv.count { |row| row[:gender] == 'male' }
  end
end

total = female + male

puts "Female: #{(female / total.to_f * 100).round(2)}% (#{female})"
puts "Male: #{(male / total.to_f * 100).round(2)}% (#{male})"
puts "Total: #{total}"
