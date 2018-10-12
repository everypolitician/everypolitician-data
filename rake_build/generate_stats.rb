# frozen_string_literal: true

#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

require 'date' # To give us DateTime.now
require 'octokit'

STATSFILE = Pathname.new('unstable/stats.json')

namespace :stats do
  def local_git_lastmod(file)
    Date.parse `git log -1 --format="%ai" -- #{file}`.split.first
  rescue => e
    warn e
    nil
  end

  def octokit
    @octokit ||= Octokit::Client.new(access_token: github_access_token)
  end

  def github_access_token
    @github_access_token ||= ENV.fetch('GITHUB_ACCESS_TOKEN')
  rescue KeyError
    abort 'Please set GITHUB_ACCESS_TOKEN in the environment before running'
  end

  def datapath
    @datapath ||= Pathname.pwd.relative_path_from(PROJECT.realpath)
  end

  def github_lastmod(file)
    lc = octokit.commits('everypolitician/everypolitician-data', path: datapath + file).first
    lc.commit.author.date.to_date
  rescue Octokit::TooManyRequests
    nil
  rescue => e
    warn e
    nil
  end

  def lastmod_warning(source, lastmod)
    return unless lastmod && source.key?(:create)

    elapsed = (DateTime.now - lastmod).to_i
    return unless elapsed > 90

    warning = "  ☢  #{source[:file]} has not been updated for #{elapsed} days"
    if source[:file].include?('gender')
      missing = @popolo.persons.reject(&:gender).count
      return if missing.zero?

      return "#{warning} (#{missing} missing)"
    end
    warning
  end

  def lastmod(source)
    path = Pathname('sources') + source[:file]
    lm = ENV['EP_FULL_GIT'] ? local_git_lastmod(path) : github_lastmod(path)
    if warning = lastmod_warning(source, lm)
      warn warning
    end
    lm
  end

  task :regenerate do
    stats = StatsFile.new(popolo: ep_popolo, position_file: POSITION_CSV).stats
    stats[:sources] = json_load(@INSTRUCTIONS_FILE)[:sources].map do |src|
      {
        file:    src[:file],
        type:    src[:type],
        scraper: src.dig(:create, :scraper),
        lastmod: lastmod(src),
      }
    end
    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
