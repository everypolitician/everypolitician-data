# frozen_string_literal: true

require_relative 'json'

module Source
  class Positions
    # Deprecated approach where we build this ourselves. This should all
    # be done on morph and simply imported as a CSV.
    class Old < JSON
    end
  end
end
