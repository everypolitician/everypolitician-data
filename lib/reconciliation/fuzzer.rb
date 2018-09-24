# frozen_string_literal: true

require 'fuzzy_match'
require 'twitter_username_extractor'
require 'unicode_utils'

# Given a list of existing People records (each of which must have a UUID)
# and a list of incoming People (none of which yet have UUIDs),
# calculate potential matches from the first list for each from the second

module Reconciliation
  class Fuzzer
    attr_reader :existing_rows
    attr_reader :incoming_rows
    attr_reader :instructions

    def initialize(existing_rows, incoming_rows, instructions)
      @existing_rows = existing_rows
      @incoming_rows = incoming_rows
      @instructions = instructions
    end

    # Ensure we only have one row per UUID, and generate for each row a
    # 'fuzzit' field that we'll be checking against.
    # TODO: allow this to be more complex - e.g. multiple fields
    def existing_people
      @existing_people ||= existing_rows.uniq { |r| r[:uuid] }.each { |r| r[:fuzzit] = comparable(r[existing_field], existing_field) }
    end

    def fuzzer
      @fuzzer ||= FuzzyMatch.new(existing_people, read: :fuzzit)
    end

    def score_all
      incoming_rows.map do |incoming_row|
        if incoming_row[incoming_field].to_s.empty?
          warn "No #{incoming_field} in #{incoming_row.reject { |_k, v| v.to_s.empty? }}".red
          next
        end
        matches = fuzzer.find_all_with_score(comparable(incoming_row[incoming_field], incoming_field))
        unless matches.any?
          warn "No fuzzed matches for #{incoming_row.reject { |_k, v| v.to_s.empty? }}"
          next
        end
        data = {
          incoming: incoming_row,
          existing: matches.take(3),
        }
        output = "Fuzzed #{display(data)}"
        data[:existing].first[1] > 0.9 ? warn(output.to_s.yellow) : warn(output)
        data
      end.compact
    end

    private

    def incoming_field
      instructions[:incoming_field].to_sym
    rescue NoMethodError
      raise('Need an `incoming_field` to match on')
    end

    def existing_field
      instructions[:existing_field].to_sym
    rescue NoMethodError
      raise('Need an `existing_field` to match on')
    end

    # Standardise the strings we're comparing
    # For now just downcase it (in a Unicode-friendly way); later we'll
    # want to make this more cmomplex (e.g. accent folding)
    def comparable(str, field = nil)
      return if str.to_s.empty?

      if field == :twitter
        # Convert all the values to simple twitter-names
        return str.to_s.split(';').map do |h|
          TwitterUsernameExtractor.extract(h) rescue nil
        end.compact.uniq.join(';')
      end
      UnicodeUtils.downcase(str.to_s)
    end

    def display(row)
      {
        row[:incoming][incoming_field] => row[:existing].map do |r|
          [r[0][existing_field], r[1].to_f * 100]
        end,
      }
    end
  end
end
