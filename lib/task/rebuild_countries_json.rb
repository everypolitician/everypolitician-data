# frozen_string_literal: true

require 'everypolitician'
require 'json'

module Task
  class RebuildCountriesJSON
    def initialize(to_build)
      @to_build = to_build
    end

    def execute
      countries_file.write(
        JSON.pretty_generate(updated_data.sort_by { |c| c[:name] }.to_a)
      )
    end

    private

    attr_reader :to_build

    def countries_file
      Pathname.new('countries.json')
    end

    def raw_existing_data
      @raw_existing_data ||= JSON.parse(countries_file.read, symbolize_names: true)
    end

    def existing_data_as_hash
      raw_existing_data.map { |e| [e[:name], e] }.to_h
    end

    def all_countries
      Everypolitician::Index.new(index_url: 'countries.json').countries
    end

    def matching
      all_countries.select { |c| c.slug.downcase.include? to_build.downcase }
    end

    def countries
      return all_countries if to_build.to_s.empty?
      raise "Couldn't find the country '#{to_build}'" if matching.empty?

      matching
    end

    def commit_metadata
      @commit_metadata ||= file_to_commit_metadata(commit_path)
    end

    # If we know we'll need data for every country directory anyway,
    # it's much faster to pass the single directory 'data' than a list
    # of every country directory
    def commit_path
      return ['data'] if to_build.to_s.empty?

      countries.flat_map(&:legislatures).map { |l| 'data/' + l.directory }
    end

    def updated_data
      data = existing_data_as_hash
      countries.each { |c| data[c[:name]] = country_data(c) }
      data.values
    end

    def country_data(country)
      Everypolitician::Metadata::Country.new(
        country:         country,
        commit_metadata: commit_metadata
      ).stanza
    end
  end
end
