# frozen_string_literal: true

require_relative './wikidata_lookup'
require 'json'
require 'csv'

class RemoteSource
  # Instantiate correct subclass based on instructions
  def self.instantiate(instructions)
    c = instructions.i(:create)
    return RemoteSource::URL.new(instructions)                if c.key? :url
    return RemoteSource::Morph.new(instructions)              if c[:from] == 'morph'
    return RemoteSource::Parlparse.new(instructions)          if c[:from] == 'parlparse'
    return RemoteSource::Wikidata::Election.new(instructions) if c[:from] == 'election-wikidata'
    return RemoteSource::Wikidata::Group.new(instructions)    if c[:from] == 'group-wikidata'
    return RemoteSource::Wikidata::Raw.new(instructions)      if c[:from] == 'wikidata-raw'
    return RemoteSource::GenderBalance.new(instructions)      if c[:from] == 'gender-balance'

    raise "Don't know how to fetch #{instructions[:file]}"
  end

  def initialize(instructions)
    @instructions = instructions
  end

  def i(key)
    @instructions.i(key.to_sym)
  end

  def c(key)
    i(:create)[key.to_sym]
  end

  def source
    c(:source)
  end

  def copy_url(url)
    IO.copy_stream(open(url), i(:file))
  rescue => e
    abort "Failed to GET #{url}: #{e.message}"
  end

  def regenerate
    FileUtils.mkpath File.dirname i(:file)
    write
  end
end

class RemoteSource::GenderBalance < RemoteSource
  def write
    remote = "http://www.gender-balance.org/export/#{source}"
    copy_url(remote)
  end
end

class RemoteSource::Morph < RemoteSource
  def morph_select(src, query)
    (morph_api_key = ENV['MORPH_API_KEY']) || fail('Need a Morph API key')
    key = ERB::Util.url_encode(morph_api_key)
    warn "⤈ No ORDER BY for #{i(:file)}" unless query.downcase.include? 'order by'
    query = ERB::Util.url_encode(query.gsub(/\s+/, ' ').strip)
    url = "https://api.morph.io/#{src}/data.csv?key=#{key}&query=#{query}"
    begin
      open(url).read
    rescue => e
      abort "Failed to perform morph query #{query.inspect}: #{e.message}"
    end
  end

  def write
    data = morph_select(c(:scraper), c(:query))
    File.write(i(:file), data)
  end
end

class RemoteSource::Parlparse < RemoteSource
  def write
    gh_url = 'https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/data/'
    term_file_url = gh_url + '%s/sources/manual/terms.csv'
    instructions_url = gh_url + '%s/sources/parlparse/instructions.json'
    cwd = Dir.pwd.split('/').last(2).join('/')

    args = {
      terms_csv:         term_file_url % cwd,
      instructions_json: instructions_url % cwd,
    }
    remote = 'https://parlparse-to-csv.herokuapp.com/?' + URI.encode_www_form(args)
    copy_url(remote)
  end
end

class RemoteSource::URL < RemoteSource
  def write
    copy_url(c(:url))
  end
end

class RemoteSource::Wikidata < RemoteSource
  def lookup_class
    WikidataLookup
  end

  def csv_data
    CSV.table("sources/#{source}", converters: nil)
  end

  def map_data
    csv_data.map(&:to_hash)
  end

  def raw_wikidata
    lookup_class.new(map_data)
  end

  def processed_wikidata
    raw_wikidata.to_hash
  end

  def write
    File.write(i(:file), JSON.pretty_generate(processed_wikidata))
  end
end

class RemoteSource::Wikidata::Group < RemoteSource::Wikidata
  def lookup_class
    GroupLookup
  end
end

class RemoteSource::Wikidata::Election < RemoteSource::Wikidata
  def lookup_class
    ElectionLookup
  end

  # We don't have our own list of IDs to look up - instead pass through
  # the `create` data so we can look those up from the base
  def map_data
    i(:create)
  end
end

class RemoteSource::Wikidata::Raw < RemoteSource::Wikidata
  def lookup_class
    P39sLookup
  end

  def map_data
    super.each { |h| h[:wikidata] = h[:id] }
  end

  def processed_wikidata
    raw_wikidata.to_hash.each_with_object({}) { |(k, v), h| h[k] = v[:p39s] }.reject { |_, v| v.nil? }
  end
end
