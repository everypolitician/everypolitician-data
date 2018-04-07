# frozen_string_literal: true

# Patch an existing row, with data from an incoming row
# according to a set of instructions
class Patcher
  attr_reader :existing, :incoming, :instructions, :warnings

  def initialize(existing, incoming, instructions = {})
    @existing = existing
    @incoming = incoming
    @instructions = instructions || {}
    @new_headers = Set.new
    @warnings = []
  end

  def instruction(field)
    instructions.fetch(field, nil)
  end

  def new_headers
    @new_headers.to_a
  end

  # TODO: this is a mess, and needs to be refactored and tested
  def patched
    fields.each do |h|
      next if incoming[h].to_s.empty?

      # If we didn't have anything before, take the new version
      if existing[h].to_s.empty? || existing[h].to_s.casecmp('unknown').zero?
        existing[h] = incoming[h]
        next
      end

      # These are _expected_ to be different on a term-by-term basis
      next if %i[term group group_id area area_id].include? h

      # Can't do much yet with these ones
      next if %i[source given_name family_name].include? h

      # Accept multiple values for multi-lingual names
      if h.to_s.start_with? 'name__'
        existing[h] += ';' + incoming[h]
        next
      end

      # TODO: accept multiple values for :website, etc.
      next if %i[website].include? h

      # Accept values from multiple sources for given fields
      if %i[email twitter facebook image].include? h
        existing[h] = [existing[h], incoming[h]].join(';').split(';').map(&:strip).uniq(&:downcase).join(';')
        next
      end

      # If we have the same as before (case insensitively), that's OK
      next if existing[h].casecmp(incoming[h].downcase).zero?

      # Accept more precise dates
      if h.to_s.include?('date')
        if incoming[h].include?(existing[h])
          existing[h] = incoming[h]
          next
        end
        # Ignore less precise dates
        next if existing[h].include?(incoming[h])
      end

      # Store alternate names for `other_names`
      if h == :name
        @new_headers << :alternate_names
        existing[:alternate_names] ||= nil
        existing[:alternate_names] = [existing[:alternate_names], incoming[:name]].compact.join(';')
        next
      end

      @warnings << "  ☁ Mismatch in #{h} for #{existing[:uuid]} (#{existing[h]}) vs #{incoming[h]} (for #{incoming[:id]})"
    end

    existing
  end

  # skip these fields (e.g. UK Commons)
  def to_ignore
    instruction(:ignore).to_a.map(&:to_sym).to_set
  end

  def fields
    incoming.keys.reject { |h| h == :id || to_ignore.include?(h) }
  end
end
