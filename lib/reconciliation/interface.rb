# frozen_string_literal: true

module Reconciliation
  # Produce an HTML interface for reconciling incoming data
  class Interface
    attr_reader :merged_rows
    attr_reader :incoming_data
    attr_reader :previously_reconciled
    attr_reader :merge_instructions

    def initialize(merged_rows, incoming_data, previously_reconciled, merge_instructions)
      @merged_rows = merged_rows
      @incoming_data = incoming_data
      @previously_reconciled = previously_reconciled
      @merge_instructions = merge_instructions
    end

    def html
      template.render
    end

    private

    def template
      @template ||= Template.new(
        to_reconcile:   to_reconcile,
        reconciled:     previously_reconciled,
        incoming_field: merge_instructions[:incoming_field],
        existing_field: merge_instructions[:existing_field]
      )
    end

    def need_reconciling
      done = Set.new(previously_reconciled.map { |r| r[:id].to_s })
      incoming_data.reject { |r| done.include? r[:id].to_s }
    end

    def to_reconcile
      @to_reconcile ||= fuzzer.score_all.sort_by do |row|
        [
          # Order first by how good the first match is
          row[:existing][0][1],
          # and then how bad the second (i.e. more confident that first is better)
          -(row[:existing][1] ? row[:existing][1][1] : 0),
        ]
      end.reverse rescue binding.pry
    end

    def fuzzer
      @fuzzer ||= Fuzzer.new(merged_rows, need_reconciling, merge_instructions)
    end
  end
end
