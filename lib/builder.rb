
class EveryPolitician

  class Builder

    class Morph

      require 'fileutils'
      require 'erb'
      require 'csv_to_popolo'

      @@SOURCE_DIR = 'sources/morph'
      @@MORPH_DATA_FILE = @@SOURCE_DIR + '/data.csv'
      @@MORPH_TERM_FILE = @@SOURCE_DIR + '/terms.csv'

      def initialize(src, opts)
        @src = src
        @opts = opts
      end

      def fetch!
        FileUtils.mkpath @@SOURCE_DIR

        File.write(@@MORPH_DATA_FILE, morph_select(data_query))

        if @opts[:get_terms] 
          File.write(@@MORPH_TERM_FILE, morph_select(term_query))
        end
      end

      private
      def morph_select(qs)
        morph_api_key = ENV['MORPH_API_KEY'] or fail 'Need a Morph API key'
        key = ERB::Util.url_encode(morph_api_key)
        query = ERB::Util.url_encode(qs.gsub(/\s+/, ' ').strip)
        url = "https://api.morph.io/#{@src}/data.csv?key=#{key}&query=#{query}"
        warn "Fetching #{url}"
        open(url).read
      end
            
      def data_query
        @opts[:data_query] || 'SELECT * FROM data'
      end

      def term_query
        @opts[:term_query] || 'SELECT * FROM terms'
      end

    end

  end

end
