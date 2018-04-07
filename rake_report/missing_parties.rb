# frozen_string_literal: true

namespace :report do
  task :missing_parties do
    puts EveryPolitician::Popolo.read('ep-popolo-v1.0.json').organizations.reject(&:wikidata).map { |p| [p.id, p.name].to_csv }
  end
end
