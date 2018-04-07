#!/usr/bin/env ruby
# frozen_string_literal: true

# How long has it been since the data for a legislature changed?

require 'pry'
require 'everypolitician'
EveryPolitician.countries_json = 'countries.json'

legislatures = EveryPolitician.countries.map(&:legislatures).flatten
legislatures.sort_by(&:lastmod).reverse_each do |legislature|
  lastmod = Time.at(legislature.lastmod.to_i)
  puts "#{legislature.country.name} — #{legislature.name} — #{lastmod}"
end
