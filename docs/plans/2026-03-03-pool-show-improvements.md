# Pool Show Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance the pool show page so pick visibility, tournament pick windows, and member management all behave according to the new product rules.

**Architecture:** Extend existing pool/tournament/pick views and queries to support per-tournament pick visibility rules, add a global pick-visibility toggle based on tournament state and pick lock timing, and simplify member management UI by removing the “add user” dropdown and moving removal to standings. All changes stay within current Rails MVC patterns and reuse existing models (`Pool`, `Tournament`, `Pick`, `PoolUser`, `PoolTournament`) and partials (`picks/tournament_with_picks`).

**Tech Stack:** Ruby on Rails, ERB views, Stimulus/Turbo (where already used), existing models and helpers.

---

### Task 1: Model-level support for pick visibility and pick window

**Files:**
- Modify: `app/models/tournament.rb`
- Modify: `app/models/pool_tournament.rb` (if present) or create helper methods elsewhere
- Modify: `app/models/pool.rb` (optional helper for visibility)

**Step 1:** Add a `picks_open_at` helper on `Tournament`  
- Implement logic such that picks open exactly 4 days before `starts_at`.  
- E.g. `picks_open_at = starts_at - 4.days`.

**Step 2:** Add predicates for state  
- On `Tournament`, add:
  - `#started?` (if not already present) based on `starts_at <= Time.current`.
  - `#picks_open?` returning `Time.current >= picks_open_at && !started?`.
  - `#picks_locked?` returning `started?` (or, if you already have a lock time separate from start, use that instead).

**Step 3:** Add visibility policy helpers  
- On `PoolTournament` or a helper module, define methods for a given `user`:
  - `#can_view_all_picks?(user)` → true when `tournament.picks_locked?` (or all picks locked).
  - `#can_view_member_picks?(viewer, member)` → true if:
    - `viewer == member` always, OR
    - `can_view_all_picks?(viewer)` is true.
- Keep these as simple Ruby methods; no need for Pundit unless you already use it.

**Step 4:** Add a helper to check if picks are open for pool members  
- On `PoolTournament`, add `#picks_open_for_submission?` that delegates to `tournament.picks_open?`.

**Step 5:** Add basic model specs (if you have tests)  
- For `Tournament`, test `picks_open_at`, `picks_open?`, `picks_locked?` around boundary times.  
- For `PoolTournament`, test `can_view_all_picks?`, `can_view_member_picks?`, and `picks_open_for_submission?` with different tournament times and users.

---

### Task 2: Controller changes to load picks for all pool members

**Files:**
- Modify: `app/controllers/pools_controller.rb`
- (Possibly) Modify: `app/controllers/picks_controller.rb` if it needs visibility logic or shared queries
- Test: relevant controller specs/request specs

**Step 1:** Extend `PoolsController#show` to preload picks for all users in the pool  
- Currently, `@my_picks_by_tournament` only loads picks for `current_user`.  
- Add an instance variable, e.g. `@picks_by_tournament_and_user`, shaped like:

```ruby
# { tournament_id => { user_id => pick } }
```

- Implement with a single query:
  - `Pick.joins(:pool_tournament).where(pool_tournaments: { pool_id: @pool.id, tournament_id: @pool.tournaments.ids }).includes(:user, pick_golfers: :golfer)`
  - Group by `tournament_id` and `user_id`.

**Step 2:** Also load a quick map of which users have submitted picks per tournament and pick slot  
- If picks are 1–4 golfers in a single pick record, you just need to know “pick present or not”.  
- If picks are multiple records per user/tournament/slot, adjust the grouping to:

```ruby
# { tournament_id => { user_id => { slot_number => pick } } }
```

- Store in a separate hash if it simplifies the view.

**Step 3:** Ensure performance is acceptable  
- Confirm via console/logs that the preloading uses a small number of queries (thanks to `.includes`).  
- If needed, add scopes on `Pick`/`PoolTournament` to keep `PoolsController#show` readable.

**Step 4:** Add controller tests  
- For a pool with multiple users and picks:
  - Expect `@picks_by_tournament_and_user` structure to contain picks for all users in the pool, not just the current user.

---

### Task 3: Tournament block UI – show picks per member with visibility rules

