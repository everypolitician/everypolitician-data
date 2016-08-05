class GroupPopolo
  attr_reader :popolo

  def initialize(popolo)
    @popolo = popolo
  end

  def merge_group_data(group_data)
    popolo[:organizations].select { |o| o[:classification] == 'party' }.each do |org|

      # FIXME: This doesn't do a deep merge, so any nested arrays on 'org'
      # will be clobbered if they appear in 'group_data'.
      org.merge!(group_data.fetch(org[:id].sub(/^party\//, '').to_sym, {}))
    end
  end
end
