# frozen_string_literal: true

require_relative 'plain_csv'

module Source
  class Gender < PlainCSV
    def converter(column_name)
      column_name == 'uuid' ? :string : :int
    end

    def fields
      %i[gender]
    end

    def merged_with(csv)
      gb_score = gb_added = 0
      results = GenderBalancer.new(as_table).results

      csv.each do |r|
        next unless winner = results[r[:uuid]]

        gb_score += 1

        # if our results are different from another source
        # warn, and keep the original
        if r[:gender]
          add_warning "    ☁ Mismatch for #{r[:uuid]} #{r[:name]} (Was: #{r[:gender]} | GB: #{winner})" if r[:gender] != winner
          next
        end

        r[:gender] = winner
        gb_added += 1
      end
      # TODO: have a standardised way of passing back reporting info
      warn "  ⚥ data for #{gb_score}; #{gb_added} added\n".cyan unless gb_score.zero?
      csv
    end
  end
end
