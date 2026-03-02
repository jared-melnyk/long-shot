# Pool Permissions, Removal Confirmations, and Remove Manual Data-Entry UI — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** (1) Restrict pool management so only the pool creator can add/remove tournaments and remove members; any member can leave the pool (remove themselves). Add confirmation dialogs for all removal actions; hide/block removing tournaments once they have started. (2) Remove all user-facing UI for manually adding golfers, tournaments, or results (API/sync-only for that data).

**Architecture:** Add a `creator_id` (user_id) to the `pools` table and set it on create. Use `pool.creator?(user)` for view/controller checks. Enforce creator-only in `PoolTournamentsController` and for adding/removing other members in `PoolUsersController`; allow any member to remove themselves (leave pool) via the same `PoolUsersController#destroy` (allow if creator OR removing self). In the Members list: show "Leave pool" for the current user on their own row (any member); show "Remove" for other members only when current user is creator. Use Rails Turbo's `data: { turbo_confirm: "..." }` on all removal/leave buttons. For tournament removal, hide the Remove button when `tournament.started?`. For part 2, remove routes, controller actions, and view UI for new/create golfer, new/create tournament, and create/destroy tournament results; keep sync and read-only views where appropriate.

**Tech Stack:** Rails 8.1, Turbo, Stimulus (optional for confirmations; Turbo confirm is sufficient), PostgreSQL.

---

## Part 1: Pool creator and removal tightening

### Task 1: Add pool creator to schema and set on create

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_creator_id_to_pools.rb` (use `bin/rails g migration AddCreatorIdToPools creator_id:bigint`)
- Modify: `app/models/pool.rb` — add `belongs_to :creator, class_name: "User", optional: true` and validation/association as needed
- Modify: `app/controllers/pools_controller.rb` — in `create`, set `@pool.creator = current_user` before save (and ensure creator is added as first member)

**Step 1: Generate migration**

```bash
cd long_shot && bin/rails g migration AddCreatorIdToPools creator_id:bigint
```

Edit the migration to add foreign key and index:

```ruby
# db/migrate/..._add_creator_id_to_pools.rb
class AddCreatorIdToPools < ActiveRecord::Migration[8.1]
  def change
    add_reference :pools, :creator, foreign_key: { to_table: :users }, index: true
  end
end
```

**Step 2: Run migration**

```bash
bin/rails db:migrate
```

Expected: Migration runs without error.

**Step 3: Update Pool model**

In `app/models/pool.rb` add:

```ruby
belongs_to :creator, class_name: "User", optional: true
```

(Optional: add `validates :creator_id, presence: true` if you want to require it for new pools; existing pools will have nil creator_id until backfilled.)

**Step 4: Backfill existing pools (optional but recommended)**

Create a one-off migration or data fix that sets `creator_id` to the first `pool_user`'s user_id per pool (oldest by `pool_users.created_at` or `id`). Example in a migration:

```ruby
 reversible do |dir|
   dir.up do
     execute <<-SQL.squish
       UPDATE pools p
       SET creator_id = (
         SELECT user_id FROM pool_users WHERE pool_id = p.id ORDER BY id ASC LIMIT 1
       )
     SQL
   end
 end
```

Alternatively skip backfill and keep `creator` optional so only new pools have a creator; then in the UI/controller, treat "no creator" as "any member can manage" if you prefer. For this plan we assume backfill so behavior is consistent.

**Step 5: Set creator on new pools**

In `app/controllers/pools_controller.rb` in `create`:

```ruby
@pool = Pool.new(pool_params)
@pool.creator = current_user
if @pool.save
  @pool.pool_users.create!(user: current_user)
  ...
```

**Step 6: Commit**

```bash
git add db/migrate app/models/pool.rb app/controllers/pools_controller.rb
git commit -m "feat: add pool creator and set on create"
```

---

### Task 2: Add Pool#creator? and use in views (creator UI + Leave pool)

**Files:**
- Modify: `app/models/pool.rb` — add `def creator?(user); user.present? && creator_id == user.id; end`
- Modify: `app/views/pools/show.html.erb` — show "Add tournament" and "Add member" only when creator. Show "Remove" (tournament) only when creator and tournament not started. For members: show "Leave pool" on the current user's own row (any member can leave); show "Remove" on other members' rows only when current user is creator (creator can remove anyone).

**Step 1: Add Pool#creator?**

In `app/models/pool.rb`:

```ruby
def creator?(user)
  user.present? && creator_id == user.id
