require 'rcsv'
require_relative 'uuid_map'

module Source
  class Base
    # Instantiate correct subclass based on instructions
    def self.instantiate(i)
      raise "Missing `type` in #{i}" unless i.key? :type
      return Source::Membership.new(i)  if i[:type] == 'membership'
      return Source::Person.new(i)      if i[:type] == 'person'
      return Source::Wikidata.new(i)    if i[:type] == 'wikidata'
      return Source::Group.new(i)       if i[:type] == 'group'
      return Source::OCD.new(i)         if i[:type] == 'ocd'
      return Source::Area.new(i)        if i[:type] == 'area-wikidata'
      return Source::Gender.new(i)      if i[:type] == 'gender'
      return Source::Positions.new(i)   if i[:type] == 'wikidata-positions'
      return Source::Elections.new(i)   if i[:type] == 'wikidata-elections'
      return Source::Term.new(i)        if i[:type] == 'term'
      return Source::Corrections.new(i) if i[:type] == 'corrections'
      return Source::Areas.new(i)       if i[:type] == 'wikidata-areas'
      raise "Don't know how to handle #{i[:type]} files (#{i})"
    end

    def initialize(i)
      @instructions = i
    end

    def i(k)
      @instructions[k.to_sym]
    end

    def type
      i(:type)
    end

    def merge_instructions
      i(:merge)
    end

    def is_memberships?
      false
    end

    def is_bios?
      false
    end

    def has_people?
      false
    end

    # private
    REMAP = {
      area:            %w(constituency region district place),
      area_id:         %w(constituency_id region_id district_id place_id),
      biography:       %w(bio blurb),
      birth_date:      %w(dob date_of_birth),
      blog:            %w(weblog),
      cell:            %w(mob mobile cellphone),
      chamber:         %w(house),
      death_date:      %w(dod date_of_death),
      end_date:        %w(end ended until to),
      executive:       %w(post),
      family_name:     %w(last_name surname lastname),
      fax:             %w(facsimile),
      gender:          %w(sex),
      given_name:      %w(first_name forename),
      group:           %w(party party_name faction faktion bloc block org organization organisation),
      group_id:        %w(party_id faction_id faktion_id bloc_id block_id org_id organization_id organisation_id),
      image:           %w(img picture photo photograph portrait),
      name:            %w(name_en),
      patronymic_name: %w(patronym patronymic),
      phone:           %w(tel telephone),
      source:          %w(src),
      start_date:      %w(start started from since),
      term:            %w(legislative_period),
      website:         %w(homepage href url site),
    }.each_with_object({}) { |(k, vs), mapped| vs.each { |v| mapped[v] = k } }

    def remap(str)
      REMAP[str.to_s] || str.to_sym
    end

    def filename
      i(:file)
    end

    def pathname
      Pathname.new(filename)
    end

    def file_contents
      File.read(filename)
    end
  end

  class PlainCSV < Base
    def raw_table
      Rcsv.parse(file_contents, row_as_hash: true, columns: rcsv_column_options)
    end

    def as_table
      raw_table
    end

    def rcsv_column_options
      @header_converters ||= Hash[headers.map do |h|
        [h, { alias: h.to_s.downcase.strip.gsub(/\s+/, '_').gsub(/\W+/, '').to_sym, type: converter(h) }]
      end]
    end

    def headers
      (header_line = File.open(filename, &:gets)) || abort("#{filename} is empty!".red)
      Rcsv.parse(header_line, header: :none).first
    end

    def fields
      []
    end

    def converter(_)
      :string
    end
  end

  class CSV < PlainCSV
    def fields
      headers.map { |h| remap(h.to_s.downcase) }
    end

    def raw_table
      rows = []
      super.each do |row|
        # Need to make a copy in case there are multiple source columns
        # mapping to the same term (e.g. with areas)
        rows << Hash[row.keys.each.map { |h| [remap(h), row[h].nil? ? nil : row[h].tidy] }]
      end
      rows
    end
  end

  class JSON < Base
    def fields
      []
    end

    def as_json
      ::JSON.parse(file_contents, symbolize_names: true)
    end
  end

  class Membership < CSV
    def is_memberships?
      true
    end

    def has_people?
      true
    end

    def id_map
      id_mapper.mapping
    end

    def write_id_map_file!(data)
      id_mapper.rewrite(data)
    end

    def raw_table
      super.each do |r|
        # if the source has no ID, generate one
        r[:id] = r[:name].downcase.gsub(/\s+/, '_') if r[:id].to_s.empty?
      end
    end

    # Currently we just recognise a hash of k:v pairs to accept if matching
    # TODO: add 'reject' and more complex expressions
    def as_table
      return raw_table unless i(:filter)
      filter = ->(row) { i(:filter)[:accept].all? { |k, v| row[k] == v } }
      @_filtered ||= raw_table.select { |row| filter.call(row) }
    end

    private

    def id_mapper
      @map ||= UuidMapFile.new(id_map_file)
    end

    def id_map_file
      Pathname.new(filename.sub(/.csv$/, '-ids.csv'))
    end
  end

  class Person < CSV
    def is_bios?
      true
    end

    def has_people
      true
    end
  end

  class Wikidata < Person
    def fields
      super << :identifier__wikidata
    end
  end

  class OCD < CSV
    def fields
      %i(area area_id)
    end

    def fuzzy_match?
      i(:merge)[:fuzzy]
    end

    def overrides
      return {} unless i(:merge)
      return {} unless i(:merge).key? :overrides
      i(:merge)[:overrides]
    end

    def generate
      i(:generate)
    end
  end

  class Gender < PlainCSV
    def converter(h)
      h == 'uuid' ? :string : :int
    end

    def fields
      %i(gender)
    end
  end

  class Term < PlainCSV
  end

  class Group < JSON
  end

  class Area < JSON
  end

  class Elections < JSON
  end

  class Positions < JSON
  end

  class Corrections < PlainCSV
  end

  class Areas < PlainCSV
    def fields
      %i(area area_id)
    end
  end
end
