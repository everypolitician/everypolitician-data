# frozen_string_literal: true

#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

require 'date' # To give us DateTime.now
require 'octokit'

STATSFILE = Pathname.new('unstable/stats.json')

class BuiltSource
  def initialize(source)
    @source = source
  end

  def lastmod
    # TODO: move this check out of the class
    @lastmod ||= ENV['EP_FULL_GIT'] ? local_git_lastmod(path) : github_lastmod(path)
  end

  def warning
    return unless lastmod && source.key?(:create)
    return unless elapsed > 90

    default_warning
  end

  private

  attr_reader :source

  def default_warning
    "  ☢  #{source[:file]} has not been updated for #{elapsed} days"
  end

  def path
    @path ||= Pathname('sources') + source[:file]
  end

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

  def elapsed
    @elapsed ||= (DateTime.now - lastmod).to_i
  end
end

class BuiltSource
  class Gender < BuiltSource
    def initialize(source, popolo)
      @source = source
      @popolo = popolo
    end

    def warning
      return unless missing_gender?
      return unless super

      '%s (Missing %d)' % [super, missing_gender]
    end

    private

    attr_reader :source, :popolo

    def missing_gender
      @missing_gender ||= @popolo.persons.reject(&:gender).count
    end

    def missing_gender?
      missing_gender.positive?
    end
  end
end

namespace :stats do
  def lastmod(source)
    path = Pathname('sources') + source[:file]
    lm = ENV['EP_FULL_GIT'] ? local_git_lastmod(path) : github_lastmod(path)
    lm
  end

  task :regenerate do
    stats = StatsFile.new(popolo: ep_popolo, position_file: POSITION_CSV).stats
    stats[:sources] = json_load(@INSTRUCTIONS_FILE)[:sources].map do |src|
      bs = src[:file].include?('gender') ? BuiltSource::Gender.new(src, @popolo) : BuiltSource.new(src)
      warn bs.warning if bs.warning

      {
        file:    src[:file],
        type:    src[:type],
        scraper: src.dig(:create, :scraper),
        lastmod: bs.lastmod,
      }
    end
    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
