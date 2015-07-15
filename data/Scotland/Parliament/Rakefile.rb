require_relative '../../../rakefile_parlparse.rb'

namespace :transform do
  task :load do
    # David Steel as Presiding Officer
    @json[:memberships].find { |m| m[:id] == 'uk.org.publicwhip/member/80277' }[:legislative_period_id] = 'term/1'
    # George Reid as Presiding Officer
    @json[:memberships].find { |m| m[:id] == 'uk.org.publicwhip/member/80272' }[:legislative_period_id] = 'term/2'
  end
end

