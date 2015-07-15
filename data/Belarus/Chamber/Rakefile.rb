require_relative '../../../rakefile_morph.rb'
require 'csv'

@MERGED_FILE = "sources/merged.csv"
CLEAN.include(@MERGED_FILE)

namespace :merge do

  file @MERGED_FILE => @MORPH_DATA_FILE do
    original = CSV.table(@MORPH_DATA_FILE)
    override = CSV.table('sources/manual/overrides.csv')
    override.sort_by { |r| r[:timestamp] }.each do |change|
      old_row = original.find { |r| r[:id] == change[:id] && r[:term] == change[:term] } or raise "No match for #{change[:id]} in term #{change[:term]}"
      old_val = old_row[change[:field].to_sym]
      old_val.to_s == change[:old].to_s or raise "#{change[:field]} is '#{old_val}' not '#{change[:old]}' for #{change[:id]} in term #{change[:term]}"
      old_row[change[:field].to_sym] = change[:new]
    end

    header = original.headers.to_csv
    rows   = original.map { |r| r.to_hash.values.to_csv }
    csv    = [header, rows].compact.join
    warn "Creating #{@MERGED_FILE}"
    File.write(@MERGED_FILE, csv)
  end
end

namespace :whittle do
  task load: @MERGED_FILE do
    @json = Popolo::CSV.new(@MERGED_FILE).data
  end
end
