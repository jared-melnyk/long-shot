class Pick < ApplicationRecord
  belongs_to :user
  belongs_to :tournament
  has_many :pick_golfers, dependent: :destroy
  has_many :golfers, through: :pick_golfers

  validates :tournament_id, uniqueness: { scope: :user_id }

  # Sum of prize money for this pick's golfers in this tournament (from tournament_results).
  def total_prize_money
    TournamentResult.where(tournament: tournament, golfer: golfers).sum(:prize_money)
  end
end