end
```

**Step 2: Restrict pool show view**

In `app/views/pools/show.html.erb`:

- Wrap the "Add tournament" form (the `form_with url: pool_pool_tournaments_path(@pool)` ... and the "Add tournament" submit) in `<% if @pool.creator?(current_user) %> ... <% end %>`.
- Wrap the "Add member" form (the `form_with url: pool_pool_users_path(@pool)` ... and "Add member" submit) in `<% if @pool.creator?(current_user) %> ... <% end %>`.
- For each tournament in the list, show the "Remove" button only if `@pool.creator?(current_user) && !t.started?` (use `Tournament#started?` from Step 3).
- For each member row (iterating `@pool.users` with `u` and `pu = @pool.pool_users.find_by(user: u)`):
  - If `u == current_user`: show a "Leave pool" button that submits DELETE to `pool_pool_user_path(@pool, pu)`. Any member can see and use this on their own row.
  - If `u != current_user`: show "Remove" only when `@pool.creator?(current_user)`; same DELETE to `pool_pool_user_path(@pool, pu)`.
  - Use the same confirmation dialog for both buttons (Task 4).

**Step 3: Add Tournament#started?**

In `app/models/tournament.rb` add:

```ruby
def started?
  starts_at.present? && starts_at <= Time.current
end
```

Use in the view as above: do not show Remove for a tournament when `t.started?`.

**Step 4: Commit**

```bash
git add app/models/pool.rb app/models/tournament.rb app/views/pools/show.html.erb
git commit -m "feat: restrict pool management UI to creator; hide tournament remove when started"
```

---

### Task 3: Enforce creator in PoolTournamentsController and PoolUsersController

**Files:**
- Modify: `app/controllers/pool_tournaments_controller.rb` — in `create` and `destroy`, after loading the pool, check `@pool.creator?(current_user)`; if not, redirect with alert and return.
- Modify: `app/controllers/pool_users_controller.rb` — in `create` (add member) and `destroy` (remove member), ensure only creator can perform; if not creator, redirect with alert.

**Step 1: PoolTournamentsController**

In `create` and `destroy`, after you have `@pool`:

```ruby
unless @pool.creator?(current_user)
  redirect_to @pool, alert: "Only the pool creator can add or remove tournaments."
  return
end
```

In `destroy`, also prevent removal when the tournament has started:

```ruby
if pt.tournament.started?
  redirect_to @pool, alert: "Cannot remove a tournament that has already started."
  return
end
```

**Step 2: PoolUsersController**

In `create`: only creator can add members (invite).

```ruby
unless @pool.creator?(current_user)
  redirect_to @pool, alert: "Only the pool creator can add members."
  return
end
```

In `destroy`: allow if (1) current user is the pool creator (can remove any member), OR (2) current user is removing themselves (leave pool). Otherwise forbid. After a successful destroy, redirect: if they left themselves, redirect to `pools_path` with "You left the pool."; if creator removed someone else, redirect to `@pool` with "Member removed."

```ruby
pu = PoolUser.find(params[:id])
@pool = current_user.pools.find(pu.pool_id)
can_remove = @pool.creator?(current_user) || pu.user_id == current_user.id
unless can_remove
  redirect_to @pool, alert: "Only the pool creator can remove other members. You can leave the pool using Leave pool."
  return
end
pu.destroy!
if pu.user_id == current_user.id
  redirect_to pools_path, notice: "You left the pool."
else
  redirect_to @pool, notice: "Member removed."
end
```

**Step 3: Commit**

```bash
git add app/controllers/pool_tournaments_controller.rb app/controllers/pool_users_controller.rb
git commit -m "feat: enforce creator-only for add/remove tournaments and add/remove members"
```

