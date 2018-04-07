# frozen_string_literal: true

require_relative 'person'

module Source
  class Wikidata < Person
    def fields
      super << :identifier__wikidata
    end

    def reconciliation_file
      Reconciliation::File.new(
        Pathname.new('sources/') + i(:merge)[:reconciliation_file]
      )
    end
  end
end
