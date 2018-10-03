# frozen_string_literal: true

require_relative 'csv'

module Source
  class Person < CSV
    # TODO: change logic so that headers are gathered _after_ merge, rather
    # than before, so we don't need an extra field
    attr_reader :additional_headers

    def person_data?
      true
    end

    # TODO: split this up. This version was migrated directly from the
    # original Rakefile approach, so is still doing too many things.
    def merged_with(csv)
      abort "No merge instructions for #{filename}" unless merge_instructions
      reconciler = Reconciler.new(merge_instructions, ENV['GENERATE_RECONCILIATION_INTERFACE'], csv, as_table)

      if reconciler.filename
        pr = reconciler.reconciliation_data rescue abort($ERROR_INFO.to_s)
        matcher = Matcher::Reconciled.new(csv, merge_instructions, pr)
      else
        matcher = Matcher::Exact.new(csv, merge_instructions)
      end

      unmatched = []
      @additional_headers = Set.new

      as_table.each do |incoming_row|
        incoming_row[:identifier__wikidata] ||= incoming_row[:id] if i(:type) == 'wikidata'

        to_patch = matcher.find_all(incoming_row)
        if to_patch && !to_patch.size.zero?
          # Be careful to take a copy and not delete from the core list
          to_patch = to_patch.select { |r| r[:term].to_s == incoming_row[:term].to_s } if merge_instructions[:term_match]
          uids = to_patch.map { |r| r[:uuid] }.uniq
          if uids.count > 1
            add_warning "Error: trying to patch multiple people: #{uids.join('; ')}".red.on_yellow
            next
          end
          to_patch.each do |existing_row|
            patcher = Patcher.new(existing_row, incoming_row, merge_instructions[:patch])
            existing_row = patcher.patched
            @additional_headers |= patcher.new_headers.to_a
            patcher.warnings.each { |w| add_warning w }
          end
        else
          unmatched << incoming_row
        end
      end

      if unmatched.any? && merge_instructions.dig(:report_missing) != false
        add_warning '* %d of %d unmatched'.magenta % [unmatched.count, as_table.count]
        unmatched.sample(10).each do |r|
          add_warning "\t#{r.to_hash.reject { |_, v| v.to_s.empty? }.select { |k, _| %i[id name].include? k }}"
        end
      end

      csv
    end
  end
end
