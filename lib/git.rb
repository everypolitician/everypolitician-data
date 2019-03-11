# frozen_string_literal: true

# A helpful monkey-patch to MatchData to return named matches as a
# hash that maps from symbolized match names to the matched text.
class MatchData
  def to_hash
    names.map(&:to_sym).zip(captures).to_h
  end
end

class GitHistory
  def initialize(directories:)
    @directories = directories
  end

  def metadata
    last_commit = {}
    # The command can return multi-MB of data, so parse it section by section
    IO.popen(command) do |output|
      output.each_line("\n\n\n") do |section|
        header, *files = section.strip.split(/\n+/)
        next unless files.any?

        commit_data = header.match(/^(?<sha>[a-f\d]+)\|(?<timestamp>\d+)$/).to_hash
        files.each { |file| last_commit[file] ||= commit_data }
      end
    end
    last_commit
  end

  private

  attr_reader :directories

  def command
    # Add three linebreaks to distinguish each section, so we can parse on that later
    ['git', '--no-pager', 'log', '--name-only', "--format=\n\n\n%H|%at", '--', *directories]
  end
end
