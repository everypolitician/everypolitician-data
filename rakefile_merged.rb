
require 'colorize'
require 'csv'
require 'erb'
require 'fileutils'
require 'fuzzy_match'
require 'json'
require 'open-uri'
require 'pry'
require 'rake/clean'
require 'set'

def json_load(file)
  return unless File.exist? file
  JSON.parse(File.read(file), symbolize_names: true)
end

@instructions = json_load('instructions.json') 
raise "No sources" if @instructions[:sources].count.zero?

@recreatable = @instructions[:sources].find_all { |i| i.key? :create }
CLOBBER.include FileList.new(@recreatable.map { |i| i[:file] })

# For now, write the merged file to manual/members.csv so we can then
# fall-back on the old-style rake task that looks there
# TODO: consolidate these
CLOBBER.include 'manual/members.csv'

def morph_select(src, qs)
  morph_api_key = ENV['MORPH_API_KEY'] or fail 'Need a Morph API key'
  key = ERB::Util.url_encode(morph_api_key)
  query = ERB::Util.url_encode(qs.gsub(/\s+/, ' ').strip)
  url = "https://api.morph.io/#{src}/data.csv?key=#{key}&query=#{query}"
  warn "Fetching #{url}"
  open(url).read
end

def fetch_missing
  @recreatable.each do |i|
    unless File.exist? i[:file]
      c = i[:create]
      raise "Don't know how to fetch #{i[:file]}" unless c[:type] == 'morph'
      data = morph_select(c[:scraper], c[:query])
      FileUtils.mkpath File.dirname i[:file]
      File.write(i[:file], data)
    end
  end 
end

REMAP = {
  area: %w(constituency region district place),
  area_id: %w(constituency_id region_id district_id place_id),
  biography: %w(bio blurb),
  birth_date: %w(dob date_of_birth),
  blog: %w(weblog),
  cell: %w(mob mobile cellphone),
  chamber: %w(house),
  death_date: %w(dod date_of_death),
  end_date: %w(end ended until to),
  executive: %w(post),
  family_name: %w(last_name surname lastname),
  fax: %w(facsimile),
  gender: %w(sex),
  given_name: %w(first_name forename),
  group: %w(party party_name faction faktion bloc block org organization organisation),
  group_id: %w( party_id faction_id faktion_id bloc_id block_id org_id organization_id organisation_id),
  image: %w(img picture photo photograph portrait),
  name: %w(name_en),
  patronymic_name: %w(patronym patronymic),
  phone: %w(tel telephone),
  source: %w(src),
  start_date: %w(start started from since),
  term: %w(legislative_period),
  website: %w(homepage href url site),
}
def remap(str)
  REMAP.find(->{[str]}) { |k, v| v.include? str.to_s }.first.to_sym
end


# http://codereview.stackexchange.com/questions/84290/combining-csvs-using-ruby-to-match-headers
def combine_sources

  # build headers for everything
  all_headers = @instructions[:sources].find_all { |src|
    src[:type] != 'term'
  }. map { |src| src[:file] }.reduce([]) do |all_headers, file|
    puts "Headers from #{file}".cyan
    header_line = File.open(file, &:gets)     
    all_headers | CSV.parse_line(header_line).map { |h| remap(h.downcase) } 
  end

  # First concat everything that's a "membership" (or default)
  all_rows = []
  @instructions[:sources].find_all { |src|
    src[:type].to_s.empty? || src[:type].to_s.downcase == 'membership'
  }.each do |src| 
    file = src[:file] 
    fuzzer = nil
    puts "Concat #{file}".cyan
    CSV.table(file).each do |row|
      # Need to make a copy in case there are multiple source columns
      # mapping to the same term (e.g. with areas)
      row = Hash[ row.headers.each.map { |h| [ remap(h), row[h] ] } ]

      if src.key? :merge
        field = src[:merge][:field].to_sym
        if src[:merge][:approximate] 
          fuzzer ||= FuzzyMatch.new(all_rows, read: field, must_match_at_least_one_word: true )
          found = fuzzer.find(row[field])
          puts "Matched #{row[field]} to #{found[field]}".yellow
        else
          raise "Not implemented yet"
        end

        if src[:merge][:clobber]
          row.headers.each do |h|
            found[h] = row[h] unless row[h].to_s.empty? || row[h].to_s.downcase == 'unknown'
          end
        else
          raise "Not implemented yet"
        end

      else # append
        all_rows << row.to_hash
      end
    end
  end

  # Then merge with Wikidata files
  # Two approaches supported so far:
  #    field: 'name':    merge by name, with fuzzy matching
  #    field: '<other>': merge by some other local field = the Wikidata ID
  #      match_on: the field in Wikidata to match with the local
  #
  #    TODO: merge by a field being a Wikipedia URL or Title
  if @instructions[:sources].find { |src| src[:type].to_s.downcase == 'person' }
    raise "No longer handle 'person' files. Perhaps you want a 'Wikidata' source?"
  end

  if wd = @instructions[:sources].find { |src| src[:type].to_s.downcase == 'wikidata' }
    puts "Merging with Wikidata #{wd[:file]}".magenta

    # Can merge either by a specified ID key, or on names
    raise "Need a Merge field" unless wd.key?(:merge) and wd[:merge].key?(:field)
    match_field = wd[:merge][:field].to_sym
    warn "Match by #{match_field}"

    wikidata = CSV.table(wd[:file])

    wd_by_id = ->(id) { 
      return unless id
      wikidata.find { |r| r[:id] == id } 
    }

    override = ->(name) { 
      return unless wd[:merge].key? :overrides
      return unless override_id = wd[:merge][:overrides][name.to_sym] 
      return '' if override_id.empty?
      wd_by_id.( override_id ) || "" # override to an ID that we don't have. TODO warn
    }

    if match_field == :name
      fuzzer = FuzzyMatch.new(wikidata, read: :name, must_match_at_least_one_word: true )
      finder = ->(r) { fuzzer.find(r[:name]) }
    else 
      match_on = (wd[:merge][:match_on] || 'id').to_sym
      finder = ->(r) { wikidata.find { |d| d[match_on] == r[match_field] } }
    end

    all_rows.each do |r|
      unless wd_match = override.(r[:name]) || finder.(r) 
        warn "No Wikidata match for #{r[:name]}"
        next
      end

      if wd_match == ''
        warn "Override skip for #{r[:name]}"
        next
      end

      # TODO: add as other_name
      warn "Matched #{r[:name]} to #{wd_match[:name]} (#{wd_match[:id]})".yellow if wd_match && wd_match[:name] != r[:name]

      # Merge it in (non-destructively)
      wd_match.headers.each { |h| r[h] = wd_match[h] if r[h].to_s.empty? || r[h].to_s.downcase == 'unknown' }
    end
  end

  # Then write it all out
  FileUtils.mkpath "manual"
  CSV.open("manual/members.csv", "w") do |out|
    out << all_headers
    all_rows.each { |r| out << all_headers.map { |header| r[header.to_sym] } }
  end

  # Write a source file, if required
  # TODO remove this once we're doing everything ourselves

  unless File.exist? 'manual/instructions.json'
    source = { source: @instructions[:sources].first { |i| i[:source] }[:source] }
    File.write 'manual/instructions.json', JSON.pretty_generate(source)
  end

end

task :fetch_missing do
  fetch_missing
end

task 'manual/members.csv' => :fetch_missing do
  combine_sources
end

task :default => [ 'manual/members.csv' ]
