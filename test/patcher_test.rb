# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/patcher'
require 'pry'

describe 'Patcher' do
  it 'makes a simple addition' do
    existing = { id: 1, name: 'Fred' }
    incoming = { id: 1, name: 'Fred', birth_date: '2001-01-01' }
    result = Patcher.new(existing, incoming).patched
    result[:id].must_equal 1
    result[:name].must_equal 'Fred'
    result[:birth_date].must_equal '2001-01-01'
  end

  it 'patches Unknowns' do
    existing = { id: 1, name: 'Fred', birth_date: 'unknown' }
    incoming = { id: 1, name: 'Fred', birth_date: '2001-01-01' }
    result = Patcher.new(existing, incoming).patched
    result[:id].must_equal 1
    result[:name].must_equal 'Fred'
    result[:birth_date].must_equal '2001-01-01'
  end

  it 'keeps existing birth dates' do
    existing = { id: 1, name: 'Fred', birth_date: '2000-01-01' }
    incoming = { id: 1, name: 'Fred', birth_date: '2001-01-01' }
    result = Patcher.new(existing, incoming).patched
    result[:id].must_equal 1
    result[:name].must_equal 'Fred'
    result[:birth_date].must_equal '2000-01-01'
  end

  it 'ignores skipped fields' do
    existing = { id: 1, name: 'Fred' }
    incoming = { id: 1, name: 'Fred', birth_date: '2001-01-01' }
    result = Patcher.new(existing, incoming, ignore: ['birth_date']).patched
    result[:id].must_equal 1
    result[:name].must_equal 'Fred'
    result[:birth_date].must_be_nil
  end
end
