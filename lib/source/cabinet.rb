# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class Cabinet < PlainCSV
    def partitioned(position_map:)
      wanted = position_map.cabinet_position_ids
      as_table.partition { |r| wanted.include? r[:position] }
    end
  end
end
