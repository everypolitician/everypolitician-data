# frozen_string_literal: true

desc 'Generate merged.json'
task whittle: [:clobber, MERGED_JSON]

namespace :whittle do
  file MERGED_JSON => :write

  task load: 'verify:check_data' do
    @json = Popolo::CSV.new(MERGED_CSV).data
  end

  task meta_info: :load do
    @json[:meta] ||= {}
    @json[:meta][:sources] = @SOURCES.flat_map { |s| s.i(:source) }.compact.uniq
  end

  # Remove any 'warnings' left behind from (e.g.) csv-to-popolo
  task write: :remove_warnings
  task remove_warnings: :load do
    @json.delete :warnings
  end

  # TODO: work out how to make this do the 'only run if needed'
  task write: :meta_info do
    json_write(MERGED_JSON, @json) unless MERGED_JSON.exist?
  end

  #---------------------------------------------------------------------
  # Rule: No orphaned memberships
  #---------------------------------------------------------------------
  task write: :no_orphaned_memberships
  task no_orphaned_memberships: :load do
    @json_orgs ||= Set.new @json[:organizations].map { |o| o[:id] }
    @json_persons ||= Set.new @json[:persons].map { |p| p[:id] }
    @json[:memberships].keep_if do |m|
      @json_orgs.include?(m[:organization_id]) && @json_persons.include?(m[:person_id])
    end
  end
end
