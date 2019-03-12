# frozen_string_literal: true

# TODO: rename as non -er class
class Matcher
  def initialize(existing_rows, instructions, reconciliation_csv = nil)
    @existing_rows = existing_rows
    @instructions  = instructions
    @reconciliation_csv = reconciliation_csv
  end

  private

  attr_reader :existing_rows, :instructions, :reconciliation_csv

  def existing_field
    instructions[:existing_field].to_sym rescue raise('Need an `existing_field` to match on')
  end

  def incoming_field
    instructions[:incoming_field].to_sym rescue raise('Need an `incoming_field` to match on')
  end
end

class Matcher::Reconciled < Matcher
  def find_all(incoming_row)
    match = prereconciled[incoming_row[:id].to_s] or return []
    existing[match]
  end

  private

  def existing
    @existing ||= existing_rows.group_by { |row| row[:uuid].to_s }
  end

  def prereconciled
    return {} unless reconciliation_csv

    @prereconciled ||= reconciliation_csv.map { |row| row.values_at(:id, :uuid) }.to_h
  end
end

class Matcher::Exact < Matcher
  def find_all(incoming_row)
    incoming = incoming_row[incoming_field]
    return [] if incoming.to_s.empty?

    existing[incoming.downcase] || []
  end

  private

  def existing
    @existing ||= existing_rows.group_by { |row| row[existing_field].to_s.downcase }
  end
end
