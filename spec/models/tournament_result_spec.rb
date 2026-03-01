# frozen_string_literal: true

require "rails_helper"

RSpec.describe TournamentResult, type: :model do
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now) }
  let(:golfer) { Golfer.create!(name: "Scottie Scheffler", external_id: "185") }

  describe "validations" do
    it "validates uniqueness of golfer scoped to tournament" do
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000)
      duplicate = TournamentResult.new(tournament: tournament, golfer: golfer, position: 2, prize_money: 500_000)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tournament_id]).to be_present
    end

    it "allows the same golfer in different tournaments" do
      other_tournament = Tournament.create!(name: "PGA", starts_at: 2.days.from_now, ends_at: 5.days.from_now)
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000)
      other = TournamentResult.new(tournament: other_tournament, golfer: golfer, position: 1, prize_money: 2_000_000)
      expect(other).to be_valid
    end

    it "allows nil prize_money" do
      result = TournamentResult.new(tournament: tournament, golfer: golfer, position: 50, prize_money: nil)
      expect(result).to be_valid
    end

    it "allows zero prize_money" do
      result = TournamentResult.new(tournament: tournament, golfer: golfer, position: 80, prize_money: 0)
      expect(result).to be_valid
    end

    it "allows positive prize_money" do
      result = TournamentResult.new(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_500_000)
      expect(result).to be_valid
    end

    it "rejects negative prize_money" do
      result = TournamentResult.new(tournament: tournament, golfer: golfer, position: 1, prize_money: -100)
      expect(result).not_to be_valid
      expect(result.errors[:prize_money]).to be_present
    end
  end
end
