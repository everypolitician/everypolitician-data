# frozen_string_literal: true

require 'everypolitician'
require 'everypolitician/popolo'
require 'pry'
require 'csv'

# Report on which Legislatures still need Election data
#
# Usage: This should be passed the location of a file
# that ranks the countries (e.g. output from Google Analytics)

(analytics_file = ARGV.first) || abort("Usage: #{$PROGRAM_NAME} <analytics.csv>")
drilldown = CSV.table(analytics_file)
ordering = Hash[drilldown.select { |r| (r[0].to_s.length > 1) && (r[0][0] == r[0][-1]) }.each_with_index.map { |r, i| [r[0].delete('/'), i] }]

EveryPolitician.countries_json = 'countries.json'

data = EveryPolitician.countries.map do |c|
  c.legislatures.map do |l|
    events = Everypolitician::Popolo.read(l.raw_data[:popolo]).events
    elections = events.select { |e| e.classification == 'general election' }
    {
      country:     c.name,
      legislature: l.name,
      posn:        ordering[c.slug.downcase] || 999,
      count:       elections.count,
    }
  end
end.flatten

data.sort_by { |h| [h[:posn], h[:country]] }.each do |h|
  puts '- [%s] %s — %s (%d)' % [(h[:count].zero? ? ' ' : 'x'), h[:country], h[:legislature], h[:count]]
end
