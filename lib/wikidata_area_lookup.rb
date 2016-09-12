class WikidataAreaLookup
  def initialize(areas)
    @areas_by_name = Hash[areas.map { |a| [a[:name], a[:id]] }]
  end

  def find_by_name(area_name)
    areas_by_name[area_name]
  end

  private

  attr_reader :areas_by_name
end
