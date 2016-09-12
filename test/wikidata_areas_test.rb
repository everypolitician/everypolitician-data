require 'test_helper'
require_relative '../lib/wikidata_area_lookup'

describe WikidataAreaLookup do
  subject do
    WikidataAreaLookup.new(
      [
        { id: 'Q178752', name: 'Menzies' },
        { id: 'Q182615', name: 'Cunningham' },
      ]
    )
  end

  it 'returns an id for a given area name' do
    subject.find_by_name('Menzies').must_equal 'Q178752'
    subject.find_by_name('Cunningham').must_equal 'Q182615'
  end

  it 'returns nil for unknown area names' do
    subject.find_by_name('Narnia').must_be_nil
  end
end
