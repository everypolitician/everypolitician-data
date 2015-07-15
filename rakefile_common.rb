require 'yajl/json_gem'
require 'open-uri'
require 'rake/clean'
require 'pry'
require 'csv'

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
  return unless File.exist? file
  JSON.parse(File.read(file), symbolize_names: true)
end

def json_write(file, json)
  # TODO remove the need for the .to_s here, by ensuring all People and Orgs have names
  json[:persons].sort_by!       { |p| [ p[:name].to_s, p[:id] ] }
  json[:organizations].sort_by! { |o| [ o[:name].to_s, o[:id] ] }
  json[:memberships].sort_by!   { |m| [ m[:person_id], m[:organization_id] ] }
  final = Hash[deep_sort(json).sort_by { |k, _| k }.reverse]
  File.write(file, JSON.pretty_generate(final))
end

def instructions(key)
  @instructions ||= json_load(@INSTRUCTIONS_FILE) || raise("Can't read #{@INSTRUCTIONS_FILE}")
  @instructions[key]
end

desc "Rebuild from source data"
task :rebuild => [ :clobber, 'ep-popolo-v1.0.json' ]
task :default => :csvs

desc "Remove unwanted data from source"
task :whittle => [:clobber, 'sources/merged.json']

namespace :whittle do

  # Source-specific files must provide a whittle:load

  file 'sources/merged.json' => :write 
  CLEAN.include('sources/merged.json')

  # Source-specific files must provide a @SOURCE

  task :meta_info => :load do
    @json[:meta] ||= {}
    @json[:meta][:source] = @SOURCE || instructions(:source) || abort("No @SOURCE defined")
  end

  # Remove any 'warnings' left behind from (e.g.) csv-to-popolo
  task :write => :remove_warnings
  task :remove_warnings => :load do
    @json.delete :warnings
  end

  # TODO work out how to make this do the 'only run if needed'
  task :write => :meta_info do
    unless File.exists? 'sources/merged.json'
      json_write('sources/merged.json', @json)
    end
  end

  #---------------------------------------------------------------------
  # Rule: No orphaned memberships
  #---------------------------------------------------------------------
  task :write => :no_orphaned_memberships
  task :no_orphaned_memberships => :load do
    @json[:memberships].keep_if { |m|
      @json[:organizations].find { |o| o[:id] == m[:organization_id] } and
      @json[:persons].find { |p| p[:id] == m[:person_id] } 
    }
  end  
end


