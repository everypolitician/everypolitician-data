
desc 'Remap memberships ids'
namespace :memberships do
  task :remap_ids, [:from, :to] do |_, args|
    @INSTRUCTIONS.sources_of_type('membership').each do |source|
      data = source.mapfile
      abort "No existing data for #{args[:from]}" unless data.uuid_for(args[:from])
      abort "Already have data for #{args[:to]}" if data.uuid_for(args[:to])
      data.remap(args[:from], args[:to])
      puts "Remapped #{args[:from]} to #{args[:to]} in #{source.filename.to_s}."
    end
  end
end
