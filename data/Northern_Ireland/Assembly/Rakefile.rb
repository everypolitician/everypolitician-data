require_relative '../../../rakefile_parlparse.rb'

namespace :transform do
  task :load do
    # Odd case of Eileen Bell staying on as Speaker beyond the term
    @json[:memberships].find { |m| m[:id] == 'uk.org.publicwhip/member/90241' }[:legislative_period_id] = 'term/2'
  end
end

