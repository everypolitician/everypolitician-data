# frozen_string_literal: true

WIKIDATA_QUERY_URL = 'https://query.wikidata.org/sparql?format=json&query=%s'
MERGED_SPARQL = <<~SPARQL
  SELECT
    (STRAFTER(STR(?old), STR(wd:)) AS ?from)
    (STRAFTER(STR(?new), STR(wd:)) AS ?to)
  WHERE {
    VALUES ?old { %s }
    ?old owl:sameAs ?new
  }
SPARQL

def sparql(query)
  result = RestClient.post WIKIDATA_SPARQL_URL, query, accept: 'text/csv', params: { query: query }
  CSV.parse(result, headers: true, header_converters: :symbol)
rescue RestClient::Exception => e
  raise "Wikidata query #{query} failed: #{e.message}"
end

namespace :wikidata do
  desc 'Handle moved Wikidata'
  task :handle_move, %i[from to] do |_, args|
    rfile = @INSTRUCTIONS.sources_of_type('wikidata').first.reconciliation_file
    data = rfile.to_h
    abort "No existing data for #{args[:from]}" unless data[args[:from]]
    abort "Already have data for #{args[:to]}" if data[args[:to]]
    data[args[:to]] = data.delete(args[:from])
    rfile.write!(data)
  end

  desc 'Automatically re-reconcile Wikidata merges'
  task :rereconcile do
    data = @INSTRUCTIONS.sources_of_type('wikidata').first.reconciliation_file.to_h

    # At 550-600 IDs this triggers "414 URI too long" error
    merges = data.keys.each_slice(500).flat_map do |ids|
      query = MERGED_SPARQL % ids.join(' ').gsub('Q', 'wd:Q')
      sparql(query).map(&:to_h)
    end

    merges.each do |change|
      warn "#{change[:from]} → #{change[:to]}"
      data[change[:to]] = data.delete(change[:from])
    end

    rfile.write!(data)
  end

  desc 'Remove orphaned Wikidata reconciliation records'
  task :remove_orphans do
    rfile = (@INSTRUCTIONS.sources_of_type('wikidata').first or next).reconciliation_file
    known = ep_popolo.persons.map(&:id)

    orphaned = rfile.to_h.values - known
    next unless orphaned.any?

    puts orphaned
    rfile.write!(rfile.to_h.reject { |_k, v| orphaned.include? v })
  end
end
