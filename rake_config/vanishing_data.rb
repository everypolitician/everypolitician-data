# frozen_string_literal: true

class SourceCSV
  def initialize(str)
    @raw = str
  end

  def ids
    grouped.keys
  end

  def rows(*wanted)
    wanted.flat_map { |k| grouped[k] }
  end

  private

  attr_reader :raw

  def as_csv
    @as_csv ||= CSV.parse(raw, headers: true, header_converters: :symbol)
  end

  def grouped
    # TODO: have an option to group by some other column
    raise 'No ID column in data' unless as_csv.headers.include? :id

    @grouped ||= as_csv.group_by { |r| r[:id] }
  end
end

class SourceHistory
  # Given a Source file, look at the prior version in git history and
  # provide access to information that has changed since then
  def initialize(source)
    @source = source
  end

  def removed_data
    old.rows(*removed_ids)
  end

  def added_data
    cur.rows(*added_ids)
  end

  private

  attr_reader :source

  def repo_root
    Pathname.new('../../..').realpath
  end

  def full_pathname
    source.pathname.realpath.relative_path_from(repo_root)
  end

  def old
    @old ||= SourceCSV.new(`git show @~1:#{full_pathname}`)
  end

  def cur
    @cur ||= SourceCSV.new(source.pathname.read)
  end

  def added_ids
    cur.ids - old.ids
  end

  def removed_ids
    old.ids - cur.ids
  end
end

namespace :changing_sources do
  def history(filename)
    wanted = @SOURCES.find { |s| s.filename.to_s.include? filename }
    abort "No suitable source matching '#{filename}'" if wanted.nil?
    SourceHistory.new(wanted)
  end

  desc 'report on vanished rows from a given source'
  task :removed_rows, [:filename] do |t, args|
    # TODO: add a parallel task for the idmap files
    abort "Usage: rake #{t}[source]" if args[:filename].to_s.empty?
    source = history(args[:filename])
    changed = source.removed_data
    abort 'No rows removed' if changed.empty?
    puts changed.first.headers.join(',')
    puts changed
  end

  desc 'report on added rows to a given source'
  task :added_rows, [:filename] do |t, args|
    abort "Usage: rake #{t}[source]" if args[:filename].to_s.empty?
    source = history(args[:filename])
    changed = source.added_data
    abort 'No rows added' if changed.empty?
    puts changed.first.headers.join(',')
    puts changed
  end
end