**Files:**
- Modify: `app/views/pools/show.html.erb`
- Modify: `app/views/picks/_tournament_with_picks.html.erb` (and/or create a new partial, e.g. `app/views/picks/_tournament_pool_picks.html.erb`)
- Modify: `app/helpers/tournaments_helper.rb` (if helpful for odds formatting, etc.)

**Step 1:** Decide where the “everyone’s picks” UI lives  
- Keep `picks/tournament_with_picks` focused on the current user’s pick summary to minimize disruption.  
- Add a new partial to render the pool-wide picks per tournament, used only on the pool show page.

**Step 2:** Design the “everyone’s picks” table/list  
- For each tournament row in `pools/show.html.erb`, beneath the existing partial, render a table:

  - First column: pool members (`@pool.users.order(:name)`).
  - Next columns: Pick 1–4 (or one column listing all selected golfers, depending on your data model).
  - Show locked American odds next to each golfer (e.g. `Name (+1200)`), using existing odds fields and helpers.

**Step 3:** Implement visibility rules in the view  
- For each cell (member + pick slot/tournament):

  - If `pool_tournament.can_view_all_picks?(current_user)` is true:
    - Show the actual golfers and odds for that member’s pick.
  - Else (tournament not started/locked yet):
    - If `current_user == member`:
      - Show their actual pick(s) and odds.
    - Else:
      - If the member has no pick for that slot:
        - Render “No pick”.
      - If the member has submitted a pick for that slot:
        - Render “Pick submitted”.

- Use `@picks_by_tournament_and_user` to determine presence/absence and to render the full pick when allowed.

**Step 4:** Handle edge cases in the UI  
- Show a small helper message above the table explaining:
  - “Before the tournament starts, you can only see your own picks. After picks lock, all picks become visible.”
- Ensure layout is responsive, given potentially many members.

**Step 5:** Add view specs/system tests  
- Scenario 1: Before picks open:
  - Table present, but all cells show “No pick” or nothing (depending on whether picks are allowed yet).
- Scenario 2: Picks open but tournament not started:
  - Current user sees their full picks; other users show “No pick” / “Pick submitted”.
- Scenario 3: After tournament starts:
  - All users see full picks and odds for everyone.

---

### Task 4: Enforce “picks open 4 days before start” in Make Picks link

**Files:**
- Modify: `app/views/picks/_tournament_with_picks.html.erb` (or wherever the “Make Picks” link currently lives)
- Modify: possibly `app/helpers/tournaments_helper.rb` for formatted “picks open” text

**Step 1:** Use the new `Tournament#picks_open?` predicate  
- Replace any unconditional “Make Picks” link with logic:

```erb
<% if tournament.picks_open? %>
  <%= link_to "Make picks", ... %>
<% else %>
  <span class="text-gray-500 text-sm">
    Picks open on <%= tournament.picks_open_at.to_date.to_s(:long) %>
  </span>
<% end %>
```

- Ensure you handle time zones consistently with `starts_at`.

**Step 2:** Disable the link before picks open  
- Do not render a clickable link before `picks_open?` is true.  
- Optionally, render a `button` styled as disabled (`cursor-not-allowed`, gray text) with no href if you want consistent layout.

**Step 3:** Add tests  
- For a tournament starting 5 days from now:
  - Expect no “Make picks” link; expect text “Picks open on …”.
- For a tournament starting 3 days from now:
  - Expect the normal “Make picks” link.

---

### Task 5: Locking picks and exposing them after lock

**Files:**
- Modify: `app/models/tournament.rb` or existing logic that determines when picks are no longer editable
- Modify: any pick submission paths in `app/controllers/picks_controller.rb`
- Modify: any views showing “Edit picks” or similar
- Tests: model/controller specs

**Step 1:** Ensure picks become non-editable at lock time  
- If you already have a rule “no picks after tournament start”, centralize it in `Tournament#picks_locked?`.  
- In `PicksController` (`new`, `create`, `edit`, `update`), guard with:

```ruby
redirect_to ..., alert: "Picks are locked." if tournament.picks_locked?
```

