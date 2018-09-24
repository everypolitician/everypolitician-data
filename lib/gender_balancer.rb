# frozen_string_literal: true

# Calculate results from a Gender-Balance API data file
class GenderBalancer
  # a single result from the CSV file
  class Result
    # TODO: pass these to the constructor
    MIN_SELECTIONS = 5   # accept gender if at least this many votes
    VOTE_THRESHOLD = 0.8 # and at least this ratio of votes were for it

    attr_reader :row

    def initialize(row)
      @row = row
    end

    def uuid
      row[:uuid]
    end

    def winner
      return if total < MIN_SELECTIONS

      %w[male female other].find { |g| percent(g) >= VOTE_THRESHOLD }
    end

    private

    def total
      row[:total].to_i - row[:skip].to_i
    end

    def percent(gender)
      row[gender.to_sym].to_f / total.to_f
    end
  end

  attr_reader :raw

  def initialize(raw)
    @raw = raw
  end

  def results
    Hash[raw.map do |r|
      res = Result.new(r)
      [res.uuid, res.winner]
    end]
  end

  private

  def enough_votes
    @enough_votes ||= raw.reject { |r| (r[:total] -= r[:skip]) < MIN_SELECTIONS }
  end
end
