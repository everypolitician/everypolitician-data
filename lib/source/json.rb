# frozen_string_literal: true

module Source
  class JSON < Base
    def fields
      []
    end

    def as_json
      ::JSON.parse(file_contents, symbolize_names: true)
    end
  end
end
