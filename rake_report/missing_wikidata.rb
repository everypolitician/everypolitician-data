# frozen_string_literal: true

namespace :report do
  task :missing_wikidata do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')

    # Find the latest term that has anyone unmapped to Wikidata
    latest_missing = popolo.terms.map do |term|
      term.memberships.reject { |mem| mem.person.wikidata }
    end.reject(&:empty?).last

    latest_missing.uniq { |mem| mem.person.id }.each do |mem|
      puts '%s (%s) %s' % [mem.person.name, mem.person.id, mem.sources.first&.[](:url)]
    end
  end
end
