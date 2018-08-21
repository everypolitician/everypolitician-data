# frozen_string_literal: true

require 'csv'
require 'everypolitician/popolo'
require 'pathname'

desc 'Generate an Area reconcilation file'
namespace :reconciliation do
  task :generate_areas do
    abort 'No Popolo file' unless EP_POPOLO.exist?
    recfile = @INSTRUCTIONS.sources_of_type('area-wikidata').first.reconciliation_file
    abort "#{recfile} already exists" if recfile.exist?
    areas = ep_popolo.areas.map { |a| { id: a.id, name: a.name } }
    header = %w[id wikidata].to_csv
    body = areas.map { |a| [a[:id].split('/').last, "??? #{a[:name]}"].to_csv }.join
    recfile.write(header + body)
    puts "Wrote #{recfile}"
  end
end
