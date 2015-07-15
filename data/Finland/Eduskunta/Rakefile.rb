require_relative '../../../rakefile_common.rb'

@SOURCE = 'https://github.com/tmtmtmtm/eduskunta-popolo'

@RAWFILE = 'sources/tmtmtmtm/eduskunta.json'

namespace :raw do
  @GITHUB_SOURCE = 'https://raw.githubusercontent.com/tmtmtmtm/eduskunta-popolo/master/eduskunta.json'
  file @RAWFILE do
    File.write(@RAWFILE, open(@GITHUB_SOURCE).read)
  end
end

namespace :whittle do
  task :load => @RAWFILE do
    @json = JSON.parse(File.read(@RAWFILE), symbolize_names: true)
  end
end

