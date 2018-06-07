# frozen_string_literal: true

require_relative 'csv'
require_relative '../ocd_id'

module Source
  class OCD < CSV
    def fields
      %i[area area_id]
    end

    def generate
      i(:generate)
    end
  end

  # we used to also have an OCD::IDs subclass, but it's no longer used.
  # We could get rid of the need for _this_ subclass, by pushing
  # everything up into the parent, but the longer term goal is to get
  # rid of all OCD-handling entirely, so we'll put up with this for now.
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
