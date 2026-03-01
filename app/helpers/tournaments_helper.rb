# frozen_string_literal: true

module TournamentsHelper
  # Returns the place string for a single result when displayed in a list of results.
  # - MC for missed cut / $0 (prize_money nil or zero)
  # - T + position when multiple results share the same position (tie)
  # - position otherwise
  def display_place(result, results)
    return "MC" if missed_cut?(result)

    position = result.position
    return "MC" if position.nil?

    count_at_position = results.count do |r|
      !missed_cut?(r) && r.position == position
    end
    count_at_position > 1 ? "T#{position}" : position.to_s
  end

  def missed_cut?(result)
    result.prize_money.nil? || result.prize_money.to_d.zero?
  end
end
