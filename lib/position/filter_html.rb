# frozen_string_literal: true

require 'json'

class Position
  class Filter
    class HTML
      def initialize(json)
        @json = json
      end

      def html
        "<html><head>#{head}</head><body>#{body}</body>"
      end

      private

      def unknown
        @json[:unknown][:unknown]
      end

      def head
        scripts
      end

      def body
        '<div id="data">%s</div><div><pre id="results" /></div></body></html>' %
          unknown.map { |p| "<p data-id='#{p[:id]}'>#{p[:name]} <small>(#{p[:description]})</small></p>" }.join("\n")
      end

      def scripts
        ['https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js', '.position-filter.js'].map do |src|
          %(<script src="#{src}"></script>)
        end.join
      end
    end
  end
end
