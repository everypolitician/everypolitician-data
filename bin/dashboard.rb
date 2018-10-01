# frozen_string_literal: true

require 'everypolitician'
require 'everypolitician/popolo'
require 'pry'
require 'csv'

# Report some statistics for each legislature
#
# Usage: This should be passed the location of a file
# that ranks the countries (e.g. output from Google Analytics)

(analytics_file = ARGV.first) || abort("Usage: #{$PROGRAM_NAME} <analytics.csv>")
drilldown = CSV.table(analytics_file)
ordering = drilldown.reject { |r| r.count < 5 }
                    .select do |r|
             (r[0].to_s.length > 1) && (r[0][0] == r[0][-1])
           end.each_with_index.map { |r, i| [r[0].delete('/'), i] }.to_h

EveryPolitician.countries_json = 'countries.json'

def percentage(numerator, denominator)
  '%0.3f' % (numerator.to_f / denominator.to_f)
end

data = EveryPolitician::Index.new.countries.map(&:lower_house).map do |l|
  basedir = Pathname.new(l.raw_data[:popolo]).dirname
  statsfile = basedir + 'unstable/stats.json'
  raise "No statsfile for #{l.country.name}/#{l.name}" unless statsfile.exist?

  stats = JSON.parse(statsfile.read, symbolize_names: true)

  instructions_file = basedir + 'sources/instructions.json'
  instructions = JSON.parse(instructions_file.read, symbolize_names: true)

  mem_sources = instructions[:sources].select { |s| s[:type] == 'membership' }
  createables = mem_sources.select { |s| s.key?(:create) }
  p39_sources = createables.select { |c| c[:source].to_s.include? 'wikidata' }
  puts "+++ #{l.country.name}" if p39_sources.any?

  now = Time.now.to_date
  last_build = Time.at(l.lastmod.to_i).to_date

  latest = stats[:people][:latest_term]
  {
    posn:            (ordering[l.country.slug.downcase] || 999) + 1,
    country:         l.country.name,
    legislature:     l.name,
    lastmod:         last_build.to_s,
    ago:             (now - last_build).to_i,
    people:          stats[:people][:count],
    wikidata_all:    stats[:people][:wikidata],
    parties:         stats[:groups][:count],
    wd_parties:      stats[:groups][:wikidata],
    terms:           l.legislative_periods.count,
    wd_terms:        stats[:terms][:wikidata],
    areas:           stats[:areas][:count],
    wd_areas:        stats[:areas][:wikidata],
    elections:       stats[:elections][:count],
    latest_election: stats[:elections][:latest],
    latest_term:     l.legislative_periods.first.raw_data[:start_date],
    latest_count:    latest[:count],
    latest_wikidata: latest[:wikidata],
    email:           percentage(latest[:contacts][:email], latest[:count]),
    twitter:         percentage(latest[:contacts][:twitter], latest[:count]),
    facebook:        percentage(latest[:contacts][:facebook], latest[:count]),
    cabinet:         stats[:positions][:cabinet],
    mem_sources:     mem_sources.count,
    live_sources:    createables.count,
    p39_sources:     p39_sources.count,
  }
end.flatten

puts data.first.keys.to_csv
data.sort_by { |h| [h[:posn], h[:country]] }.each do |h|
  puts h.values.to_csv
end
