require 'test_helper'
require_relative '../lib/group_popolo'

describe GroupPopolo do
  subject do
    GroupPopolo.new(organizations: [
      {
        id: 'abc',
        classification: 'party',
      }
    ])
  end

  it 'augments the existing popolo' do
    subject.merge_group_data(abc: { foo: 'bar' })
    assert_equal 'bar', subject.popolo[:organizations].first[:foo]
  end
end
