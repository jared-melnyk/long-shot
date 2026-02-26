# frozen_string_literal: true

module BallDontLie
  # Optional: sync all players from API (e.g. rake task). Normal flow is to let golfers be created when syncing tournament results.
  class SyncPlayers
    def initialize(client: nil)
      @client = client || Client.new
    end

    def call
      api_players = @client.fetch_all_players
      created = updated = 0
      api_players.each do |p|
        rec = Golfer.find_or_initialize_by(external_id: p["id"].to_s)
        rec.name = p["display_name"].presence || [ p["first_name"], p["last_name"] ].compact.join(" ")
        if rec.new_record?
          rec.save!
          created += 1
        elsif rec.changed?
          rec.save!
          updated += 1
        end
      end
      { created: created, updated: updated, total: api_players.size }
    end
  end
end
