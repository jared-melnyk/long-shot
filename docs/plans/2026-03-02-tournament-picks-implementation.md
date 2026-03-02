 # Tournament Picks Implementation Plan

 > **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

 **Goal:** Update the data model and application code so that picks are scoped to a specific pool–tournament pair (`PoolTournament`), allowing different picks for the same tournament in different pools.

 **Architecture:** `Pick` will belong to `PoolTournament` instead of `Tournament`. We will migrate the `picks` table to reference `pool_tournaments`, update all usages to query by `(user, pool_tournament)` scoped to a pool, and keep views indexing by `tournament_id` via delegation.

 **Tech Stack:** Ruby on Rails, ActiveRecord, RSpec.

 ---

 ### Task 1: Migrate picks to belong_to PoolTournament

 **Files:**
 - Create: `db/migrate/<timestamp>_change_picks_to_pool_tournament.rb`
 - Modify: `db/schema.rb` (generated)

 **Step 1: Add migration to introduce pool_tournament_id and backfill**

 - Create a migration that:
   - Adds `pool_tournament_id` (nullable at first) with a foreign key to `pool_tournaments`.
   - Deletes picks whose tournaments are not present in any `PoolTournament`.
   - Sets `pool_tournament_id` for remaining picks by picking the first `pool_tournaments.id` where `pool_tournaments.tournament_id = picks.tournament_id`.
   - Makes `pool_tournament_id` non-nullable.
   - Drops the `[user_id, tournament_id]` unique index and the `tournament` reference.
   - Adds a unique index on `[user_id, pool_tournament_id]`.

 **Step 2: Run migration**

 - Run: `bin/rails db:migrate`
 - Expected: migration succeeds with no errors.

 ### Task 2: Update Pick model and associations

 **Files:**
 - Modify: `app/models/pick.rb`

 **Step 1: Update associations and validations**

 - Change `Pick` to:
   - `belongs_to :user`
   - `belongs_to :pool_tournament`
   - Remove `belongs_to :tournament`.
   - Validate uniqueness of `pool_tournament_id` scoped to `user_id`.

 **Step 2: Delegate tournament helpers**

 - Add delegation from `Pick` to `pool_tournament`:
   - `delegate :tournament, :tournament_id, to: :pool_tournament`

 **Step 3: Update total_prize_money**

 - Change `total_prize_money` to use `tournament` via the delegated association instead of the removed `tournament` foreign key.

 ### Task 3: Update Pool scoring logic and controllers

 **Files:**
 - Modify: `app/models/pool.rb`
 - Modify: `app/controllers/picks_controller.rb`
 - Modify: `app/controllers/pools_controller.rb`

 **Step 1: Update Pool#total_points_for**

 - Change pick lookup from `Pick.find_by(user: user, tournament: tournament)` to `Pick.find_by(user: user, pool_tournament: pool_tournament)`.
 - Use `pool_tournament.tournament` where the tournament was previously used directly.

 **Step 2: Update PicksController#index scope**

 - Replace `Pick.where(user: current_user, tournament: @tournaments)` with a join through `pool_tournaments` scoped to `@pool`, and continue to index the result by `tournament_id` from the delegated method.

 **Step 3: Update PicksController#new/#create to use pool_tournament**

 - In `set_tournament`, also load `@pool_tournament = @pool.pool_tournaments.find_by!(tournament: @tournament)`.
 - Replace `Pick.find_or_initialize_by(user: current_user, tournament: @tournament)` with `Pick.find_or_initialize_by(user: current_user, pool_tournament: @pool_tournament)`.

 **Step 4: Update PicksController#set_pick and edit/update**

 - Update `picks_scope` to join `pool_tournaments` and scope by `@pool`.
 - Use `@pick.tournament` via delegation where the controller previously used `@pick.tournament`.

 **Step 5: Update PoolsController#show picks lookup**

 - Replace `Pick.where(user: current_user, tournament: @pool.tournaments)` with a join through `pool_tournaments` scoped to `@pool`, indexing by `tournament_id`.

 ### Task 4: Update and extend tests

 **Files:**
 - Modify: `spec/models/pool_spec.rb`
 - Modify: `spec/models/pick_spec.rb`

 **Step 1: Update existing specs to create picks via PoolTournament**

 - In `Pool` specs, replace `Pick.create!(user: user, tournament: tournament)` with `Pick.create!(user: user, pool_tournament: PoolTournament.find_by!(pool: pool, tournament: tournament))`.

 **Step 2: Update Pick specs to use PoolTournament**

 - Create a `Pool` and `PoolTournament` in the setup and initialize `Pick` with `pool_tournament: pool_tournament` instead of `tournament: tournament`.

 **Step 3: Add spec for per-pool picks**

 - Add a spec that verifies a user can create different picks for the same tournament in two different pools (distinct `PoolTournament` rows) and that the uniqueness validation only applies within a single `pool_tournament`.

 **Step 4: Run test suite**

 - Run: `bin/rspec`
 - Expected: all specs pass, including the new per-pool picks behavior tests.

