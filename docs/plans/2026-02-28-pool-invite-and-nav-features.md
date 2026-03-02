# Pool Start Date, Invite CTA, and Left Navigation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** (1) Show pool start date (derived from first tournament) on the pool page; (2) Add an “Invite to pool” CTA that copies a join link and ensure unauthenticated visitors are prompted to sign in/register then can join; (3) Move bottom-of-page navigation links into a left sidebar.

**Architecture:** Pool start date is derived in the model (no new column). Invite flow uses existing `pool_path`/`pool_url`; `require_login` stores `request.original_url` in `session[:return_to]` and sessions/users controllers redirect there after auth. Left nav is a new sidebar in the application layout (when signed in), with global links (Pools, Tournaments, Golfers, Sync) and optional pool-context links (pool name, My picks); all bottom-of-page nav links are removed from individual views.

**Tech Stack:** Rails 8, ERB, Tailwind CSS, vanilla JS or Stimulus for clipboard (navigator.clipboard.writeText).

---

## Part 1: Pool start date

### Task 1: Pool start_date and display

**Files:**
- Modify: `app/models/pool.rb`
- Modify: `app/views/pools/show.html.erb`
- Test: `spec/models/pool_spec.rb` (add examples for `start_date`)

**Step 1: Write the failing test**

In `spec/models/pool_spec.rb`, add:

```ruby
describe "#start_date" do
  it "returns the starts_at of the first tournament by start time when pool has tournaments" do
    early = Tournament.create!(name: "Early", starts_at: 1.week.from_now, ends_at: 2.weeks.from_now)
    late = Tournament.create!(name: "Late", starts_at: 2.weeks.from_now, ends_at: 3.weeks.from_now)
    PoolTournament.create!(pool: pool, tournament: late)
    PoolTournament.create!(pool: pool, tournament: early)
    expect(pool.start_date).to eq(early.starts_at)
  end

  it "returns nil when pool has no tournaments" do
    expect(pool.start_date).to be_nil
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/pool_spec.rb -e "start_date" -v`  
Expected: FAIL (undefined method `start_date` or wrong value)

**Step 3: Implement Pool#start_date**

In `app/models/pool.rb`, add:

```ruby
# Start date of the pool = start date of the first tournament (by starts_at).
def start_date
  tournaments.order(:starts_at).limit(1).pick(:starts_at)
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/models/pool_spec.rb -e "start_date" -v`  
Expected: PASS

**Step 5: Display on pool show**

In `app/views/pools/show.html.erb`, below the `<h1>` (e.g. after line 1), add:

```erb
<% if @pool.start_date.present? %>
  <p class="text-gray-600 mb-4">Starts <%= l(@pool.start_date, format: :long) %></p>
<% end %>
```

(Use `l` with a format; if no locale is set, use `@pool.start_date.strftime("%B %d, %Y")` or add a helper.)

**Step 6: Commit**

```bash
git add app/models/pool.rb app/views/pools/show.html.erb spec/models/pool_spec.rb
git commit -m "feat: show pool start date from first tournament on pool page"
```

---

## Part 2: Invite CTA and join-after-login flow

### Task 2: Invite CTA that copies pool link

**Files:**
- Modify: `app/views/pools/show.html.erb`
- Create: `app/javascript/controllers/clipboard_controller.js` (if using Stimulus) OR inline script in a partial / layout

**Step 1: Add Invite CTA and copy behavior (vanilla JS)**

On the pool show page, add a button that copies `pool_url(@pool)` to the clipboard and gives feedback. No new route; link is the existing pool URL (so when opened by someone else they see the pool and, if not logged in, get redirected to login with return_to, then back to pool to join).

In `app/views/pools/show.html.erb`, add after the `<h1>` / start date block (e.g. after the start_date paragraph), only when the user is a member (they’re already on show, not show_join):

```erb
<p class="mb-4">
  <button type="button"
          data-invite-url="<%= pool_url(@pool) %>"
          data-controller="clipboard"
          data-action="click->clipboard#copy"
          class="rounded px-4 py-2 text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700">
    Invite to pool
  </button>
  <span data-clipboard-target="feedback" class="ml-2 text-sm text-gray-600 hidden">Link copied!</span>
</p>
```

Create a Stimulus controller that copies the URL and shows the feedback span. If the project has no Stimulus, use a simple inline script instead (see Step 3 alternative).

**Step 2: Create Stimulus clipboard controller**

