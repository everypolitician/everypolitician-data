require 'yajl/json_gem'
require 'iso_country_codes'
require 'tmpdir'

ISO = IsoCountryCodes.for_select

@HOUSES = FileList['data/**/Rakefile.rb'].map { |f| f.pathmap '%d' }.reject { |p| File.exist? "#{p}/WIP" }

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
  JSON.parse(File.read(json_file), symbolize_names: true)
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
      code: meta['iso_code'] || name_to_iso_code(name),
      slug: slug,
      legislatures: hs.map { |h|
        json_file = h + '/ep-popolo-v1.0.json'
        popolo = json_from(json_file)

        cmd = "git log -p --format='%h|%at' --no-notes -s -1 #{h}"
        (sha, lastmod) = `#{cmd}`.chomp.split('|')
        lname = name_from(popolo)
        lslug = h.split('/').last.tr('_', '-')
        {
          name: lname,
          slug: lslug,
          sources_directory: "#{h}/sources",
          popolo: json_file,
          lastmod: lastmod,
          sha: sha,
          legislative_periods: terms_from(popolo, h),
        }
      }
    }
  end
  File.write('countries.json', JSON.pretty_generate(data.to_a))
end

