# frozen_string_literal: true

require 'everypolitician'
require 'everypolitician/popolo'

# Report on which Legislatures have no-one matched to Wikidata

EveryPolitician.countries_json = 'countries.json'
EveryPolitician.countries.each do |c|
  c.legislatures.each do |l|
    people = Everypolitician::Popolo.read(l.raw_data[:popolo]).persons
    wdp = people.partition(&:wikidata)
    puts '- [ ] %s — %s (%d)' % [c.name, l.name, people.count] if wdp.first.count.zero?
  end
end
