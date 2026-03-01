# frozen_string_literal: true

RSpec.shared_context "pool with tournament" do
  let(:pool) { Pool.create!(name: "Test Pool") }
  let(:user) { User.create!(name: "User", email: "user@example.com", password: "password") }
  let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: "20") }
  let(:golfer) { Golfer.create!(name: "Golfer", external_id: "185") }

  before do
    PoolUser.create!(pool: pool, user: user)
    PoolTournament.create!(pool: pool, tournament: tournament)
  end
end
