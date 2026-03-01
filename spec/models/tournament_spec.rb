# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tournament, type: :model do
  describe "#completed?" do
    it "returns true when ends_at is in the past" do
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: 2.days.ago)
      expect(tournament.completed?).to be true
    end

    it "returns false when ends_at is in the future" do
      tournament = Tournament.create!(name: "Future", starts_at: 1.day.from_now, ends_at: 4.days.from_now)
      expect(tournament.completed?).to be false
    end

    it "returns false when ends_at is nil" do
      tournament = Tournament.create!(name: "No end", starts_at: 1.day.ago, ends_at: nil)
      expect(tournament.completed?).to be false
    end
  end

  describe "#results_synced_since_completion?" do
    it "returns false when tournament is not completed" do
      tournament = Tournament.create!(name: "Future", starts_at: 1.day.from_now, ends_at: 4.days.from_now, results_synced_at: 1.day.from_now)
      expect(tournament.results_synced_since_completion?).to be false
    end

    it "returns false when completed but results_synced_at is blank" do
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: 2.days.ago, results_synced_at: nil)
      expect(tournament.results_synced_since_completion?).to be false
    end

    it "returns true when completed and results_synced_at is after ends_at" do
      ends_at = 2.days.ago
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: ends_at, results_synced_at: 1.day.ago)
      expect(tournament.results_synced_since_completion?).to be true
    end

    it "returns true when completed and results_synced_at equals ends_at" do
      ends_at = 2.days.ago
      tournament = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: ends_at, results_synced_at: ends_at)
      expect(tournament.results_synced_since_completion?).to be true
    end
  end

  describe ".addable_to_pool" do
    it "includes tournaments with nil ends_at" do
      t = Tournament.create!(name: "No end", starts_at: 1.day.from_now, ends_at: nil)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "includes tournaments ending in the future" do
      t = Tournament.create!(name: "Future", starts_at: 1.day.from_now, ends_at: 3.days.from_now)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "includes tournaments that ended less than 1 day ago" do
      t = Tournament.create!(name: "Just ended", starts_at: 5.days.ago, ends_at: 12.hours.ago)
      expect(described_class.addable_to_pool).to include(t)
    end

    it "excludes tournaments that ended more than 1 day ago" do
      t = Tournament.create!(name: "Past", starts_at: 5.days.ago, ends_at: 2.days.ago)
      expect(described_class.addable_to_pool).not_to include(t)
    end
  end
end
