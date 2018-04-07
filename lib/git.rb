# frozen_string_literal: true

# A helpful monkey-patch to MatchData to return named matches as a
# hash that maps from symbolized match names to the matched text.
class MatchData
  def to_hash
    Hash[names.map(&:to_sym).zip(captures)]
  end
end

def file_to_commit_metadata(directories)
  # There's about 2MB of data returned by this command, so rather than
  # using backticks to turning it into a string and then splitting it,
  # parse the output line-by-line. As a bonus this doesn't
  # unnecessarily invoke a shell.
  command = [
    'git', '--no-pager', 'log', '--name-only', '--format=%H|%at',
    '--', *directories,
  ]
  last_commit = {}
  commit_details = nil
  IO.popen(command) do |f|
    f.each_line do |line|
      # Each commit is introduced with the abbreviated object name
      # of the commit and author date timestamp, separated by '|'.
      # Then there's a blank line, then one filename per line.
      line.strip!
      commit_match = line.match /^(?<sha>[a-f\d]+)\|(?<timestamp>\d+)$/
      if commit_match
        commit_details = commit_match.to_hash
      elsif !line.empty?
        last_commit[line] ||= commit_details
      end
    end
  end
  last_commit
end
