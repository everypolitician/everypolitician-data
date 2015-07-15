require_relative 'rakefile_common.rb'

require 'colorize'

@TWFY_RAW_FILE = 'sources/parlparse/twfy.json'
@META = JSON.parse(File.read('meta.json'), symbolize_names: true )

namespace :raw do
  file @TWFY_RAW_FILE do
    warn "Refetching TWFY JSON"
    File.write(@TWFY_RAW_FILE, open('https://raw.githubusercontent.com/mysociety/parlparse/master/members/people.json').read)
  end
end

namespace :whittle do

  file 'sources/merged.json' => @TWFY_RAW_FILE
  task :load => @TWFY_RAW_FILE do
    @SOURCE = "http://www.theyworkforyou.com/"
    @HOUSE_ID = @META[:name].downcase.tr(' ','-')

    @json = JSON.parse(File.read(@TWFY_RAW_FILE), { symbolize_names: true })
    @json[:organizations] << {
      id: @HOUSE_ID,
      classification: 'legislature',
    }
  end

  task :no_orphaned_memberships => :remove_unwanted_data
  task :remove_unwanted_data => :load do
    @json[:posts].keep_if { |p| p[:organization_id] == @HOUSE_ID }

    kept_posts = @json[:posts].map { |p| p[:id] }
    @json[:memberships].keep_if { |m| kept_posts.include? m[:post_id] }
    @json[:memberships].each do |m| 
      post = @json[:posts].find { |p| p[:id] == m[:post_id] }
      m[:organization_id] = post[:organization_id]
      m[:area] = post[:area]
      m[:role] = 'member'
    end
    @json.delete 'posts'

    tokeep = @json[:memberships].map { |m| m[:person_id] }
    @json[:persons].keep_if { |p| tokeep.include? p[:id] }
  end

end

namespace :transform do

  task :ensure_membership_terms => :set_membership_terms
  task :set_membership_terms => :load do
    terms = @json[:events].find_all { |e| e[:classification] == 'legislative period' }
    @json[:memberships].find_all { |m| m[:organization_id] == @HOUSE_ID and not m.has_key? :legislative_period_id }.each do |m|
      s_date = m[:start_date]
      s_date += "-12-31" if s_date.length == 4
      e_date = m[:end_date] || '2100-01-01'
      e_date += "-01-01" if e_date.length == 4
      e_date = s_date if e_date < s_date
      
      matched = terms.find_all { |t| (s_date >= t[:start_date]) and (e_date <= (t[:end_date] || '2100-01-01')) }
      if matched.count == 1
        m[:legislative_period_id] = matched.first[:id]
      elsif matched.count > 1 and probable = matched.find { |poss| poss[:start_date] == s_date || poss[:end_date] == e_date }
        warn "#{matched.count} matches for #{m[:start_date]}–#{m[:end_date]}".magenta
        warn "  — picking #{probable}".yellow
        m[:legislative_period_id] = probable[:id]
      else 
        warn "Invalid term intersection (#{matched.count} matches)"
        warn "#{m[:start_date]}–#{m[:end_date]}".cyan
        warn "#{matched}".yellow

      end
    end
  end

  def display_name_from(name)
    if name.key? :lordname
      display = "#{name[:honorific_prefix]} #{name[:lordname]}"
      display += " of #{name[:lordofname]}" unless name[:lordofname].to_s.empty?
      return display
    end
    name[:given_name] + " " + name[:family_name]
  end


  task :write => :ensure_names
  task :ensure_names => :set_membership_terms do
    @json[:persons].each do |p| 
      p[:other_names].delete_if { |n| n[:note] != 'Main' } 
      p[:other_names].find_all { |n| not n.key? :name }.each do |n|
        n[:name] = display_name_from(n)
      end
    end
    @json[:persons].find_all { |p| not p.key? :name }.each do |p|
      main_names = p[:other_names].find_all { |n| n[:note] == 'Main' }
      most_recent = main_names.find { |n| n[:end_date].nil? } || main_names.sort_by { |n| n[:end_date] }.last
      raise "Uncertain name for #{JSON.pretty_generate p}" unless most_recent
      p[:name] = most_recent[:name]
    end
  end

end

