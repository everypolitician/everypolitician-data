class OcdPatcher
  attr_reader :row, :ocd_ids, :warnings, :area

  def initialize(row, area)
    @row = row
    @ocd_ids = area.as_table
    @area = area
    @warnings = []
  end

  def patched
    row.dup.tap do |r|
      if area.generate == 'area'
        if ocds.key?(r[:area_id])
          r[:area] = ocds[r[:area_id]].first[:name]
        elsif r[:area_id].to_s.empty?
          warnings << "    No area_id given for #{r[:uuid]}"
        else
          # :area_id was given but didn't resolve to an OCD ID.
          warnings << "    Could not resolve area_id #{r[:area_id]} for #{r[:uuid]}"
        end
      else
        # Generate IDs from names
        overrides_with_string_keys = Hash[area.overrides.map { |k, v| [k.to_s, v] }]
        fuzzy = (area.merge_instructions || {})[:fuzzy]
        ocd_ids = OcdId.new(area.as_table, overrides_with_string_keys, fuzzy)

        merged_rows.select { |r| r[:area_id].nil? }.each do |r|
          area = ocd_ids.from_name(r[:area])
          if area.nil?
            warn_once "  No area match for #{r[:area]}"
            next
          end
          r[:area_id] = area
        end
        output_warnings('Unmatched areas')

        merged_rows.select { |r| r[:area].to_s.empty? && r[:area_id].to_s.start_with?('ocd-division') }.each do |r|
          area = ocd_ids.area_lookup[r[:area_id]]
          if area.nil?
            warn_once "  No area_id match for #{r[:area_id]}"
            next
          end
          r[:area] = area[:name]
        end
      end
    end
  end

  def ocds
    @ocds ||= ocd_ids.group_by { |r| r[:id] }
  end
end
