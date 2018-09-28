# frozen_string_literal: true

require 'csv'
require 'json'
require 'pathname'

WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql'

def sparql(query)
  result = RestClient.get WIKIDATA_SPARQL_URL, accept: 'text/csv', params: { query: query }
  CSV.parse(result, headers: true, header_converters: :symbol)
rescue RestClient::Exception => e
  raise "Wikidata query #{query} failed: #{e.message}"
end

namespace :generate do
  desc 'Generate the list of cabinet positions'
  task :cabinet do
    c_json = json_load(COUNTRY_JSON)
    abort 'No cabinet set for this country' unless c_json[:cabinet]

    position_query = <<~SPARQL
      SELECT DISTINCT ?item ?itemLabel WHERE {
        ?item wdt:P279* wd:Q83307 ; wdt:P361 wd:#{c_json[:cabinet]}.
        SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        # date = #{Time.now}
      }
      ORDER BY ?item
    SPARQL
    data = sparql(position_query).map(&:to_h)

    csv_head = [%w[id label type]]
    csv_data = data.map { |r| [r[:item].split('/').last, r[:itemlabel], 'cabinet'] }
    POSITION_FILTER_CSV.write csv_head.concat(csv_data).map(&:to_csv).join
  end
end
