# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/task/rebuild_countries_json'

describe 'RebuildCountriesJSON' do
  def tmp_countries_json_filename
    File.join(File.dirname(__FILE__), '..', 'countries.json')
  end

  # By default Everypolitician.countries_json uses the remote URL, but
  # we have countries.json locally in this repo, so make sure that's
  # used in these tests.

  before do
    @old_countries_json = Everypolitician.countries_json
    Everypolitician.countries_json = tmp_countries_json_filename
  end

  after do
    Everypolitician.countries_json = @old_countries_json
  end

  it 'errors if the requested country does not exist' do
    rebuilder = Task::RebuildCountriesJSON.new('freedonia')
    err = -> { rebuilder.send(:countries) }.must_raise RuntimeError
    err.message.must_match(/Couldn't find the country 'freedonia'/)
  end

  it 'finds a country if it does exists' do
    rebuilder = Task::RebuildCountriesJSON.new('united-states-of-america')
    countries_to_rebuild = rebuilder.send(:countries)
    countries_to_rebuild.length.must_equal 1
    countries_to_rebuild[0].name.must_equal 'United States of America'
  end

  it 'finds all matching countries' do
    rebuilder = Task::RebuildCountriesJSON.new('America')
    countries_to_rebuild = rebuilder.send(:countries)
    countries_to_rebuild.length.must_equal 2
    countries_to_rebuild.map(&:name).must_include 'American Samoa'
    countries_to_rebuild.map(&:name).must_include 'United States of America'
  end

  it 'returns lots of countries when none is specified' do
    rebuilder = Task::RebuildCountriesJSON.new nil
    countries_to_rebuild = rebuilder.send(:countries)
    countries_to_rebuild.length.must_be :>, 30
  end
end
