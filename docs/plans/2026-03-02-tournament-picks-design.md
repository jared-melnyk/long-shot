 # Tournament Picks Per Pool Design

 **Goal:** Allow a user to make different picks for the same tournament in different pools by scoping picks to a specific pool–tournament pairing instead of just the tournament.

 **Current state:**
 - `Pick` belongs to `user` and `tournament` and enforces uniqueness on `[user_id, tournament_id]`.
 - `Pool` connects to `Tournament` through `PoolTournament`.
 - Controllers and `Pool#total_points_for` look up picks by `user` and `tournament`, so one pick is effectively shared across all pools that include that tournament.

 **Chosen architecture (Approach 2):**
 - Change `Pick` to `belongs_to :pool_tournament` (and still `belongs_to :user`).
 - Remove the direct `tournament` foreign key from `picks` and replace it with `pool_tournament_id`.
 - Enforce uniqueness on `[user_id, pool_tournament_id]` so a user gets at most one pick per pool per tournament.
 - Delegate `tournament` and `tournament_id` from `Pick` to its `pool_tournament` so existing views can still index picks by `tournament_id` without major changes.

 **Data migration strategy:**
 - Add `pool_tournament_id` to `picks`.
 - For each existing pick, look up a `PoolTournament` row with the same `tournament_id` and assign the first match to `pool_tournament_id`.
 - Delete any picks whose tournaments are not present in any `PoolTournament` (these are most likely test or dev artifacts).
 - Make `pool_tournament_id` non-nullable, remove the old `tournament_id` column and `[user_id, tournament_id]` index, and add a unique index on `[user_id, pool_tournament_id]`.

 **Behavior and usage changes:**
 - Controllers that previously did `Pick.where(user: current_user, tournament: @tournaments)` will instead join through `pool_tournaments` and scope by `pool_id`, but they can still index by `tournament_id` via delegation.
 - `Pool#total_points_for` will look up picks by `(user, pool_tournament)` instead of `(user, tournament)` so scores are per pool.
 - The duplicate-golfer validation and prize-money calculations will switch to using `pick.tournament` via the delegated association; scoring behavior remains the same.

