# frozen_string_literal: true

require 'json'

module Everypolitician
  module Metafile
    class Legislature
      def initialize(pathname)
        @pathname = pathname
      end

      def popolo
        raise "No wikidata" unless raw[:wikidata]

        raw.except(:member, :wikidata).merge({
          identifiers: [{
            scheme:     'wikidata',
            identifier: raw[:wikidata],
          }]
        })
      end

      private

      attr_reader :pathname

      def raw
        @raw ||= JSON.parse(pathname.read, symbolize_names: true)
      end
    end
  end
end
