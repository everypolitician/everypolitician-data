# frozen_string_literal: true

require 'require_all'
require_rel '../lib'

namespace :report do
  @recreatable = @SOURCES.select(&:recreateable?)

  desc 'List all morph sources for this legislature'
  task :morph_urls do
    src = @recreatable.map { |i| RemoteSource.instantiate(i) }.select { |rs| rs.class == RemoteSource::Morph }.map do |rs|
      "https://morph.io/#{rs.c(:scraper)}"
    end.uniq
    puts src
  end
end
