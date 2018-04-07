# frozen_string_literal: true

class WikidataPosition
  attr_reader :person
  def initialize(raw:, person:)
    @raw = raw
    @person = person
  end

  def id
    raw[:id]
  end

  def label
    raw[:label]
  end

  def description
    raw[:description]
  end

  def start_date
    qualifier(580)
  end

  def end_date
    qualifier(582)
  end

  private

  attr_reader :raw

  def qualifiers
    raw[:qualifiers] || {}
  end

  def qualifier(pcode)
    qualifiers["P#{pcode}".to_sym]
  end
end
