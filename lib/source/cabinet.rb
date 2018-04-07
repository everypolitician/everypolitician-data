# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class Cabinet < PlainCSV
    def filtered(position_map:)
      map = ::CSV.table(position_map)
      wanted = map.select { |r| r[:type] == 'cabinet' }.map { |r| r[:id] }
      as_table.select { |r| wanted.include? r[:position] }
    end
  end
end
