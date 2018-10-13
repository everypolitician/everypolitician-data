# frozen_string_literal: true

namespace :report do
  task :missing_wikidata do
    # Find the latest term that has anyone unmapped to Wikidata
    latest_missing = ep_popolo.terms.map do |term|
      term.memberships.reject { |mem| mem.person.wikidata }
    end.reject(&:empty?).last or next

    puts latest_missing.first.term.id
    latest_missing.uniq { |mem| mem.person.id }.each do |mem|
      puts '%s (%s) %s @ %s' % [mem.person.name, mem.person.id, mem.area&.name, mem.sources.first&.[](:url)]
    end
  end
end
