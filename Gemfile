# frozen_string_literal: true

source 'https://rubygems.org'

abort 'Ruby should be >= 2.3' unless RUBY_VERSION.to_f >= 2.3
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gem 'close_old_pull_requests', github: 'everypolitician/close_old_pull_requests'
gem 'colorize'
gem 'csv_to_popolo', github: 'tmtmtmtm/csv_to_popolo'
gem 'csvlint'
gem 'deep_merge'
gem 'everypolitician', github: 'everypolitician/everypolitician-ruby'
gem 'everypolitician-dataview-terms', github: 'everypolitician/everypolitician-dataview-terms'
gem 'everypolitician-popolo', github: 'everypolitician/everypolitician-popolo'
gem 'everypolitician-pull_request', github: 'everypolitician/everypolitician-pull_request'
gem 'facebook_username_extractor', '~> 0.3.0', github: 'everypolitician/facebook_username_extractor'
gem 'field_serializer', github: 'everypolitician/field_serializer'
gem 'fuzzy_match'
gem 'json'
gem 'json5'
gem 'pry'
gem 'rake'
gem 'rcsv'
gem 'require_all', '~> 1.0'
gem 'rest-client'
gem 'sass'
gem 'slop', '~> 3.6.0' # tied to pry version
gem 'twitter_username_extractor', github: 'everypolitician/twitter_username_extractor'
gem 'unicode_utils'
gem 'wikisnakker', github: 'everypolitician/wikisnakker'
gem 'yajl-ruby', require: 'yajl'

group :test do
  gem 'flog'
  gem 'minitest'
  gem 'minitest-around'
  gem 'rubocop'
  gem 'vcr'
  gem 'webmock'
end
