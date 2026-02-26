# frozen_string_literal: true

class SyncController < ApplicationController
  def index
    @tournaments_with_api_id = Tournament.where.not(external_id: [ nil, "" ]).order(:starts_at)
  end

  def tournaments
    season = (params[:season].presence || Date.current.year).to_i
    result = BallDontLie::SyncTournaments.new(season: season).call
    redirect_to tournaments_path, notice: "Synced tournaments: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)."
  rescue => e
    redirect_to sync_index_path, alert: "Sync failed: #{e.message}"
  end

  def players
    result = BallDontLie::SyncPlayers.new.call
    redirect_to golfers_path, notice: "Synced golfers: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)."
  rescue => e
    redirect_to sync_index_path, alert: "Sync failed: #{e.message}"
  end

  def field
    tournament = Tournament.find(params[:tournament_id])
    result = BallDontLie::SyncTournamentField.new(tournament: tournament).call
    redirect_to golfers_path, notice: "Synced field for #{tournament.name}: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} players)."
  rescue => e
    redirect_to sync_index_path, alert: "Sync failed: #{e.message}"
  end

  def tournament_results
    tournament = Tournament.find(params[:tournament_id])
    result = BallDontLie::SyncTournamentResults.new(tournament: tournament).call
    redirect_to tournament_path(tournament), notice: "Synced results: #{result[:created]} created, #{result[:updated]} updated (#{result[:total]} total)."
  rescue => e
    redirect_to tournament_path(params[:tournament_id]), alert: "Sync failed: #{e.message}"
  end
end
