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
          legislatures: dirs.map { |dir| Legislature.new(dir: dir, commit_metadata: commit_metadata).stanza },
        }
      end

      private

      attr_reader :country, :commit_metadata

      def dirs
        country.legislatures.map { |l| 'data/' + l.directory }
      end

      def meta_file
        dirs.first + '/../meta.json'
      end

      def meta_json
        JSON.load(File.open(meta_file))
      end

      def meta
        @meta ||= File.exist?(meta_file) ? meta_json : {}
      end

      def name
        meta['name'] || country.name.tr('_', ' ')
      end

      def slug
        dirs.first.split('/').drop(1).first.tr('_', '-')
      end
    end

    # The metadata for a legislature, included in countries.json
    class Legislature
      def initialize(dir:, commit_metadata:)
        @dir = dir
        @commit_metadata = commit_metadata
      end

      def stanza
        sha, lastmod = commit_metadata[json_file].values_at :sha, :timestamp
        {
          name:                lname,
          slug:                lslug,
          sources_directory:   "#{dir}/sources",
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

      attr_reader :dir, :commit_metadata

      def remote_source
        'https://cdn.rawgit.com/everypolitician/everypolitician-data/%s/%s'
      end

      private

      def json_file
        dir + '/ep-popolo-v1.0.json'
      end

      def name_file
        dir + '/names.csv'
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
        dir.split('/').last.tr('_', '-')
      end

      def json_with_count
        @json_with_count ||= begin
          statements = 0
          json = JSON.load(File.read(json_file), lambda do |hash|
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
        legislature[:type] || raise("Missing 'type' for Legislature #{legislature[:name]} in #{dir}")
      end
    end

    # The metadata for a legislative period, included in countries.json
    class Term
      def initialize(event:, legislature:)
        @event = event
        @legislature = legislature
      end

      def stanza
        # TODO: split this up
        @stanza ||= begin
          event.delete :classification
          event.delete :organization_id
          event.delete :identifiers
          event[:slug] ||= event[:id].split('/').last
          event[:csv] = legislature.dir + "/term-#{event[:slug]}.csv"
          term_csv_sha = legislature.commit_metadata[event[:csv]][:sha]
          event[:csv_url] = legislature.remote_source % [term_csv_sha, event[:csv]]
          event
        end
      end

      def exists?
        File.exist? stanza[:csv]
      end

      private

      attr_reader :event, :legislature
    end
  end
end
