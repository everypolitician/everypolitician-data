require 'test_helper'
require_relative '../lib/combined_areas'

describe CombinedAreas do
  subject { CombinedAreas.new }
  let(:uuid_regex) { /^\w{8}-(\w{4}-){3}\w{12}$/ }

  it 'can find areas by name' do
    wikidata_area = { id: 'Q3296251', name: 'Anvard' }
    subject.add_wikidata_area(wikidata_area)
    area = subject.find_by_name('Anvard')
    area.uuid.must_match uuid_regex
    area.name.must_equal 'Anvard'
    area.identifier__wikidata.must_equal 'Q3296251'
  end
end
