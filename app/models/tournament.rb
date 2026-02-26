class Tournament < ApplicationRecord
  has_many :pool_tournaments, dependent: :destroy
  has_many :pools, through: :pool_tournaments
  has_many :picks, dependent: :destroy
  has_many :tournament_results, dependent: :destroy

  validates :name, presence: true
end
