# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class Cabinet < PlainCSV
    def partitioned(position_map:)
      map = ::CSV.table(position_map)
      wanted = map.select { |r| r[:type] == 'cabinet' }.map { |r| r[:id] }
      as_table.partition { |r| wanted.include? r[:position] }
    end
  end
end
