class Pool < ApplicationRecord
  has_many :pool_tournaments, dependent: :destroy
  has_many :tournaments, through: :pool_tournaments
  has_many :pool_users, dependent: :destroy
  has_many :users, through: :pool_users

  validates :name, presence: true

  # Standings: total prize money per user from their picks in this pool's tournaments.
  # Returns array of [ user, total_prize_money ] sorted by total descending.
  def standings
    users
      .distinct
      .map { |user| [ user, total_prize_money_for(user) ] }
      .sort_by { |_, total| -total }
  end

  def total_prize_money_for(user)
    Pick
      .where(user: user, tournament: tournaments)
      .sum { |pick| pick.total_prize_money.to_d }
  end
end
