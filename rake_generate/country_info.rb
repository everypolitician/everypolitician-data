# frozen_string_literal: true

require 'wikisnakker'

desc 'Refresh the information in the country meta.json'
task :refresh_country_meta do
  l_json = json_load(LEGISLATURE_META)

  l_id = l_json[:wikidata] or abort 'No Wikidata ID set for this legislature'

  query = <<~SPARQL
    SELECT DISTINCT (STRAFTER(STR(?country), STR(wd:)) AS ?country_id) ?countryLabel ?iso
                    (STRAFTER(STR(?cabinet), STR(wd:)) AS ?cabinet_id) ?cabinetLabel WHERE {
      BIND(wd:%s as ?legislature)
      ?legislature wdt:P1001 ?country .
      OPTIONAL { ?country wdt:P297 ?iso }
      OPTIONAL { ?country wdt:P300 ?iso }
      OPTIONAL { ?cabinet wdt:P279* wd:Q640506 ; wdt:P1001 ?country }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
    }
  SPARQL
  data = sparql(query % l_id).map(&:to_h)

  abort 'No country found' if data.empty?
  abort "More than one row returned from #{query % l_id}" if data.count > 1
  info = data.first

  base_data = { # We don't want to automatically update these
    id:   SecureRandom.uuid,
    name: info[:countryLabel],
  }

  existing_data = json_load(COUNTRY_META) rescue {}

  replacement_data = {
    iso_code: info[:iso],
    wikidata: info[:country_id],
    cabinet:  info[:cabinet_id],
  }.compact

  replacement_data.each do |field, value|
    existing = existing_data.dig(field)
    warn "Setting #{field} to #{value}" unless existing
    warn "Updating #{field} to #{value}" if existing && existing != value
  end

  new_data = base_data.merge(existing_data).merge(replacement_data)
  COUNTRY_META.write JSON.pretty_generate(new_data)

  # Make sure the legislature also has a UUID
  unless l_json.key? :uuid
    l_json[:uuid] = SecureRandom.uuid
    LEGISLATURE_META.write JSON.pretty_generate(l_json)
  end
end
