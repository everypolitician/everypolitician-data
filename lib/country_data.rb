# frozen_string_literal: true

module Everypolitician
  module Metadata
    # The metadata for a country, included in countries.json
    class Country
      def initialize(country:, commit_metadata:)
        @country = country
        @commit_metadata = commit_metadata
      end

      def stanza
        {
          name:         name,
          # Deprecated - will be removed soon!
          country:      name,
          code:         meta['iso_code'].upcase,
          slug:         slug,
          legislatures: paths.map { |path| Legislature.new(path: path, commit_metadata: commit_metadata).stanza },
        }
      end

      private

      attr_reader :country, :commit_metadata

      def datadir
        Pathname.new('data')
      end

      def paths
        country.legislatures.map { |l| datadir + l.directory }
      end

      def meta_file
        paths.first.parent + 'meta.json'
      end

      def meta_json
        JSON.load(meta_file.open)
      end

      def meta
        @meta ||= meta_file.exist? ? meta_json : {}
      end

      def name
        meta['name'] || country.name.tr('_', ' ')
      end

      def slug
        paths.first.parent.split.last.to_s.tr('_', '-')
      end
    end

    # The metadata for a legislature, included in countries.json
    class Legislature
      def initialize(path:, commit_metadata:)
        @path = path
        @commit_metadata = commit_metadata
      end

      def stanza
        sha, lastmod = commit_metadata[json_file.to_s].values_at :sha, :timestamp
        {
          name:                lname,
          slug:                lslug,
          sources_directory:   path + 'sources',
          popolo:              json_file,
          popolo_url:          remote_source % [sha, json_file],
          names:               name_file,
          lastmod:             lastmod,
          person_count:        popolo[:persons].size,
          sha:                 sha,
          legislative_periods: terms,
          statement_count:     statement_count,
          type:                type,
        }
      end

      attr_reader :path, :commit_metadata

      def remote_source
        'https://cdn.rawgit.com/everypolitician/everypolitician-data/%s/%s'
      end

      private

      def json_file
        path + 'ep-popolo-v1.0.json'
      end

      def name_file
        path + 'names.csv'
      end

      def terms
        # TODO: use everypolitician-popolo
        popolo[:events].select { |event| event[:classification] == 'legislative period' }
                       .map { |term| Term.new(event: term, legislature: self) }
                       .select(&:exists?)
                       .map(&:stanza)
                       .sort_by { |term| term[:start_date].to_s }
                       .reverse
      end

      def legislature
        orgs = popolo[:organizations].select { |org| org[:classification] == 'legislature' }
        raise "Wrong number of legislatures (#{orgs})" unless orgs.count == 1

        orgs.first
      end

      def lname
        legislature[:name]
      end

      def lslug
        path.basename.to_s.tr('_', '-')
      end

      def json_with_count
        @json_with_count ||= begin
          statements = 0
          json = JSON.load(json_file.read, lambda do |hash|
            statements += hash.values.select { |value| value.class == String }.count if hash.class == Hash
          end, symbolize_names: true, create_additions: false)
          [json, statements]
        end
      end

      def popolo
        json_with_count.first
      end

      def statement_count
        json_with_count.last
      end

      def type
        legislature[:type] || raise("Missing 'type' for Legislature #{legislature[:name]} in #{path}")
      end
    end

    # The metadata for a legislative period, included in countries.json
    class Term
      require 'active_support/core_ext/hash/except'

      def initialize(event:, legislature:)
        @event = event
        @legislature = legislature
      end

      def stanza
        event.except(:classification, :organization_id, :identifiers).merge(
          csv:     csv_path,
          csv_url: csv_url
        )
      end

      def exists?
        stanza[:csv].exist?
      end

      private

      attr_reader :event, :legislature

      def slug
        event[:slug] ||= event[:id].split('/').last
      end

      def csv_path
        legislature.path + "term-#{slug}.csv"
      end

      def term_csv_sha
        legislature.commit_metadata[csv_path.to_s][:sha]
      end

      def csv_url
        legislature.remote_source % [term_csv_sha, csv_path]
      end
    end
  end
end
