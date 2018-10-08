# frozen_string_literal: true

require 'rcsv'

module Source
  class PlainCSV < Base
    def raw_table
      Rcsv.parse(file_contents, row_as_hash: true, columns: rcsv_column_options)
    end

    def corrected_data
      return raw_table unless corrections.any?

      @corrected_data ||= begin
        to_correct = corrections.group_by { |r| r[:id] }
        raw_table.map do |row|
          to_correct.fetch(row[:id], []).each do |correction|
            if row[correction[:field].to_sym] == correction[:old]
              row[correction[:field].to_sym] = correction[:new]
            else
              warn "Cannot apply correction: #{correction}"
            end
          end
          row
        end
      end
    end

    def as_table
      corrected_data
    end

    def rcsv_column_options
      @rcsv_column_options ||= Hash[headers.map do |h|
        [h, { alias: h.to_s.downcase.strip.gsub(/\s+/, '_').gsub(/\W+/, '').to_sym, type: converter(h) }]
      end]
    end

    def headers
      (header_line = File.open(filename, &:gets)) || abort("#{filename} is empty!".red)
      Rcsv.parse(header_line, header: :none).first
    end

    def fields
      []
    end

    def converter(_column_name)
      :string
    end

    def corrections
      corrections_file = i('corrections') or return []
      @corrections ||= ::CSV.table('sources/' + corrections_file, converters: nil).map(&:to_h)
    end
  end
end
