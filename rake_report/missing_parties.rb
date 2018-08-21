# frozen_string_literal: true

namespace :report do
  task :missing_parties do
    puts ep_popolo.organizations.reject(&:wikidata).map { |p| [p.id, p.name].to_csv }
  end
end