namespace :transform do

  file 'ep-popolo-v1.0.json' => :write
  CLEAN.include('ep-popolo-v1.0.json', 'final.json')

  task :load => 'sources/merged.json' do
    @json = JSON.parse(File.read('sources/merged.json'), symbolize_names: true )
  end

  task :write do
    json_write('ep-popolo-v1.0.json', @json)
  end  

  #---------------------------------------------------------------------
  # Rule: There must be a legislature
  #---------------------------------------------------------------------
  task :write => :ensure_legislature
  task :ensure_legislature => :load do
    if @json[:organizations].find_all { |h| h[:classification] == 'legislature' }.count.zero?
      @json[:organizations] << {
        classification: "legislature",
        name: "Legislature",
        id: "legislature",
      }
    end
  end

  #---------------------------------------------------------------------
  # Rule: The legislature must be named
  #   Get this from the meta.json file
  #---------------------------------------------------------------------
  task :write => :name_legislature
  task :name_legislature => :ensure_legislature do
    raise "No meta.json file available" unless File.exist? 'meta.json'
    meta_info = JSON.parse(File.read('meta.json'), symbolize_names: true )
    leg = @json[:organizations].find_all { |h| h[:classification] == 'legislature' }
    raise "More than one legislature exists" if leg.count > 1
    leg.first.merge! meta_info
  end

  #---------------------------------------------------------------------
  # Rule: There must be at least one term
  # If there are none, we create them, by (in order of preference)
  # 1) Reading them from a 'terms.csv'
  # 2) Reading them from a file specified as @TERMFILE
  # 3) Reading them from a @TERMS array
  #---------------------------------------------------------------------
  task :write => :ensure_term

  def extra_termdata
    @TERMFILES = Dir.glob("sources/**/terms.csv")
    raise "Too many Termfiles [#{@TERMFILES}]" if @TERMFILES.count > 1

    if @TERMFILES.count == 1
      @TERMS = CSV.read(@TERMFILES.first, headers:true).map do |row|
        {
          id: row['id'][/\//] ? row['id'] : "term/#{row['id']}",
          name: row['name'],
          start_date: row['start_date'],
          end_date: row['end_date'],
        }.reject { |_,v| v.nil? or v.empty? }
      end
    end

    return [] if @TERMS.nil? or @TERMS.count.zero?
    @TERMS.each { |t| t[:classification] ||= 'legislative period' } 
    return @TERMS
  end

  def latest_term 
    @TERMS.sort_by { |t| t[:start_date].to_s }.last
  end

  task :write => :ensure_term
  task :ensure_term => :ensure_legislature do
    leg = @json[:organizations].find { |h| h[:classification] == 'legislature' } or raise "No legislature"
    newterms = extra_termdata
    newterms.each { |t| t[:organization_id] = leg[:id] }

    # To cope (for now) with source data that already has terms attached
    # to the legislature, build it all up there first (as before), and
    # then migrate it en masse to Events.
    if not leg.has_key?(:legislative_periods) or leg[:legislative_periods].count.zero? 
      raise "No @TERMFILE or @TERMS" if newterms.count.zero?
      leg[:legislative_periods] = newterms 
    else 
      leg[:legislative_periods].each do |t|
        if extra = newterms.find { |nt| nt[:id].to_s.split('/').last == t[:id].to_s.split('/').last }
          t.merge! extra.reject { |k, _| k == :id }
        end
      end
    end

    @json[:events] ||= []
    leg[:legislative_periods].each { |t| @json[:events] << t }
    leg.delete :legislative_periods
  end

  #---------------------------------------------------------------------
  # Rule: Legislative Memberships must be for a Term
  #---------------------------------------------------------------------
  task :write => :ensure_membership_terms
  task :ensure_membership_terms => :ensure_term do
    leg_ids = @json[:organizations].find_all { |o| %w(legislature chamber).include? o[:classification] }.map { |o| o[:id] }
    @json[:memberships].find_all { |m| m[:role] == 'member' and leg_ids.include? m[:organization_id] }.each do |m|
      m[:legislative_period_id] ||= latest_term[:id] 
    end
  end

  #---------------------------------------------------------------------
  # Rule: Legislative Memberships must have `on_behalf_of`
  # Will be set to @INDEPENDENT, or first named "Independent" party
  # (or one will be created)
  #---------------------------------------------------------------------

  def unknown_party
    if unknown = @json[:organizations].find { |o| o[:classification] == 'party' and o[:name].downcase == 'unknown' }
      return unknown
    end
    unknown = {
      classification: "party",
      name: "Unknown",
      id: "party/_unknown",
    }
    @json[:organizations] << unknown
    unknown
  end

  task :write => :ensure_behalf_of
  task :ensure_behalf_of => :ensure_legislature do
    leg_ids = @json[:organizations].find_all { |o| %w(legislature chamber).include? o[:classification] }.map { |o| o[:id] }
    @json[:memberships].find_all { |m| m[:role] == 'member' and leg_ids.include? m[:organization_id] }.each do |m|
      m[:on_behalf_of_id] = unknown_party[:id] if m[:on_behalf_of_id].to_s.empty?
    end
  end

  #---------------------------------------------------------------------
  # Rule: Areas should be first class, not just embedded
  #---------------------------------------------------------------------

  task :write => :promote_areas 
  task :promote_areas => :ensure_legislature do
    @json[:areas] ||= []
    @json[:memberships].find_all { |m| m.key? :area }.each do |m|
      area = m.delete :area
      area[:type] ||= 'constituency'
      area[:id] ||= area[:name].downcase.gsub(/\s+/, '_') 
      raise "area_id is empty" if area[:id].empty?
      m[:area_id] = area[:id]
      @json[:areas] << area unless @json[:areas].find { |a| a[:id] == area[:id] }
    end
  end

end


desc "Build the term-table CSVs"
task :csvs => ['term_csvs:term_tables']

CLEAN.include('term-*.csv')

namespace :term_csvs do

  def persons_twitter(p)
    if p.key? :contact_details
      if cd_twitter = p[:contact_details].find { |d| d[:type] == 'twitter' }
        return cd_twitter[:value]
      end
    end

    if p.key? 'links'
      if l_twitter = p[:links].find { |d| d[:note][/twitter/i] }
        return l_twitter[:url]
      end
    end
  end


  require 'csv'

  def name_at(p, date)
    return p[:name] unless date && p.key?(:other_names)
    historic = p[:other_names].find_all { |n| n.key?(:end_date) } 
    return p[:name] unless historic.any?
    at_date = historic.find_all { |n|
      n[:end_date] >= date && (n[:start_date] || '0000-00-00') <= date
    }
    return p[:name] if at_date.empty?
    raise "Too many names at #{date}: #{at_date}" if at_date.count > 1
    
    return at_date.first[:name]
  end

  task :term_tables => 'ep-popolo-v1.0.json' do
    @json = JSON.parse(File.read('ep-popolo-v1.0.json'), symbolize_names: true )
    terms = {}

    data = @json[:memberships].find_all { |m| m.key? :legislative_period_id }.map do |m|
      person = @json[:persons].find       { |r| (r[:id] == m[:person_id])       || (r[:id].end_with? "/#{m[:person_id]}") }
      group  = @json[:organizations].find { |o| (o[:id] == m[:on_behalf_of_id]) || (o[:id].end_with? "/#{m[:on_behalf_of_id]}") }
      house  = @json[:organizations].find { |o| (o[:id] == m[:organization_id]) || (o[:id].end_with? "/#{m[:organization_id]}") }
      terms[m[:legislative_period_id]] ||= @json[:events].find { |e| e[:id].split('/').last == m[:legislative_period_id].split('/').last }

      if group.nil?
        puts "No group for #{m}"
        binding.pry
        next
      end

      {
        id: person[:id].split('/').last,
        name: name_at(person, m[:end_date] || terms[m[:legislative_period_id]][:end_date]),
        email: person[:email],
        twitter: persons_twitter(person),
        group: group[:name],
        group_id: group[:id].split('/').last,
        area: m[:area_id] && @json[:areas].find { |a| a[:id] == m[:area_id] }[:name],
        chamber: house[:name],
        term: m[:legislative_period_id].split('/').last,
        start_date: m[:start_date],
        end_date: m[:end_date],
        image: person[:image],
        gender: person[:gender],
      }
    end
    data.group_by { |r| r[:term] }.each do |t, rs|
      filename = "term-#{t}.csv"
      header = rs.first.keys.to_csv
      rows   = rs.sort_by { |r| [r[:name], r[:start_date].to_s] }.map { |r| r.values.to_csv }
      csv    = [header, rows].compact.join
      warn "Creating #{filename}"
      File.write(filename, csv)
    end
  end

end
