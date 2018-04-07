# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class Term < PlainCSV
    def to_popolo
      oe = overlapping_events
      raise "Overlapping terms: #{oe.map { |ts| "#{ts.first[:id]} -> #{ts.last[:id]}" }}" unless oe.empty?

      { events: events }
    end

    private

    def overlapping_events
      sorted_events.each_cons(2).select { |e, l| l[:start_date] < e[:end_date] }
    end

    def sorted_events
      events.sort_by { |e| e[:start_date] }
    end

    def events
      @events ||= as_table.map do |row|
        {
          id:             row[:id][/\//] ? row[:id] : "term/#{row[:id]}",
          name:           row[:name],
          start_date:     row[:start_date],
          end_date:       row[:end_date],
          identifiers:    row[:wikidata].to_s.empty? ? nil : [{
            scheme:     'wikidata',
            identifier: row[:wikidata],
          },],
          classification: 'legislative period',
        }.reject { |_, v| v.to_s.empty? }
      end
    end
  end
end
