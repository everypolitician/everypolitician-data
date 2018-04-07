# frozen_string_literal: true

namespace :report do
  task :missing_wikidata do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')
    popolo.latest_term.memberships.map(&:person).reject(&:wikidata).sort_by(&:name).group_by(&:id).each do |id, ps|
      puts '%s (%s)' % [ps.first.name, id]
    end
  end
end