Create `app/javascript/controllers/clipboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["feedback"]

  copy(event) {
    const url = this.element.dataset.inviteUrl || this.urlValue
    if (!url) return
    navigator.clipboard.writeText(url).then(() => {
      if (this.hasFeedbackTarget) {
        this.feedbackTarget.classList.remove("hidden")
        setTimeout(() => this.feedbackTarget.classList.add("hidden"), 2000)
      }
    })
  }
}
```

Wire the button with `data-clipboard-url-value="<%= pool_url(@pool) %>"` if using value. Otherwise `data-invite-url` is enough; in the controller use `this.element.dataset.inviteUrl`. Ensure the controller is registered (e.g. in `application.js` or `controllers/index.js`: `import ClipboardController from "./controllers/clipboard_controller"` and `application.register("clipboard", ClipboardController)`).

**Alternative (no Stimulus):** In the same view, add a button with `onclick` that runs a small script reading the URL from a `data-url` attribute and calling `navigator.clipboard.writeText(url)`, then toggling a “Link copied!” span.

**Step 3: Run manual check**

Open pool show, click “Invite to pool”, paste in another tab; confirm the URL is the pool page.

**Step 4: Commit**

```bash
git add app/views/pools/show.html.erb app/javascript/controllers/clipboard_controller.js
git commit -m "feat: add Invite to pool CTA that copies pool link to clipboard"
```

### Task 3: Return-to after login/signup

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/sessions_controller.rb`
- Modify: `app/controllers/users_controller.rb`

**Step 1: Store return_to in session when redirecting to login**

In `app/controllers/application_controller.rb`, in `require_login`, before `redirect_to login_path`:

```ruby
def require_login
  return if current_user
  session[:return_to] = request.original_url
  redirect_to login_path, alert: "Please sign in."
end
```

**Step 2: Redirect to return_to after sign-in**

In `app/controllers/sessions_controller.rb`, in `create`, after setting `session[:user_id]`:

```ruby
redirect_to session.delete(:return_to).presence || root_path, notice: "Signed in."
```

**Step 3: Redirect to return_to after sign-up**

In `app/controllers/users_controller.rb`, in `create`, after setting `session[:user_id]`:

```ruby
redirect_to session.delete(:return_to).presence || root_path, notice: "Account created."
```

**Step 4: Request spec (optional)**

Add a request spec: unauthenticated GET pool_path(pool) redirects to login; after POST login with valid credentials, redirect is to pool_path(pool).

**Step 5: Commit**

```bash
git add app/controllers/application_controller.rb app/controllers/sessions_controller.rb app/controllers/users_controller.rb
git commit -m "feat: redirect to original URL after login or signup"
```

---

## Part 3: Left navigation bar

### Task 4: Add left sidebar to layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Create: `app/views/shared/_sidebar.html.erb` (or inline in layout)

**Step 1: Add sidebar markup to layout**

In `app/views/layouts/application.html.erb`, after the header and flash block, wrap main content in a flex container and add a sidebar when the user is signed in:

- Add a wrapper `<div class="flex ...">` that contains:
  - A left sidebar (only if `current_user`): narrow column with links: **Pools** (`pools_path`), **Tournaments** (`tournaments_path`), **Golfers** (`golfers_path`), **Sync** (`sync_index_path`). If `@pool` is set, also show a divider or heading and **Pool: [name]** (`pool_path(@pool)`) and **My picks** (`pool_picks_path(@pool)`).
  - The current main content area (flash + `<main>`).

Use a fixed or min-width sidebar (e.g. `w-48` or `w-56`) and Tailwind classes so the layout remains usable on small screens (e.g. collapse to top nav or keep sidebar scrollable).

Example structure:

```erb
<div class="flex min-h-screen">
  <% if current_user %>
    <aside class="w-48 flex-shrink-0 border-r border-gray-200 bg-white p-4">
      <nav class="space-y-1">
        <%= link_to "Pools", pools_path, class: "block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 no-underline" %>
        <%= link_to "Tournaments", tournaments_path, class: "block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 no-underline" %>
        <%= link_to "Golfers", golfers_path, class: "block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 no-underline" %>
        <%= link_to "Sync", sync_index_path, class: "block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 no-underline" %>
        <% if @pool && @pool.users.include?(current_user) %>
          <div class="pt-2 mt-2 border-t border-gray-200">
            <div class="px-3 py-1 text-xs font-medium text-gray-500 uppercase">This pool</div>
            <%= link_to @pool.name, pool_path(@pool), class: "block rounded px-3 py-2 text-sm text-emerald-600 hover:bg-gray-100 no-underline" %>
            <%= link_to "My picks", pool_picks_path(@pool), class: "block rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 no-underline" %>
          </div>
        <% end %>
      </nav>
    </aside>
  <% end %>
  <div class="flex-1 min-w-0">
    <!-- existing flash and main -->
    ...
  </div>
