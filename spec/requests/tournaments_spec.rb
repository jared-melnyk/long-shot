# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tournaments", type: :request do
  let(:user) { User.create!(name: "Test User", email: "test@example.com", password: "password") }

  before { post login_path, params: { email: user.email, password: "password" } }

  describe "GET /tournaments/:id" do
    it "returns success and shows the tournament" do
      tournament = Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now)
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Masters")
      expect(response.body).to include("Results")
    end

    it "shows sync buttons when tournament has external_id" do
      tournament = Tournament.create!(name: "PGA", starts_at: 1.day.from_now, ends_at: 4.days.from_now, external_id: "20")
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sync field")
      expect(response.body).to include("Sync results from API")
    end

    it "shows results list when tournament has results" do
      tournament = Tournament.create!(name: "Open", starts_at: 1.day.from_now, ends_at: 4.days.from_now)
      golfer = Golfer.create!(name: "Scottie Scheffler", external_id: "185")
      TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000)
      get tournament_path(tournament)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Scottie Scheffler")
      expect(response.body).to include("1 —")
    end
  end

  describe "POST /tournaments/:tournament_id/results" do
    let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now) }
    let(:golfer) { Golfer.create!(name: "Rory McIlroy", external_id: "282") }

    it "creates a result and redirects to tournament" do
      expect {
        post tournament_tournament_results_path(tournament), params: { tournament_result: { golfer_id: golfer.id, position: 1, prize_money: 2_000_000 } }
      }.to change { tournament.tournament_results.count }.by(1)

      expect(response).to redirect_to(tournament_path(tournament))
      follow_redirect!
      expect(response.body).to include("Rory McIlroy")
    end

    it "redirects with alert when validation fails" do
      post tournament_tournament_results_path(tournament), params: { tournament_result: { golfer_id: golfer.id, position: 1, prize_money: -100 } }
      expect(response).to redirect_to(tournament_path(tournament))
      expect(flash[:alert]).to be_present
    end
  end

  describe "DELETE /tournaments/:tournament_id/results/:id" do
    let(:tournament) { Tournament.create!(name: "Masters", starts_at: 1.day.from_now, ends_at: 4.days.from_now) }
    let(:golfer) { Golfer.create!(name: "Rory McIlroy", external_id: "282") }
    let!(:result) { TournamentResult.create!(tournament: tournament, golfer: golfer, position: 1, prize_money: 1_000_000) }

    it "destroys the result and redirects to tournament" do
      expect {
        delete tournament_tournament_result_path(tournament, result)
      }.to change { tournament.tournament_results.count }.by(-1)

      expect(response).to redirect_to(tournament_path(tournament))
      follow_redirect!
      expect(flash[:notice]).to eq("Result removed.")
    end
  end
end
