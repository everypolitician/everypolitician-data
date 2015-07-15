require_relative 'rakefile_common.rb'
require_relative 'lib/builder.rb'

require 'csv_to_popolo'
require 'pry'
require 'rake/clean'

@SOURCE_DIR = 'sources/morph'
CLOBBER.include(FileList.new('sources/morph/*.csv'))

@MORPH_DATA_FILE   = @SOURCE_DIR + '/data.csv'
@INSTRUCTIONS_FILE = @SOURCE_DIR + '/instructions.json'

namespace :raw do
  file 'sources/morph/data.csv' do
    builder = EveryPolitician::Builder::Morph.new(
      instructions(:source), 
      get_terms: instructions(:fetch_terms),
      data_query: instructions(:query),
      term_query: instructions(:term_query),
    )
    builder.fetch! 
  end
end

namespace :whittle do
  task load: @MORPH_DATA_FILE do
    @SOURCE = "https://morph.io/#{instructions(:source)}"
    @json = Popolo::CSV.new(@MORPH_DATA_FILE).data
  end
end