</div>
```

Ensure `@pool` is set in PoolsController (show, etc.) and PicksController so the sidebar can show pool context. It is already set in those controllers.

**Step 2: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat: add left sidebar nav for Pools, Tournaments, Golfers, Sync and pool context"
```

### Task 5: Remove bottom-of-page nav from pools index

**Files:**
- Modify: `app/views/pools/index.html.erb`

**Step 1:** Remove the paragraph with "All tournaments", "All golfers", "Sync" links at the bottom (lines 33–35).

**Step 2: Commit**

```bash
git add app/views/pools/index.html.erb
git commit -m "chore: remove bottom nav from pools index (moved to sidebar)"
```

### Task 6: Remove bottom-of-page nav from tournaments index

**Files:**
- Modify: `app/views/tournaments/index.html.erb`

**Step 1:** Remove the line(s) with "Sync" and "Back" at the bottom (lines 17–18).

**Step 2: Commit**

```bash
git add app/views/tournaments/index.html.erb
git commit -m "chore: remove bottom nav from tournaments index (moved to sidebar)"
```

### Task 7: Remove bottom-of-page nav from tournaments show

**Files:**
- Modify: `app/views/tournaments/show.html.erb`

**Step 1:** Remove the paragraph with "Back to tournaments" at the bottom.

**Step 2: Commit**

```bash
git add app/views/tournaments/show.html.erb
git commit -m "chore: remove bottom nav from tournaments show (moved to sidebar)"
```

### Task 8: Remove bottom-of-page nav from golfers index and new

**Files:**
- Modify: `app/views/golfers/index.html.erb`
- Modify: `app/views/golfers/new.html.erb`

**Step 1:** Remove "Back" link from bottom of both views.

**Step 2: Commit**

```bash
git add app/views/golfers/index.html.erb app/views/golfers/new.html.erb
git commit -m "chore: remove bottom nav from golfers views (moved to sidebar)"
```

### Task 9: Remove bottom-of-page nav from pool show, picks, pool new, show_join

**Files:**
- Modify: `app/views/pools/show.html.erb`
- Modify: `app/views/pools/new.html.erb`
- Modify: `app/views/pools/show_join.html.erb`
- Modify: `app/views/picks/index.html.erb`
- Modify: `app/views/picks/new.html.erb`
- Modify: `app/views/picks/edit.html.erb`

**Step 1:** Remove the "My picks" and "Back to pools" (or "Back to [pool]", "Back to picks", "Back") links at the bottom of each. Do not remove the "Invite to pool" button or in-page actions (e.g. "Add tournament", "Make picks").

**Step 2: Commit**

```bash
git add app/views/pools/show.html.erb app/views/pools/new.html.erb app/views/pools/show_join.html.erb app/views/picks/index.html.erb app/views/picks/new.html.erb app/views/picks/edit.html.erb
git commit -m "chore: remove bottom nav from pool and picks views (moved to sidebar)"
```

### Task 10: Remove bottom-of-page nav from sync index

**Files:**
- Modify: `app/views/sync/index.html.erb`

**Step 1:** Remove the paragraph with "Tournaments", "Golfers", "Pools" links at the bottom (lines 36–39).

**Step 2: Commit**

```bash
git add app/views/sync/index.html.erb
git commit -m "chore: remove bottom nav from sync index (moved to sidebar)"
```

---

## Verification

- Pool with tournaments shows “Starts &lt;date&gt;” on show page; pool with no tournaments shows no start date.
- “Invite to pool” copies the full pool URL; opening it in an incognito window shows login, then after sign-in redirects to the pool; non-member sees join prompt and can join.
- When signed in, left sidebar shows Pools, Tournaments, Golfers, Sync; on pool and picks pages, “This pool” with pool name and “My picks” appear. No duplicate nav at bottom of those pages.

---

## Notes

- **Stimulus:** If the app does not use Stimulus, implement the copy action with a small inline script or a single JS file that selects `[data-copy-invite]` and attaches a click handler using `navigator.clipboard.writeText`.
- **i18n:** If the app uses locale, use `l(@pool.start_date, format: :long)`; otherwise `strftime` is fine.
- **Mobile:** Consider making the sidebar collapsible or a drawer on small viewports so the left nav doesn’t dominate the screen.
