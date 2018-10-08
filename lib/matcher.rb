# frozen_string_literal: true

class Matcher
  def initialize(existing_rows, instructions, reconciled_csv = nil)
    @_existing_rows = existing_rows
    @_instructions  = instructions
    warn "Deprecated use of 'overrides'".cyan if @_instructions.include? :overrides
    @_existing_field = instructions[:existing_field].to_sym rescue raise('Need an `existing_field` to match on')
    @_incoming_field = instructions[:incoming_field].to_sym rescue raise('Need an `incoming_field` to match on')
    @_reconciled = reconciled_csv ? Hash[reconciled_csv.map { |r| [r.to_hash.values[0].to_s, r.to_hash] }] : {}
  end

  def existing
    @existing ||= @_existing_rows.group_by { |r| r[@_existing_field].to_s.downcase }
  end

  def existing_by_uuid
    @existing_by_uuid ||= @_existing_rows.group_by { |r| r[:uuid].to_s }
  end
end

class Matcher::Reconciled < Matcher
  def find_all(incoming_row)
    if match = @_reconciled[incoming_row[:id].to_s]
      return existing_by_uuid[match[:uuid].to_s] if match[:uuid]
    end
    []
  end
end

class Matcher::Exact < Matcher
  def find_all(incoming_row)
    return [] if incoming_row[@_incoming_field].to_s.empty?

    if exact_match = existing[incoming_row[@_incoming_field].downcase]
      return exact_match
    end

    []
  end
end
