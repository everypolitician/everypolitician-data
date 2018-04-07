# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class CSV < PlainCSV
    def fields
      headers.map { |h| remap(h.to_s.downcase) }
    end

    def raw_table
      rows = []
      super.each do |row|
        # Need to make a copy in case there are multiple source columns
        # mapping to the same term (e.g. with areas)
        rows << Hash[row.keys.each.map { |h| [remap(h), row[h].nil? ? nil : row[h].tidy] }]
      end
      rows
    end
  end
end
