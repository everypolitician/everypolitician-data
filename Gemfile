source "https://rubygems.org"

abort 'Ruby should be >= 2.1.0' unless RUBY_VERSION.to_f >= 2.1
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gem 'json'
gem 'nokogiri'
gem 'pry'
gem 'rake'
gem 'csv_to_popolo', '~> 0.27.0', github: 'tmtmtmtm/csv_to_popolo'
gem 'colorize'
gem 'fuzzy_match'
gem 'yajl-ruby', require: 'yajl'
gem 'rest-client'
gem 'sass'
gem 'unicode_utils'
gem 'wikisnakker', '~> 0.7.0', github: 'everypolitician/wikisnakker'
gem 'everypolitician', github: 'everypolitician/everypolitician-ruby'
gem 'everypolitician-popolo', '~> 0.7.0', github: 'everypolitician/everypolitician-popolo'
gem 'twitter_username_extractor', github: 'everypolitician/twitter_username_extractor'
gem 'facebook_username_extractor', '~> 0.2.0'
gem 'json5'
gem 'slop', '~> 3.6.0' # tied to pry version
gem 'rcsv'
gem 'require_all'
gem 'close_old_pull_requests', github: 'everypolitician/close_old_pull_requests'
gem 'everypolitician-pull_request', github: 'everypolitician/everypolitician-pull_request'
gem 'everypolitician-dataview-terms', github: 'everypolitician/everypolitician-dataview-terms'

group :test do
  gem 'minitest'
  gem 'minitest-around'
  gem 'vcr'
  gem 'webmock'
  gem 'rubocop'
  gem 'flog'
end
