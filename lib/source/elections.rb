# frozen_string_literal: true

require_relative 'json'

module Source
  class Elections < JSON
    def to_popolo
      { events: events }
    end

    private

    def events
      as_json.map do |id, data|
        name = data[:other_names].find { |h| h[:lang] == 'en' } or next warn "no English name for election #{id}"
        dates = (data.key?(:start_date) && data.key?(:end_date) ?
                  [data[:start_date], data[:end_date]] :
                  [data[:dates]]
                ).flatten.compact.sort
        next warn "No dates for election #{id} (#{name[:name]})" if dates.empty?

        {
          id:             id,
          name:           name[:name],
          start_date:     dates.first,
          end_date:       dates.last,
          identifiers:    [{ identifier: id, scheme: 'wikidata' }],
          classification: 'general election',
        }
      end.compact
    end
  end
end
