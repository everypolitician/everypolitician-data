
require 'everypolitician'
require 'fileutils'
require 'pathname'
require 'pry'
require 'require_all'
require 'tmpdir'
require 'json'

require_rel 'lib'

@HOUSES = FileList['data/*/*/Rakefile.rb'].map { |f| f.pathmap '%d' }.reject { |p| File.exist? "#{p}/WIP" }

def json_load(file)
  raise "No such file #{file}" unless File.exist? file
  JSON.parse(File.read(file), symbolize_names: true)
end

def json_write(file, json)
  File.write(file, JSON.pretty_generate(json))
end


desc 'Install country-list locally'
task 'countries.json' do
  # By default we build every country, but if EP_COUNTRY_REFRESH is set
  # we only build any country that contains that string. For example:
  #    EP_COUNTRY_REFRESH=Latvia be rake countries.json
  to_build = ENV['EP_COUNTRY_REFRESH'] || 'data'
  if to_build == 'data'
    countries = EveryPolitician.countries
  else
    countries = countries.select do |c|
      c.slug.downcase.include? to_build.downcase
    end
  end

  data = json_load('countries.json') rescue {}
  # If we know we'll need data for every country directory anyway,
  # it's much faster to pass the single directory 'data' than a list
  # of every country directory:
  commit_metadata = file_to_commit_metadata(
    to_build == 'data' ?
      ['data'] :
      countries.flat_map(&:legislatures).map { |l| 'data/' + l.directory }
  )

  countries.each do |c|
    country = Everypolitician::Country::Metadata.new(
      # TODO: change this to accept an EveryPolitician::Country
      country: c.name,
      dirs: c.legislatures.map { |l| 'data/' + l.directory },
      commit_metadata: commit_metadata,
    ).stanza
    data[data.find_index { |c| c[:name] == country[:name] }] = country
  end
  File.write('countries.json', JSON.pretty_generate(data.sort_by { |c| c[:name] }.to_a))
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task default: :test

desc "Go through the list of open pull requests and close any outdated ones"
task :close_old_pull_requests do
  require 'close_old_pull_requests'
  CloseOldPullRequests.clean.each do |pull_request|
    puts "Pull request #{pull_request.number} is outdated. (Newest pull request is #{pull_request.superseded_by.number})"
  end
end

require 'everypolitician/pull_request/rake_task'
Everypolitician::PullRequest::RakeTask.new.install_tasks
