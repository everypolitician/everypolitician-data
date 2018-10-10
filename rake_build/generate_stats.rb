# frozen_string_literal: true

#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

STATSFILE = Pathname.new('unstable/stats.json')

namespace :stats do
  def lastmod(file)
    path = Pathname('sources') + file
    `git log -1 --format="%ai" -- #{path}`.split.first
  end

  task :regenerate do
    stats = StatsFile.new(popolo: ep_popolo, position_file: POSITION_CSV).stats
    stats[:sources] = json_load(@INSTRUCTIONS_FILE)[:sources].map do |src|
      {
        file:    src[:file],
        type:    src[:type],
        scraper: src.dig(:create, :scraper),
        lastmod: lastmod(src[:file]),
      }
    end
    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
