# frozen_string_literal: true

module OCD
  class Lookup
    class Plain
      attr_reader :ocd_ids
      attr_reader :overrides
      attr_reader :area_ids

      def initialize(ocd_ids, overrides)
        @ocd_ids = ocd_ids
        @overrides = overrides
        @area_ids = {}
      end

      def from_name(name)
        area_ids[name] ||= area_id_from_name(name)
      end

      private

      def area_id_from_name(name)
        area = override(name) || find(name)
        return if area.nil?

        warn '  Matched Area %s to %s' % [name.yellow, area[:name].to_s.green] unless area[:name].include? " #{name} "
        area[:id]
      end

      def override(name)
        override_id = overrides[name]
        return if override_id.nil?

        { name: name, id: override_id }
      end

      def find(name)
        ocd_ids.find { |i| i[:name] == name }
      end
    end

    class Fuzzy < Plain
      private

      def find(name)
        fuzzer.find(name.to_s, must_match_at_least_one_word: true)
      end

      def fuzzer
        @fuzzer ||= FuzzyMatch.new(ocd_ids, read: :name)
      end
    end
  end
end
