# frozen_string_literal: true

class TournamentField < ApplicationRecord
  belongs_to :tournament
  belongs_to :golfer

  validates :golfer_id, uniqueness: { scope: :tournament_id }
end
