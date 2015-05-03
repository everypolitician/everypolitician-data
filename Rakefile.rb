require 'tmpdir'

@COUNTRIES = FileList['*/Rakefile.rb'].pathmap('%d')

@COUNTRIES.each do |country|
  desc "Regenerate #{country}"
  task country.to_sym do 
    Rake::Task[:regenerate].execute(country: country) 
  end
end

task :regenerate, :country do |t, args|
  country = args[:country] or abort "Need a country"
  abort "Don't know how to build #{country}" unless @COUNTRIES.include? country
  chdir country
  sh 'rake rebuild'
  chdir '..'
end

desc "Regenarate all countries"
task :regenerate_all do
  @COUNTRIES.each do |country| 
    Rake::Task[country.to_sym].execute
  end
end

desc "Publish data"
task :publish do
  Dir.mktmpdir do |dir|
    cwd = Dir.pwd
    puts "Currently in #{cwd}"
    puts "cd #{dir}"
    last_commit = %x{ git rev-parse --short HEAD }.chomp
    branch_name = "epdata-#{Time.now.to_i}"

    %x[ hub clone mysociety/popolo-viewer-sinatra #{dir} ]
    %x[ git checkout -b epdata-#{last_commit} ]
    @COUNTRIES.each do |country| 
      cp "#{country}/final.json", "#{dir}/data/#{country}.json"
    end
    %x[ git add . ]
    %x[ git commit -m "Refresh with new data from #{last_commit}" ]
    %x[ git push -u origin epdata-a28fc5f ]
    %x[ hub pull-request -m "Refresh with new data from #{last_commit}" ]
    require 'pry'
    binding.pry
  end
end

