
# frozen_string_literal: true

desc 'Handle moved Wikidata'
namespace :wikidata do
  task :handle_move, %i[from to] do |_, args|
    rfile = @INSTRUCTIONS.sources_of_type('wikidata').first.reconciliation_file
    data = rfile.to_h
    abort "No existing data for #{args[:from]}" unless data[args[:from]]
    abort "Already have data for #{args[:to]}" if data[args[:to]]
    data[args[:to]] = data.delete(args[:from])
    rfile.write!(data)
  end
end

desc 'Report on orphaned Wikidata reconciliation records'
namespace :wikidata do
  task :remove_orphans do
    rfile = (@INSTRUCTIONS.sources_of_type('wikidata').first or next).reconciliation_file
    known = ep_popolo.persons.map(&:id)

    orphaned = rfile.to_h.values - known
    next unless orphaned.any?

    puts orphaned
    rfile.write!(rfile.to_h.reject { |_k, v| orphaned.include? v })
  end
end
