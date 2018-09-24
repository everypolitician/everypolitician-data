# frozen_string_literal: true

require_relative 'uuid_map'

module Source
  class Base
    attr_reader :warnings

    MAP = {
      'membership'         => Source::Membership,
      'person'             => Source::Person,
      'wikidata'           => Source::Wikidata,
      'group'              => Source::Group,
      'ocd-names'          => Source::OCD::Names,
      'area-wikidata'      => Source::Area,
      'gender'             => Source::Gender,
      'wikidata-cabinet'   => Source::Cabinet,
      'wikidata-positions' => Source::Positions::Old,
      'wikidata-elections' => Source::Elections,
      'term'               => Source::Term,
      'corrections'        => Source::Corrections,
    }.freeze

    def self.instantiate(instructions)
      raise "Missing `type` in #{instructions}" unless instructions.key? :type
      raise "Unknown file type: #{instructions[:type]}" unless klass = MAP[instructions[:type]]

      klass.new(instructions)
    end

    def initialize(instructions)
      @instructions = instructions
      @warnings = Set.new
    end

    def i(key)
      @instructions[key.to_sym]
    end

    def type
      i(:type)
    end

    def merge_instructions
      i(:merge)
    end

    def person_data?
      false
    end

    def recreateable?
      i(:create)
    end

    # private
    REMAP = {
      area:            %w[constituency region district place],
      area_id:         %w[constituency_id region_id district_id place_id],
      biography:       %w[bio blurb],
      birth_date:      %w[dob date_of_birth],
      blog:            %w[weblog],
      cell:            %w[mob mobile cellphone],
      chamber:         %w[house],
      death_date:      %w[dod date_of_death],
      end_date:        %w[end ended until to],
      executive:       %w[post],
      family_name:     %w[last_name surname lastname],
      fax:             %w[facsimile],
      gender:          %w[sex],
      given_name:      %w[first_name forename],
      group:           %w[party party_name faction faktion bloc block org organization organisation],
      group_id:        %w[party_id faction_id faktion_id bloc_id block_id org_id organization_id organisation_id],
      image:           %w[img picture photo photograph portrait],
      name:            %w[name_en],
      patronymic_name: %w[patronym patronymic],
      phone:           %w[tel telephone],
      source:          %w[src],
      start_date:      %w[start started from since],
      term:            %w[legislative_period],
      website:         %w[homepage href url site],
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

    private

    def add_warning(str)
      @warnings << str
    end
  end
end
