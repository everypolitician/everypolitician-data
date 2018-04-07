# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/wikidata_lookup'

describe WikidataLookup do
  around { |test| VCR.use_cassette('wikidata-lookup', &test) }

  subject do
    WikidataLookup.new([
                         { id: 'pnp', wikidata: 'Q1076562' },
                         { id: 'ppd', wikidata: 'Q199319' },
                       ])
  end

  describe '#to_hash' do
    it 'returns a hash' do
      subject.to_hash.is_a?(Hash).must_equal true
    end

    it 'has a key for each requested item' do
      subject.to_hash.key?('pnp').must_equal true
    end

    it 'has an other_names key for each item' do
      subject.to_hash['pnp'].key?(:other_names).must_equal true
    end

    it 'includes the wikidata id' do
      subject.to_hash['pnp'].key?(:identifiers).must_equal true
      wikidata_identifier = subject.to_hash['pnp'][:identifiers][0]
      wikidata_identifier[:scheme].must_equal 'wikidata'
      wikidata_identifier[:identifier].must_equal 'Q1076562'
    end
  end
end
