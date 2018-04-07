# frozen_string_literal: true

require 'rcsv'

module Source
  class PlainCSV < Base
    def raw_table
      Rcsv.parse(file_contents, row_as_hash: true, columns: rcsv_column_options)
    end

    def as_table
      raw_table
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
  end
end