---

### Task 4: Add confirmation dialog to all removal actions

**Files:**
- Modify: `app/views/pools/show.html.erb` — add `data: { turbo_confirm: "Removal cannot be undone. Are you sure?" }` (or similar) to the Remove button for pool tournaments and to the Remove button for pool members.
- Modify: `app/views/tournaments/show.html.erb` — add the same confirmation to the "Remove" result button (until we remove that UI in Part 2).

**Step 1: Pools show — tournament Remove, member Remove, and Leave pool**

Rails 7+ with Turbo: add confirmation to every delete form. Use a single message, e.g. `"Removal cannot be undone. Are you sure?"`

- Tournament Remove: `form: { class: "inline-block", data: { turbo_confirm: "Removal cannot be undone. Are you sure?" } }`
- Member Remove (creator removing someone else): same.
- Leave pool (member removing self): same `turbo_confirm` on the form so users confirm before leaving.

**Step 2: Tournament result Remove (temporary until Part 2)**

In `app/views/tournaments/show.html.erb`, add `data: { turbo_confirm: "Removal cannot be undone. Are you sure?" }` to the Remove result `button_to` form. (This view will be changed again in Part 2 when we remove manual result add/remove.)

**Step 3: Commit**

```bash
git add app/views/pools/show.html.erb app/views/tournaments/show.html.erb
git commit -m "feat: add confirmation dialog for all removal actions"
```

---

## Part 2: Remove manual data-entry UI (golfers, tournaments, results)

### Task 5: Remove manual add golfer UI and routes

**Files:**
- Modify: `config/routes.rb` — change `resources :golfers, only: [ :index, :new, :create ]` to `resources :golfers, only: [ :index ]`.
- Modify: `app/controllers/golfers_controller.rb` — remove `new` and `create` actions.
- Modify: `app/views/golfers/index.html.erb` — remove the "Add golfer" link and any empty-state copy that says to add golfers manually.
- Delete: `app/views/golfers/new.html.erb` if it exists.

**Step 1: Routes**

In `config/routes.rb`:

```ruby
resources :golfers, only: [ :index ]
```

**Step 2: Controller**

Remove the `new` and `create` methods from `app/controllers/golfers_controller.rb`.

**Step 3: Golfers index view**

Remove the paragraph with "Add golfer" link. Update empty state to something like "No golfers yet. Sync players from the API or add them via sync." (or just "No golfers yet." if sync is elsewhere.)

**Step 4: Delete new view**

```bash
rm app/views/golfers/new.html.erb
```

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/golfers_controller.rb app/views/golfers/index.html.erb
git commit -m "chore: remove manual add golfer UI; golfers from API/sync only"
```

---

### Task 6: Remove manual add tournament UI and routes

**Files:**
- Modify: `config/routes.rb` — change tournaments to `only: [ :index, :show ]` (remove `:new, :create`).
- Modify: `app/controllers/tournaments_controller.rb` — remove `new` and `create` actions.
- Modify: `app/views/tournaments/index.html.erb` — remove "Add tournament" link and adjust empty state.
- Delete: `app/views/tournaments/new.html.erb`.

**Step 1: Routes**

```ruby
resources :tournaments, only: [ :index, :show ] do
  resources :tournament_results, only: [ :create, :destroy ], path: "results"
end
```

(We will remove tournament_results in Task 7.)

**Step 2: Controller**

Remove `new` and `create` from `TournamentsController`.

**Step 3: Tournaments index**

Remove "Add tournament" link; update empty state to something like "No tournaments yet. Sync tournaments from the API."

**Step 4: Delete new view**

```bash
rm app/views/tournaments/new.html.erb
```

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/tournaments_controller.rb app/views/tournaments/index.html.erb
git commit -m "chore: remove manual add tournament UI; tournaments from API/sync only"
```

---

### Task 7: Remove manual add/remove result UI and routes

