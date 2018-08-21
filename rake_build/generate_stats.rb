# frozen_string_literal: true

#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

STATSFILE = Pathname.new('unstable/stats.json')

namespace :stats do
  task :regenerate do
    stats = StatsFile.new(popolo: ep_popolo, position_file: POSITION_CSV).stats
    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
