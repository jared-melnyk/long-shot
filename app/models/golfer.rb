class Golfer < ApplicationRecord
  has_many :pick_golfers, dependent: :restrict_with_error
  has_many :picks, through: :pick_golfers
  has_many :tournament_results, dependent: :destroy
  has_many :tournament_fields, dependent: :destroy

  validates :name, presence: true
end
