require_relative 'rakefile_common.rb'

require 'csv_to_popolo'

@SOURCE_DIR = 'sources/manual'
@DATA_FILE = @SOURCE_DIR + '/members.csv'
@INSTRUCTIONS_FILE = @SOURCE_DIR + '/instructions.json'

namespace :whittle do
  task :load do
    @json = Popolo::CSV.new('sources/manual/members.csv').data
  end
end
