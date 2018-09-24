# frozen_string_literal: true

require 'rcsv'

# After generating merged.csv, ensure that it contains what we need
# and is well-formed
#
# We don't need to check the raw source data as it may be overridden.

desc 'Verify merged data'

namespace :verify do
  task load: 'merge_members:sources/merged.csv' do
    csv_data = MERGED_CSV.read
    @csv_headers = Rcsv.raw_parse(StringIO.new(csv_data.each_line.first)).first
    @csv = Rcsv.parse(
      csv_data,
      row_as_hash: true,
      columns:     Hash[@csv_headers.map { |h| [h, { alias: h.to_sym }] }]
    )
  end

  task check_data: :load do
    date_fields = @csv_headers.select { |k| k.include? '_date' }.map(&:to_sym)

    @csv.each do |r|
      abort "No `name` in #{r}" if r[:name].to_s.empty?
      date_fields.each do |d|
        next if r[d].nil? || r[d].empty?
        if r[d].match(/^\d{4}$/) || r[d].match(/^\d{4}-\d{2}$/)
          # warn_once.("Short #{d} in #{r}", [d, r[:uuid]])
          next
        end

        abort "Badly formatted #{d} (#{r[d]}) in #{r}" unless r[d] =~ /^\d{4}-\d{2}-\d{2}$/
        parsed_date = Date.parse(r[d]) rescue 'broken'
        abort "Invalid #{d} in #{r}" unless parsed_date.to_s == r[d]
      end
    end
  end
end
