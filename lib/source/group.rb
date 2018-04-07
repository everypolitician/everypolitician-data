# frozen_string_literal: true

require_relative 'json'

module Source
  class Group < JSON
    def to_popolo
      { organizations: as_json.map { |k, v| v.merge(id: k.to_s) } }
    end
  end
end
