# frozen_string_literal: true

require_relative 'csv'
require_relative '../ocd_id'

module Source
  class OCD < CSV
    def fields
      %i[area area_id]
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

  class OCD::IDs < OCD
    def merged_with(csv)
      ocds = as_table.group_by { |r| r[:id] }
      overrides_with_string_keys = Hash[overrides.map { |k, v| [k.to_s, v] }]
      lookup_class = fuzzy_match? ? ::OCD::Lookup::Fuzzy : ::OCD::Lookup::Plain
      ocd_ids = lookup_class.new(as_table, overrides_with_string_keys)
      csv.select { |r| r[:area_id].nil? }.each do |r|
        area = ocd_ids.from_name(r[:area])
        if area.nil?
          add_warning "  No area match for #{r[:area]}"
          next
        end
        r[:area_id] = area
      end
      csv
    end
  end

  class OCD::Names < OCD
    def merged_with(csv)
      ocds = as_table.group_by { |r| r[:id] }
      csv.each do |r|
        if ocds.key?(r[:area_id])
          r[:area] = ocds[r[:area_id]].first[:name]
        elsif r[:area_id].to_s.empty?
          add_warning "    No area_id given for #{r[:uuid]}"
        else
          # :area_id was given but didn't resolve to an OCD ID.
          add_warning "    Could not resolve area_id #{r[:area_id]} for #{r[:uuid]}"
        end
      end
      csv
    end
  end
end
