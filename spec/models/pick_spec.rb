require "rails_helper"

RSpec.describe Pick, type: :model do
  describe "duplicate golfers validation" do
    let(:user) { User.create!(name: "User", email: "user@example.com", password: "password") }
    let(:pool) { Pool.create!(name: "Test Pool") }
    let(:tournament) { Tournament.create!(name: "Test Tournament") }
    let(:pool_tournament) { PoolTournament.create!(pool: pool, tournament: tournament) }
    let(:golfer1) { Golfer.create!(name: "Golfer 1", external_id: "1") }

    it "allows unique golfers across slots" do
      pick = Pick.new(user: user, pool_tournament: pool_tournament)
      pick.pick_golfers.build(golfer: golfer1, slot: 1)

      expect(pick).to be_valid
    end

    it "does not allow the same golfer to be selected twice" do
      pick = Pick.new(user: user, pool_tournament: pool_tournament)
      pick.pick_golfers.build(golfer: golfer1, slot: 1)
      pick.pick_golfers.build(golfer: golfer1, slot: 2)

      expect(pick).not_to be_valid
      expect(pick.errors.full_messages).to include("You can't pick the same golfer more than once for a tournament.")
    end
  end

  describe "per-pool picks" do
    let(:user) { User.create!(name: "User", email: "user@example.com", password: "password") }
    let(:tournament) { Tournament.create!(name: "Shared Tournament") }
    let(:pool1) { Pool.create!(name: "Pool 1") }
    let(:pool2) { Pool.create!(name: "Pool 2") }
    let(:pt1) { PoolTournament.create!(pool: pool1, tournament: tournament) }
    let(:pt2) { PoolTournament.create!(pool: pool2, tournament: tournament) }

    it "allows different picks for the same tournament in different pools" do
      pick1 = Pick.create!(user: user, pool_tournament: pt1)
      pick2 = Pick.create!(user: user, pool_tournament: pt2)

      expect(pick1).to be_persisted
      expect(pick2).to be_persisted
    end

    it "does not allow duplicate picks for the same pool_tournament and user" do
      Pick.create!(user: user, pool_tournament: pt1)
      dup = Pick.new(user: user, pool_tournament: pt1)

      expect(dup).not_to be_valid
    end
  end
end
