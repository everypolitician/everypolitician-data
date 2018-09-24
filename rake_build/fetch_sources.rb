# frozen_string_literal: true

require 'require_all'
require_rel '../lib'

namespace :fetch_sources do
  @recreatable = @SOURCES.select(&:recreateable?)
  CLOBBER.include FileList.new(@recreatable.map(&:filename))

  task :no_duplicate_names do
    @SOURCES.map(&:pathname).uniq.map(&:basename).group_by { |b| b }.select { |_, bs| bs.count > 1 }.each_key do |base|
      abort "More than one source called #{base}"
    end
  end

  task fetch_missing: :no_duplicate_names do
    @recreatable.each do |i|
      RemoteSource.instantiate(i).regenerate if _should_refetch(i.filename)
    end
  end

  # We re-fetch any file that is missing, or, if REBUILD_SOURCE is set,
  # any file that matches that.
  def _should_refetch(file)
    return true unless file.exist?
    return false unless ENV['REBUILD_SOURCE']

    file.to_s.include? ENV['REBUILD_SOURCE']
  end
end
