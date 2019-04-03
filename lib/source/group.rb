# frozen_string_literal: true

require_relative 'json'

module Source
  class Group < JSON
    def to_popolo
      {
        organizations: as_json.map { |id, data| data.merge(id: id.to_s) },
      }
    end
  end
end
