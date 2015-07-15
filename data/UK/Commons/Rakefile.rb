require_relative '../../../rakefile_parlparse.rb'

namespace :whittle do
  task :load do
    @json[:memberships].delete_if { |m| m.key?(:start_date) && m[:start_date] < '1997-05-01' }
  end
end

