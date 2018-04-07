# frozen_string_literal: true

require 'colorize'
require 'csv'
require 'pry'
require 'wikisnakker'

# generate a terms.csv file starting from a given Wikidata page for a
# 'legislative term' and iterating backwards

def fetch_term(qid)
  (t = Wikisnakker::Item.find(qid)) || raise('No such item')
  name = t.label('en')
  data = {
    id:         name[/^(\d+)/, 1],
    name:       name,
    start_date: %w[P580 P571].map { |p| t.send(p).to_s }.reject(&:empty?).first,
    end_date:   %w[P582 P576].map { |p| t.send(p).to_s }.reject(&:empty?).first,
    wikidata:   qid,
  }
  puts data.values.to_csv

  if prev = t.P155 || t.P1365
    fetch_term(prev.value.id)
  end
end

(start_at = ARGV.shift) || abort("Usage: #{$PROGRAM_NAME} <startingID>")
puts %w[id name start_date end_date wikidata].to_csv

# Start at most-recent term, and follow the 'follows' backwards
fetch_term start_at