**Step 2:** Wire visibility rules to `picks_locked?`  
- Ensure `PoolTournament#can_view_all_picks?` returns true when `tournament.picks_locked?` is true.  
- This will automatically flip the UI from “pick submitted” placeholders to real picks when the tournament starts/locks.

**Step 3:** Tests  
- Scenario: tournament started; viewer is any pool member:
  - Picks controller disallows changes.
  - Pool show page table shows all picks.

---

### Task 6: Simplify Members section and move removal to Standings

**Files:**
- Modify: `app/views/pools/show.html.erb`
- Modify: `app/controllers/pool_users_controller.rb` (or equivalent, if changes needed)
- Tests: controller/view/system tests

**Step 1:** Remove “Add member” form and global user dropdown  
- In `pools/show.html.erb`, delete the form at lines 72–77 that lets the pool creator add any `User`:

```erb
<% if @pool.creator?(current_user) %>
  <%= form_with url: pool_pool_users_path(@pool), ... %>
    ...
  <% end %>
<% end %>
```

- Keep the “Leave pool”/“Remove” actions already wired to `PoolUser` deletion.

**Step 2:** Remove or demote the standalone Members section  
- Option A: Remove the Members section entirely.  
- Option B: Keep it minimal (optional) but without any “add member” UI.

**Step 3:** Add per-member “Remove” link under Standings  
- In the Standings section (`pools/show.html.erb` lines 16–25), for each user in `@pool.standings`:

  - Find the corresponding `PoolUser` (e.g. `pu = @pool.pool_users.find_by(user: user)`; consider memoizing in the controller or a helper).
  - If `@pool.creator?(current_user)` and `pu` present:
    - Render a small “Remove from pool” `button_to` underneath the member’s name/total, pointing to `pool_pool_user_path(@pool, pu)` with `method: :delete` and a Turbo confirm, styled as subtle text link.

**Step 4:** Ensure the pool creator cannot add members anywhere else  
- Search for `pool_pool_users_path` usages:
  - Remove any “add member” forms or links.
- Confirm that only “Remove” and “Leave pool” actions remain.

**Step 5:** Tests  
- As pool creator:
  - Visiting pool show should **not** show any dropdown of all users.
  - Each member in standings should have a “Remove” link (except maybe themselves, depending on your rule).
- As normal member:
  - No “Remove” links visible in standings.
  - “Leave pool” still visible where appropriate.

---

### Task 7: UX polish and copy review

**Files:**
- Modify: `app/views/pools/show.html.erb`
- Modify: `app/views/picks/_tournament_with_picks.html.erb`
- Possibly modify: locale files if you use I18n

**Step 1:** Add small explanatory text around the picks table  
- Example above the table:

  - Before lock (when viewing as a member):  
    “You can see only your own picks until the tournament starts. After picks lock, everyone’s picks are revealed.”

- This reduces confusion about placeholders.

**Step 2:** Ensure consistent wording  
- Use “No pick” vs “Pick submitted” exactly as you described:
  - “No pick” when there is no pick record.
  - “Pick submitted” when there is a pick record but it’s hidden.

**Step 3:** Visual styling  
- Make the picks table readable:
  - Alternating row backgrounds.
  - Small font for odds.
  - Responsive layout for mobile (e.g. stack pick details under the member name).

**Step 4:** Smoke test in browser  
- Create a test pool with multiple members, tournaments at different times (past, within 4 days, >4 days).  
- Walk through:
  - Before picks open.
  - After picks open but before tournament start.
  - After tournament start.

---

### Task 8: Documentation and handoff

**Files:**
- Create: `docs/plans/2026-03-03-pool-show-improvements.md` (this plan)
- Modify: `README.md` or any product docs if you maintain feature-level documentation

**Step 1:** Save this plan into the repo  
- Create the `docs/plans` directory if it doesn’t exist.  
- Save this markdown file with the header above.

**Step 2:** Optional: add short feature note  
- In your README or internal docs, add a short section:
  - Explaining pick visibility rules.
  - Explaining when picks open and lock.
  - Explaining how pool membership is managed (creator-only removal via standings).

**Step 3:** Choose execution mode in a new chat  
- In a separate Cursor chat, use superpowers:executing-plans to run through these tasks step by step.  
- After each task, run tests and visually verify in the browser.

---

