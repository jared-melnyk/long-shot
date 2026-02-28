class Tournament < ApplicationRecord
  has_many :pool_tournaments, dependent: :destroy
  has_many :pools, through: :pool_tournaments
  has_many :picks, dependent: :destroy
  has_many :tournament_results, dependent: :destroy

  validates :name, presence: true

  # Tournaments that can be added to a pool: not yet completed. Started-but-not-finished is OK.
  # Completed = ends_at is at least 1 day ago so the final day of play still counts as addable.
  scope :addable_to_pool, -> { where("ends_at IS NULL OR ends_at >= ?", 1.day.ago) }
end
