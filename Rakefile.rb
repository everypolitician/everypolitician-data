# frozen_string_literal: true

require 'fileutils'
require 'require_all'

require_rel 'lib'

desc 'Install country-list locally'
task 'countries.json' do
  # By default we build every country, but if EP_COUNTRY_REFRESH is set
  # we only build any country that contains that string. For example:
  #    EP_COUNTRY_REFRESH=Latvia be rake countries.json
  Task::RebuildCountriesJSON.new(ENV['EP_COUNTRY_REFRESH']).execute
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

desc 'Go through the list of open pull requests and close any outdated ones'
task :close_old_pull_requests do
  require 'close_old_pull_requests'
  CloseOldPullRequests.clean.each do |pull_request|
    puts "Pull request #{pull_request.number} is outdated. (Newest pull request is #{pull_request.superseded_by.number})"
  end
end

require 'everypolitician/pull_request/rake_task'
Everypolitician::PullRequest::RakeTask.new.install_tasks

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: %w[test rubocop]
