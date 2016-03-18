require 'fileutils'
require 'iso_country_codes'
require 'pathname'
require 'pry'
require 'tmpdir'
require 'json'

ISO = IsoCountryCodes.for_select

@HOUSES = FileList['data/*/*/Rakefile.rb'].map { |f| f.pathmap '%d' }.reject { |p| File.exist? "#{p}/WIP" }

def name_to_iso_code(name)
  if code = ISO.find { |iname, _| iname == name }
    return code.last
  elsif code = ISO.find { |iname, _| iname.start_with? name }
    return code.last
  else
    fail "Can't find country code for #{name}"
  end
end

def json_from(json_file)
  statements = 0
  json = JSON.load(File.read(json_file), lambda { |h|
    statements += h.values.select { |v| v.class == String }.count if h.class == Hash 
  }, symbolize_names: true)
  return json, statements
end

def json_write(file, json)
  File.write(file, JSON.pretty_generate(json))
end

def terms_from(json, h)
  terms = json[:events].find_all { |o| o[:classification] == 'legislative period' }
  terms.sort_by { |t| t[:start_date].to_s }.reverse.map { |t|
    t.delete :classification
    t.delete :organization_id
    t[:slug] ||= t[:id].split('/').last
    t[:csv] = h + "/term-#{t[:slug]}.csv"
    t
  }.select { |t| File.exist? t[:csv] }
end

def name_from(json)
  orgs = json[:organizations].find_all { |o| o[:classification] == 'legislature' }
  raise "Wrong number of legislatures (#{orgs})" unless orgs.count == 1
  orgs.first[:name]
end

desc 'Install country-list locally'
task 'countries.json' do
  countries = @HOUSES.group_by { |h| h.split('/')[1] }
  
  data = countries.map do |c, hs|
    meta_file = hs.first + '/../meta.json'
    meta = File.exist?(meta_file) ? JSON.load(File.open meta_file) : {}
    name = meta['name'] || c.tr('_', ' ')
    slug = c.tr('_', '-')

    {
      name: name,
      # Deprecated — will be removed soon!
      country: name,
      code: (meta['iso_code'] || name_to_iso_code(name)).upcase,
      slug: slug,
      legislatures: hs.map { |h|
        json_file = h + '/ep-popolo-v1.0.json'
        name_file = h + '/names.csv'
        remote_source = 'https://github.com/everypolitician/everypolitician-data/raw/%s/%s'
        popolo, statement_count = json_from(json_file)

        cmd = "git --no-pager log --format='%h|%at' -1 #{h}"
        (sha, lastmod) = `#{cmd}`.chomp.split('|')
        lname = name_from(popolo)
        lslug = h.split('/').last.tr('_', '-')
        {
          name: lname,
          slug: lslug,
          sources_directory: "#{h}/sources",
          popolo: json_file,
          popolo_url: remote_source % [sha, json_file],
          names: name_file,
          lastmod: lastmod,
          person_count: popolo[:persons].size,
          sha: sha,
          legislative_periods: terms_from(popolo, h).each { |t| t[:csv_url] = remote_source % [sha, t[:csv]] },
          statement_count: statement_count,
        }
      }
    }
  end
  File.write('countries.json', JSON.pretty_generate(data.sort_by { |c| c[:name] }.to_a))
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end
