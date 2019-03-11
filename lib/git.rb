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

  # TODO: split this up
  def metadata
    last_commit = {}
    commit_details = nil

    # There's about 2MB of data returned by this command, so
    # parse the output line-by-line.
    IO.popen(command) do |output|
      output.each_line do |line|
        # Each commit is introduced with the abbreviated object name
        # of the commit and author date timestamp, separated by '|'.
        # Then there's a blank line, then one filename per line.
        line.strip!
        commit_match = line.match(/^(?<sha>[a-f\d]+)\|(?<timestamp>\d+)$/)
        if commit_match
          commit_details = commit_match.to_hash
        elsif !line.empty?
          last_commit[line] ||= commit_details
        end
      end
    end
    last_commit
  end

  private

  attr_reader :directories

  def command
    ['git', '--no-pager', 'log', '--name-only', '--format=%H|%at', '--', *directories]
  end
end
