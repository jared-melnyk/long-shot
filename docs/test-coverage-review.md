# Test Coverage Review

**Date:** 2026-02-28  
**Current suite:** 9 examples across 5 spec files, all passing.

## Current Coverage Summary

| Area | Files | What's tested |
|------|--------|----------------|
| **Models** | `pool_scoring_spec`, `pool_tournament_spec`, `pick_spec` | Pool standings (odds bonus), PoolTournament validations + sync job callback, Pick duplicate-golfer validation |
| **Jobs** | `lock_odds_job_spec` | LockOddsJob creates PoolTournamentOdds from API (double) |
| **Requests** | `landing_spec` | GET / when signed out (content) and signed in (redirect) |

**Not covered:** Most models, all controllers except landing behavior, all services, helpers, and the tournament results display logic.

---

## 1. Add Missing Test Coverage (Prioritized)

### High priority — core behavior

- **`TournamentsHelper`** (e.g. `spec/helpers/tournaments_helper_spec.rb`)
  - `display_place`: solo place (e.g. `1`), tie (`T3`), MC when `prize_money` nil/zero, and `position` nil → MC.
  - `missed_cut?`: true for nil/zero prize_money, false otherwise.
  - Prevents regressions on the new place/name formatting and MC rules.

- **`Tournament` model** (e.g. `spec/models/tournament_spec.rb`)
  - `completed?` (true when `ends_at < Time.current`, false when future/nil).
  - `results_synced_since_completion?` (false when not completed or no `results_synced_at`, true when synced after `ends_at`).
  - `addable_to_pool` scope (excludes tournaments that ended more than 1 day ago).

- **`TournamentResult` model** (e.g. `spec/models/tournament_result_spec.rb`)
  - Uniqueness of `[tournament_id, golfer_id]`.
  - `prize_money` numericality (>= 0, allow_nil).

- **`Pool` model** (expand `spec/models/pool_scoring_spec.rb` or add `spec/models/pool_spec.rb`)
  - `standings` ordering (by total descending).
  - `total_points_for` with no pick → 0; with pick but no results → 0; multiple pool_tournaments/picks.
  - `odds_bonus` behavior when no PoolTournamentOdds (no bonus).

### Medium priority — controllers and flows

- **Tournament results UI and controller**
  - Request spec for tournaments#show: results list present, sync buttons when `external_id` present.
  - Request spec for tournament_results#create (valid/invalid) and #destroy (e.g. as pool admin or same-user flows if applicable).

- **Pools controller**
  - Request spec: index (signed in), show (member vs non-member → show vs show_join), create, join (already in pool vs new join).

- **Tournaments controller**
  - Request spec: show with/without external_id (no auto-sync when no external_id), create with valid/invalid params.

### Lower priority — services and jobs

- **`BallDontLie::SyncTournamentResults`**
  - Unit spec with double client: creates/updates TournamentResult and golfers from API payload, sets `results_synced_at`, returns `{ created, updated, total }`; handles missing player, duplicate tournament+golfer.

- **`BallDontLie::SyncTournamentField`** (and optionally `SyncTournaments`, `SyncPlayers`)
  - Same pattern: double client, assert DB changes and return hash.

- **`SyncTournamentFieldJob`**
  - Performs SyncTournamentField (with double or real service and stubbed client).

### Optional but useful

- **User / PoolUser / Golfer**
  - Basic validations and associations if they encode non-trivial rules.
- **Picks controller**
  - Create/update/destroy and authorization (e.g. only own pick).
- **Sessions / sign-in**
  - Request spec for login success and failure.

---

## 2. Improve or Clean Up Existing Tests

- **Naming and structure**
  - `pool_scoring_spec.rb` is really testing `Pool#standings` and odds bonus; consider renaming to `spec/models/pool_spec.rb` and grouping examples under `describe "#standings"` and `describe "#total_points_for"` (and later `describe "validations"` if you add them). This keeps all Pool behavior in one place.

- **Reduce duplication**
  - Shared setup (user, pool, tournament, golfer, PoolUser, PoolTournament) is repeated. Add `spec/support/` and either:
    - A shared context (e.g. `:pool_with_tournament`) that sets up pool, user, tournament, pool_tournament, and optionally a pick, or
    - Factory Bot (see below) so specs stay short and consistent.

- **Enable optional RSpec features** (in `spec/spec_helper.rb` or `rails_helper.rb`)
  - `config.infer_spec_type_from_file_location!` so `type: :model` / `:request` don’t need to be stated when under `spec/models` / `spec/requests`.
  - `config.example_status_persistence_file_path = "spec/examples.txt"` for `--only-failures` / `--next-failure` (and add `spec/examples.txt` to `.gitignore`).

- **LockOddsJob**
  - Consider one example for “no golfers in field” or “futures returns empty” so the job doesn’t create odds (if that’s the intended behavior).

- **Landing request spec**
  - Already solid. Optionally add one example that the page does not render internal-only links or debug info when not signed in.

---

## 3. Tooling and Conventions

- **Code coverage**
  - Add `simplecov` (and optionally `simplecov-lcov` for CI): require at top of `spec/rails_helper.rb`, run specs, then inspect `coverage/`. Use to find untested branches (e.g. in controllers and helpers), not as a single target number.

- **Factories**
  - Add `factory_bot_rails` and define factories for User, Pool, Tournament, Golfer, PoolUser, PoolTournament, Pick, PickGolfer, TournamentResult, PoolTournamentOdds. Use in new specs and when refactoring existing ones to remove long `create!` chains. Optionally use `build` for validations-only examples.

- **Support files**
  - Create `spec/support/` and in `rails_helper.rb` uncomment:
    - `Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }`
  - Add `spec/support/shared_contexts.rb` (or similar) for shared setup and any shared examples you introduce later.

---

## 4. Suggested Order of Work

1. Add **TournamentsHelper** specs (fast, high value for the new display logic).
2. Add **Tournament** and **TournamentResult** model specs (small, high value).
3. Optionally add **simplecov** and run once to confirm gaps.
4. Expand **Pool** specs (standings edge cases, total_points_for).
5. Add **request specs** for tournaments#show and tournament_results create/destroy, then pools#show / join.
6. Introduce **spec/support** and shared context (or factories) and refactor existing specs to use them.
7. Add **SyncTournamentResults** (and optionally other sync services and SyncTournamentFieldJob).
8. Add remaining controller/request specs as needed.

---

## 5. Quick Reference: What Exists vs Not

| Component | Spec exists? | Notes |
|-----------|--------------|--------|
| Pool#standings, odds bonus | Yes | In pool_scoring_spec |
| Pool total_points_for, validations | No | |
| Tournament completed?, scope, results_synced_since_completion? | No | |
| TournamentResult validations | No | |
| Pick validations (duplicate golfer) | Yes | |
| Pick#total_prize_money | No | |
| PoolTournament validations, callbacks | Yes | |
| TournamentsHelper (display_place, missed_cut?) | No | |
| LockOddsJob | Yes | |
| SyncTournamentFieldJob | No | |
| BallDontLie::Sync* services | No | |
| TournamentsController | No | |
| TournamentResultsController | No | |
| PoolsController | No | |
| PicksController | No | |
| Landing (GET /) | Yes | |
| Sessions, Users | No | |
