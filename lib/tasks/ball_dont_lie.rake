# frozen_string_literal: true

namespace :ball_dont_lie do
  desc "Sync tournaments from BALLDONTLIE API (default: current year). Usage: rake ball_dont_lie:tournaments [SEASON=2025]"
  task tournaments: :environment do
    season = (ENV["SEASON"].presence || Date.current.year).to_i
    result = BallDontLie::SyncTournaments.new(season: season).call
    puts "Tournaments: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)"
  end

  desc "Sync golfers (active only, default 250). Usage: rake ball_dont_lie:players [LIMIT=250]"
  task players: :environment do
    limit = (ENV["LIMIT"].presence || 250).to_i
    result = BallDontLie::SyncPlayers.new(limit: limit).call
    puts "Golfers: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)"
  end

  desc "Sync tournament results from API. Usage: rake ball_dont_lie:tournament_results TOURNAMENT_ID=6"
  task tournament_results: :environment do
    id = ENV["TOURNAMENT_ID"]
    raise "Set TOURNAMENT_ID (our Tournament id or external_id)" if id.blank?
    t = Tournament.find_by(id: id) || Tournament.find_by(external_id: id)
    raise "Tournament not found: #{id}" unless t
    result = BallDontLie::SyncTournamentResults.new(tournament: t).call
    puts "Results: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)"
  end
end
