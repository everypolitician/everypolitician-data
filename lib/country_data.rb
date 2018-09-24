# frozen_string_literal: true

module Everypolitician
  class Country
    # The metadata for a country, included in countries.json
    class Metadata
      def initialize(country:, dirs:, commit_metadata:)
        @country = country
        @dirs = dirs
        @commit_metadata = commit_metadata
      end

      def stanza
        {
          name:         name,
          # Deprecated - will be removed soon!
          country:      name,
          code:         meta['iso_code'].upcase,
          slug:         slug,
          legislatures: dirs.map { |h| Legislature::Metadata.new(dir: h, commit_metadata: commit_metadata).stanza },
        }
      end

      private

      attr_reader :country, :dirs, :commit_metadata

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
        meta['name'] || country.tr('_', ' ')
      end

      def slug
        dirs.first.split('/').drop(1).first.tr('_', '-')
      end
    end
  end

  class Legislature
    class Metadata
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
          legislative_periods: terms.each do |t|
            t.delete :identifiers
            term_csv_sha = commit_metadata[t[:csv]][:sha]
            t[:csv_url] = remote_source % [term_csv_sha, t[:csv]]
          end,
          statement_count:     statement_count,
          type:                type,
        }
      end

      private

      attr_reader :dir, :commit_metadata

      def json_file
        dir + '/ep-popolo-v1.0.json'
      end

      def name_file
        dir + '/names.csv'
      end

      def remote_source
        'https://cdn.rawgit.com/everypolitician/everypolitician-data/%s/%s'
      end

      def terms
        terms = popolo[:events].select { |o| o[:classification] == 'legislative period' }
        terms.sort_by { |t| t[:start_date].to_s }.reverse.map do |t|
          t.delete :classification
          t.delete :organization_id
          t[:slug] ||= t[:id].split('/').last
          t[:csv] = dir + "/term-#{t[:slug]}.csv"
          t
        end.select { |t| File.exist? t[:csv] }
      end

      def legislature
        orgs = popolo[:organizations].select { |o| o[:classification] == 'legislature' }
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
          json = JSON.load(File.read(json_file), lambda do |h|
            statements += h.values.select { |v| v.class == String }.count if h.class == Hash
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
  end
end