**Files:**
- Modify: `config/routes.rb` — remove `resources :tournament_results, only: [ :create, :destroy ], path: "results"` from under tournaments (so tournament show no longer has create/destroy result routes).
- Modify: `app/controllers/tournament_results_controller.rb` — remove or restrict `create` and `destroy` (e.g. remove actions and routes so they are no longer reachable; or leave controller but remove routes so UI is gone).
- Modify: `app/views/tournaments/show.html.erb` — remove the "Add result" form and the "Remove" button next to each result. Keep the Results list as read-only. Keep "Sync field" and "Sync results" buttons.

**Step 1: Routes**

Change to:

```ruby
resources :tournaments, only: [ :index, :show ]
```

So no nested `tournament_results` routes.

**Step 2: Tournament results controller**

Either remove the `create` and `destroy` actions or leave them but they will be unreachable (optional: remove the controller file if it only had those two actions and no other entry points). If the controller has other uses, just leave it without routes to create/destroy.

**Step 3: Tournament show view**

- Remove the entire "Add result" form block (the `form_with model: [ @tournament, TournamentResult.new ]` ... through the submit button).
- Remove the "Remove" button from each result line in the Results list. Results list remains read-only.
- Keep the Sync field and Sync results buttons.
- Update copy if it says "or add below" to something like "Field and results can be synced from the API above."

**Step 4: Commit**

```bash
git add config/routes.rb app/controllers/tournament_results_controller.rb app/views/tournaments/show.html.erb
git commit -m "chore: remove manual add/remove result UI; results from API/sync only"
```

---

### Task 8: Verification and cleanup

**Files:**
- Any remaining references to `new_golfer_path`, `new_tournament_path`, `tournament_tournament_results_path` (POST), `tournament_tournament_result_path` (DELETE) in views or tests.

**Step 1: Search for removed routes/paths**

Run:

```bash
grep -r "new_golfer_path\|new_tournament_path\|tournament_tournament_results_path\|tournament_tournament_result_path" app/ spec/ --include="*.erb" --include="*.rb" || true
```

Remove or update any references (e.g. in specs or layout links).

**Step 2: Run tests**

```bash
bin/rails test
# or
bundle exec rspec
```

Fix any failing tests (e.g. specs that hit removed actions or routes).

**Step 3: Manual smoke test**

- Create a pool (you should be creator). Add/remove tournament (only you can); add member (only you can); remove member (only you can). As another user (member, non-creator), confirm they cannot see Add tournament / Add member and cannot see Remove for other members or for tournaments; confirm they do see "Leave pool" on their own row and can leave successfully (redirect to pools list or appropriate page).
- Join pool: non-member can still join via "Join this pool" on the pool show.
- Remove/Leave buttons: confirm dialog appears for pool tournament remove, pool member remove, and Leave pool.
- Tournament that has started: confirm Remove is hidden for that tournament in the pool.
- Golfers index: no "Add golfer". Tournaments index: no "Add tournament". Tournament show: no "Add result" form and no "Remove" on results; Sync buttons still present.

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: fix references and tests after removing manual data-entry UI"
```

---

## Summary checklist

- [ ] Task 1: Migration and model/controller for pool creator
- [ ] Task 2: Pool#creator?, Tournament#started?, view restrictions (creator-only add/remove tournament and add/remove other members; Leave pool for self)
- [ ] Task 3: Controller enforcement (creator-only for tournaments and for adding members; allow destroy if creator OR removing self)
- [ ] Task 4: Confirmation dialog on all removal/leave buttons (pool tournament, pool member Remove, Leave pool; and tournament result until Task 7)
- [ ] Task 5: Remove golfer new/create routes, actions, and "Add golfer" UI
- [ ] Task 6: Remove tournament new/create routes, actions, and "Add tournament" UI
- [ ] Task 7: Remove tournament result create/destroy routes and UI (add result form, remove result button)
- [ ] Task 8: Verification, tests, and smoke test

---

## Execution handoff

Plan complete and saved to `docs/plans/2026-03-01-pool-permissions-and-removal-ui.md`.

**Two execution options:**

1. **Subagent-Driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Parallel Session (separate)** — Open a new session with executing-plans, batch execution with checkpoints.

Which approach do you prefer?
