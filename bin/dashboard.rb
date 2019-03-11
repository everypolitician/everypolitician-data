# frozen_string_literal: true

require 'everypolitician'
require 'everypolitician/popolo'
require 'pry'
require 'csv'

# Report some statistics for each legislature
#
# Usage: This should be passed the location of a file
# that ranks the countries (e.g. output from Google Analytics)

class AnalyticsFile
  def initialize(filename)
    @filename = filename
  end

  def ordering
    countries.zip(0..countries.size).to_h
  end

  private

  attr_reader :filename

  def as_csv
    @as_csv ||= CSV.table(filename)
  end

  # The first column is the URLs visited
  def first_column
    # It seems like there should be a nicer way to do this.
    # Interesting `r.first` returns something entirely different to `r[0]`
    as_csv.map { |r| r[0] }
  end

  def countries
    # We only want visits to the main country page, in the format: /country/
    first_column.compact.map { |r| r[%r{^/(.*)/$}, 1] }.compact
  end
end

analytics_file = ARGV.first or abort("Usage: #{$PROGRAM_NAME} <analytics.csv>")
ordering = AnalyticsFile.new(analytics_file).ordering

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
