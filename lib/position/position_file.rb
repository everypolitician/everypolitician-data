# frozen_string_literal: true

class WikidataPositionFile
  def initialize(pathname:)
    @pathname = pathname
  end

  def positions_for(person)
    json[person.wikidata.to_sym].to_a.map do |posn|
      WikidataPosition.new(raw: posn, person: person)
    end
  end

  private

  attr_reader :pathname

  def json
    @json ||= JSON.parse(pathname.read, symbolize_names: true)
  end
end
