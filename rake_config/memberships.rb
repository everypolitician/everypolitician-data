
desc 'Remap memberships ids'
namespace :memberships do
  task :remap_ids, [:from, :to] do |_, args|
    @INSTRUCTIONS.sources_of_type('membership').each do |source|
      source.mapfile.remap(args[:from], args[:to])
    end
  end
end
