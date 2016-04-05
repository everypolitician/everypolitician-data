
# We take various steps to convert all the incoming data into the output
# formats. Each of these steps uses a different rake_helper:
#

# Step 1: combine_sources
# This takes all the incoming data (mostly as CSVs) and joins them
# together into 'sources/merged.csv'

# Step 2: verify_source_data
# Make sure that the merged data has everything we need and is 
# well-formed

# Step 3: turn_csv_to_popolo
# This turns the 'merged.csv' into a 'sources/merged.json'

# Step 4: generate_ep_popolo
# This turns the generic 'merged.json' into the EP-specific
# 'ep-popolo.json' 

# Step 5: generate_final_csvs
# Generates term-by-term CSVs from the ep-popolo

require 'colorize'
require 'csv'
require 'csv_to_popolo'
require 'erb'
require 'fileutils'
require 'fuzzy_match'
require 'json'
require 'open-uri'
require 'pry'
require 'rake/clean'
require 'set'
require 'yajl/json_gem'

Numeric.class_eval { def empty?; false; end }


def deep_sort(element)
  if element.is_a?(Hash)
    element.keys.sort.each_with_object({}) { |k, newhash| newhash[k] = deep_sort(element[k]) }
  elsif element.is_a?(Array)
    element.map { |v| deep_sort(v) }
  else
    element
  end
end

def json_load(file)
  raise "No such file #{file}" unless File.exist? file
  JSON.parse(File.read(file), symbolize_names: true)
end

def json_write(file, json)
  # TODO remove the need for the .to_s here, by ensuring all People and Orgs have names
  json[:persons].sort_by!       { |p| [ p[:name].to_s, p[:id] ] }
  json[:persons].each do |p|
    p[:identifiers].sort_by!     { |i| [ i[:scheme], i[:identifier] ] } if p.key?(:identifiers)
    p[:contact_details].sort_by! { |d| [ d[:type], d[:value] ] }        if p.key?(:contact_details)
    p[:links].sort_by!           { |l| [ l[:note], l[:url] ] }          if p.key?(:links)
    p[:other_names].sort_by!     { |n| [ n[:lang].to_s, n[:name] ] }    if p.key?(:other_names)
  end
  json[:organizations].sort_by! { |o| [ o[:name].to_s, o[:id] ] }
  json[:memberships].sort_by!   { |m| [ 
    m[:person_id].to_s, m[:organization_id].to_s, m[:legislative_period_id].to_s, m[:start_date].to_s, m[:on_behalf_of_id].to_s, m[:area_id].to_s
  ] }
  json[:events].sort_by!        { |e| [ e[:start_date] || '', e[:id] ] } if json.key? :events
  json[:areas].sort_by!         { |a| [ a[:id] ] } if json.key? :areas
  final = Hash[deep_sort(json).sort_by { |k, _| k }.reverse]
  File.write(file, JSON.pretty_generate(final))
end

@SOURCE_DIR = 'sources/manual'
@DATA_FILE = @SOURCE_DIR + '/members.csv'
@INSTRUCTIONS_FILE = 'sources/instructions.json'

def clean_instructions_file
  json_load(@INSTRUCTIONS_FILE) || raise("Can't read #{@INSTRUCTIONS_FILE}")
end

def load_instructions_file
  json = clean_instructions_file
  json[:sources].each do |s|
    s[:file] = "sources/%s" % s[:file] unless s[:file][/sources/]
  end
  json
end

desc "Add GenderBalance fetcher to instructions"
task :add_gender_balance do
  instr = clean_instructions_file
  sources = instr[:sources]
  abort "Already have GenderBalance instructions" if sources.find { |s| s[:type] == 'gender' }

  FileUtils.mkpath('sources/gender-balance')
  sources << { 
    file: "gender-balance/results.csv",
    type: "gender",
    create: {
      from: "gender-balance",
      source: pwd.split("/").last(2).join("/").gsub("_", "-"),
    },
  } 
  File.write(@INSTRUCTIONS_FILE, JSON.pretty_generate(instr))
end

desc "Add a wikidata Parties file"
task :build_parties do
  instr = clean_instructions_file
  sources = instr[:sources]
  abort "Already have party instructions" if sources.find { |s| s[:type] == 'group' }

  popolo = json_load('ep-popolo-v1.0.json')
  groups = popolo[:memberships].group_by { |m| m[:on_behalf_of_id] }.sort_by { 
    |m, ms| ms.count 
  }.reverse.map { |m, ms| 
    [ m.gsub('party/',''), popolo[:organizations].find { |o| o[:id] == m }[:name] ].to_csv
  }.join
  FileUtils.mkpath('sources/manual')
  File.write('sources/manual/group_wikidata.csv', "id,wikidata\n" + groups)

  sources << { 
    file: "wikidata/groups.json",
    type: "group",
    create: {
      from: "group-wikidata",
      source: "manual/group_wikidata.csv"
    },
  } 
  File.write(@INSTRUCTIONS_FILE, JSON.pretty_generate(instr))
end

desc "Add a wikidata P39 file"
task :build_p39s do
  instr = clean_instructions_file
  sources = instr[:sources]
  abort "Already have position instructions" if sources.find { |s| s[:type] == 'wikidata-positions' }

  wikidata = sources.find { |s| s[:type] == 'wikidata' } or abort "No wikidata section"
  reconciliation = [wikidata[:merge]].flatten(1).find { |s| s.key? :reconciliation_file } or abort "No wikidata reconciliation file"

  sources << { 
    file: "wikidata/positions.json",
    type: "wikidata-positions",
    create: {
      from: "wikidata-raw",
      source: reconciliation[:reconciliation_file],
    },
  } 
  File.write(@INSTRUCTIONS_FILE, JSON.pretty_generate(instr))
end

def instructions(key)
  @instructions ||= load_instructions_file
  @instructions[key]
end

def sources
  @sources ||= instructions(:sources).map do |src|
    raise "Missing `type` field in source: #{src}" if src[:type].to_s.empty?
    Source::Base.instantiate(src)
  end
end

desc "Rebuild from source data"
task :rebuild => [ :clobber, 'ep-popolo-v1.0.json' ]
task :default => :csvs

require_relative 'rake_helpers/combine_sources.rb'
require_relative 'rake_helpers/verify_source_data.rb'
require_relative 'rake_helpers/turn_csv_to_popolo.rb'
require_relative 'rake_helpers/generate_ep_popolo.rb'
require_relative 'rake_helpers/generate_final_csvs.rb'

