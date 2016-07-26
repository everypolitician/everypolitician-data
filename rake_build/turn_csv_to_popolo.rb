desc "Generate merged.json"
task :whittle => [:clobber, 'sources/merged.json']

namespace :whittle do

  file 'sources/merged.json' => :write 
  CLEAN.include('sources/merged.json')

  task :load => 'verify:check_data' do
    @json = Popolo::CSV.new('sources/merged.csv').data
    persons = @json[:persons].map do |person|
      if person[:email]
        person[:email].gsub!('mailto:','')
      end
      person
    end
    @json[:persons] = persons
  end

  task :meta_info => :load do
    @json[:meta] ||= {}
    # TODO: allow for more than one source
    @json[:meta][:sources] = instructions(:sources).map { |s| s[:source] }.compact.uniq
  end

  # Remove any 'warnings' left behind from (e.g.) csv-to-popolo
  task :write => :remove_warnings
  task :remove_warnings => :load do
    @json.delete :warnings
  end

  # TODO work out how to make this do the 'only run if needed'
  task :write => :meta_info do
    unless File.exists? 'sources/merged.json'
      json_write('sources/merged.json', @json)
    end
  end

  #---------------------------------------------------------------------
  # Rule: No orphaned memberships
  #---------------------------------------------------------------------
  task :write => :no_orphaned_memberships
  task :no_orphaned_memberships => :load do
    @json_orgs ||= Set.new @json[:organizations].map { |o| o[:id] }
    @json_persons ||= Set.new @json[:persons].map { |p| p[:id] }
    @json[:memberships].keep_if { |m|
      @json_orgs.include?(m[:organization_id]) and @json_persons.include?(m[:person_id])
    }
  end  
end


