# frozen_string_literal: true

require 'test_helper'
require 'csv'
require_relative '../lib/gender_balancer'

describe 'Serbia' do
  around { |test| VCR.use_cassette('gb-serbia', &test) }

  subject do
    GenderBalancer.new(
      CSV.parse(
        open('http://www.gender-balance.org/export/Serbia/National-Assembly').read,
        headers: true, header_converters: :symbol
      )
    )
  end

  it 'returns a hash' do
    subject.results.is_a?(Hash).must_equal true
  end

  it 'ignores insufficient votes' do
    subject.results['0121ed9c-e4e3-4461-9ebc-85c84cad1ce3'].must_be_nil
  end

  it 'scores at 100%' do
    subject.results['31ca516f-15d5-41fc-8c8c-3667b7ae3106'].must_equal 'female'
  end

  it 'scores at 80%' do
    subject.results['03d42442-249c-40d4-a463-0ad4e414d65c'].must_equal 'male'
  end

  it 'fails at 60%' do
    subject.results['ef8fdf94-5706-4b18-9121-6f5df059cb4c'].must_be_nil
  end
end
