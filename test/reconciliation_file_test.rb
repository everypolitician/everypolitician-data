# frozen_string_literal: true

require 'test_helper'
require 'csv'
require_relative '../lib/reconciliation/file'

describe 'Ukraine' do
  subject do
    Reconciliation::File.new(Pathname.new('test/data/wikidata.csv'))
  end

  it 'can convert to CSV' do
    subject.csv.size.must_equal 451
  end

  it 'can convert to Hash' do
    subject.to_h.keys.count.must_equal 451
  end

  it 'has data for Q1587874' do
    subject.to_h['Q1587874'].must_equal '0f6baa9e-1450-4a43-9410-963cdeeb165c'
  end
end
