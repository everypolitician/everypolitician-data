require_relative '../../rakefile_common.rb'

require 'csv'
require 'csv_to_popolo'

@CANDIDATES_FILE = 'sources/YNMP/candidates.csv'
@WINNERS_FILE = 'sources/YNMP/winners.csv'

namespace :raw do
  file @CANDIDATES_FILE do
    warn "Refetching CSV"
    File.write(@CANDIDATES_FILE, open('https://edit.yournextmp.com/media/candidates.csv').read)
  end
end

namespace :winners do
  file @WINNERS_FILE => @CANDIDATES_FILE do
    remap_csv_headers = {
      'twitter_username' => 'twitter',
      'facebook_page_url' => 'facebook',
      'homepage_url' => 'homepage',
      'wikipedia_url' => 'wikipedia',
      'linkedin_url' => 'linkedin',
    }
    all = CSV.read(@CANDIDATES_FILE, {
      headers: true, 
      header_converters: lambda { |h| 
        hc = h.to_s.encode(::CSV::ConverterEncoding).downcase.gsub(/\s+/, "_").gsub(/\W+/, "")
        (remap_csv_headers[hc] || hc).to_sym
      }
    })
    headers = all.headers.to_csv
    winners = all.find_all { |row| row[:elected] == 'True' }
    output = winners.map { |row| row.to_hash.values.to_csv }.join
    File.write(@WINNERS_FILE, headers + output)
  end
end

namespace :whittle do
  task :load => @WINNERS_FILE do
    @SOURCE = 'https://yournextmp.com/'
    @json = Popolo::CSV.new(@WINNERS_FILE).data
  end

  task :write => :rename_party
  task :rename_party => :load do
    @json[:organizations].find_all { |o| o[:name] == 'Speaker seeking re-election' }.each do |o|
      o[:name] = 'Speaker'
    end
  end

end

