class CombinedArea
  attr_reader :uuid, :identifier__wikidata, :name

  def initialize(opts = {})
    @uuid = SecureRandom.uuid
    @identifier__wikidata = opts[:identifier__wikidata]
    @name = opts[:name]
  end
end

class CombinedAreas
  def initialize
    @areas = []
  end

  def add_wikidata_area(area)
    existing = areas.find do |a|
      a.identifier__wikidata == area[:id] || a.name == area[:name]
    end
    if existing.nil?
      combined_area = CombinedArea.new(
        identifier__wikidata: area[:id],
        name: area[:name]
      )
      areas << combined_area
    end
  end

  def find_by_name(name)
    areas.find { |a| a.name == name }
  end

  private

  attr_reader :areas
end
