# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class Corrections < PlainCSV
    def merged_with(csv)
      as_table.each do |correction|
        rows = csv.select { |r| r[:uuid] == correction[:uuid] }
        if rows.empty?
          add_warning "Can't correct #{correction[:uuid]} — no such person"
          next
        end

        field = correction[:field].to_sym
        rows.each do |row|
          unless row[field] == correction[:old]
            add_warning "Can't correct #{correction[:uuid]}: #{field} is '#{row[field]} not '#{correction[:old]}'"
            next
          end
          row[field] = correction[:new]
        end
      end
      csv
    end
  end
end
