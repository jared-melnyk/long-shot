# LongShot Landing Page & Rebrand Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a public LongShot landing page at root, rebrand the app to LongShot, serve under subpath `/longshot`, and update repo/docs to `long_shot` and jaredmelnyk.com/longshot.

**Architecture:** New `LandingController` with unauthenticated root; logged-in users redirect to pools. Layout and meta rebrand to LongShot. Production sets `config.action_controller.relative_url_root` via env. Repo rename and deploy docs updated for long_shot and subpath URL.

**Tech Stack:** Rails, ERB, Tailwind (existing), RSpec.

**Design reference:** `docs/plans/2026-02-28-longshot-landing-design.md`

---

## Task 1: Request spec for landing page (unauthenticated)

**Files:**
- Create: `spec/requests/landing_spec.rb`

**Step 1: Create the request spec**

Create `spec/requests/landing_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Landing", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "returns success and shows the landing page" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("LongShot")
        expect(response.body).to include("Sign up")
        expect(response.body).to include("Sign in")
      end
    end

    context "when signed in" do
      let(:user) { User.create!(name: "Test", email: "test@example.com", password: "password") }

      before { post login_path, params: { email: user.email, password: "password" } }

      it "redirects to pools" do
        get root_path
        expect(response).to redirect_to(pools_path)
      end
    end
  end
end
```

**Step 2: Run spec (expect failure — no root route to landing yet)**

Run: `bundle exec rspec spec/requests/landing_spec.rb -v`  
Expected: Failure (root still goes to pools#index, or route missing for landing).

**Step 3: Commit**

```bash
git add spec/requests/landing_spec.rb
git commit -m "test: add request spec for landing page"
```

---

## Task 2: Landing controller and route

**Files:**
- Create: `app/controllers/landing_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Add LandingController**

Create `app/controllers/landing_controller.rb`:

```ruby
# frozen_string_literal: true

class LandingController < ApplicationController
  skip_before_action :require_login, only: [ :index ]

  def index
    if current_user
      redirect_to pools_path
    else
      render :index
    end
  end
end
```

**Step 2: Set root to landing**

In `config/routes.rb`, change the root line from:

```ruby
root "pools#index"
```

to:

```ruby
root "landing#index"
```

Add a route for the pools index so logged-in users have a clear dashboard URL. Check current file: pools are at `resources :pools`, so `pools_path` is already `pools_url`. No change needed for that.

**Step 3: Run spec**

Run: `bundle exec rspec spec/requests/landing_spec.rb -v`  
Expected: First example may pass (200, body includes LongShot/Sign up/Sign in only if view exists). Second example (signed in redirect) should pass. If view is missing, you'll get a missing template error — that's expected; next task adds the view.

**Step 4: Commit**

```bash
git add app/controllers/landing_controller.rb config/routes.rb
git commit -m "feat: add LandingController and root route to landing#index"
```

---

## Task 3: Landing view

**Files:**
- Create: `app/views/landing/index.html.erb`

**Step 1: Create landing view**

Create `app/views/landing/index.html.erb` with hero, short overview, features, and CTAs (match design doc copy):

```erb
<div class="space-y-10">
  <section class="text-center py-8">
    <h1 class="text-4xl font-bold text-gray-900 mb-2">LongShot</h1>
    <p class="text-xl text-gray-600 mb-6">Flexible golf pools for the PGA Tour.</p>
    <div class="flex justify-center gap-4">
      <%= link_to "Sign up", signup_path, class: "rounded px-5 py-2.5 text-base font-medium text-white bg-emerald-600 hover:bg-emerald-700 no-underline" %>
      <%= link_to "Sign in", login_path, class: "rounded px-5 py-2.5 text-base font-medium text-emerald-600 border border-emerald-600 hover:bg-emerald-50 no-underline" %>
    </div>
  </section>

  <section class="max-w-2xl mx-auto space-y-4">
    <h2 class="text-2xl font-semibold text-gray-900">What is LongShot?</h2>
    <p class="text-gray-700 leading-relaxed">
      A golf pool app where you create flexible pools by picking one or more upcoming PGA Tour events.
      Invite your friends with an easy share link (coming soon), then everyone makes their picks for each tournament.
    </p>
  </section>

  <section class="max-w-2xl mx-auto space-y-4">
    <h2 class="text-2xl font-semibold text-gray-900">How scoring works</h2>
    <p class="text-gray-700 leading-relaxed">
      Participants earn points from the prize money their picks win. Picking long-odds players pays off with a bonus—so the name fits.
    </p>
  </section>

  <section class="text-center pt-4">
    <%= link_to "Get started — Sign up", signup_path, class: "text-emerald-600 font-medium hover:underline" %>
  </section>
</div>
```

**Step 2: Run spec**

Run: `bundle exec rspec spec/requests/landing_spec.rb -v`  
Expected: All examples pass.

**Step 3: Commit**

```bash
git add app/views/landing/index.html.erb
git commit -m "feat: add landing page view with LongShot copy and CTAs"
```

---

## Task 4: Rebrand layout to LongShot

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Replace Golf Pool with LongShot in layout**

In `app/views/layouts/application.html.erb`:

- Change `<%= content_for(:title) || "Golf Pool" %>` to `<%= content_for(:title) || "LongShot" %>`.
- Change `<meta name="application-name" content="Golf Pool">` to `<meta name="application-name" content="LongShot">`.
- Change header link text from `"Golf Pool"` to `"LongShot"` (keep `root_path`).

**Step 2: Run spec and smoke check**

Run: `bundle exec rspec spec/requests/landing_spec.rb -v`  
Expected: Pass. Manually open root in browser and confirm header shows "LongShot".

**Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "chore: rebrand layout to LongShot"
```

---

## Task 5: Production relative_url_root for /longshot

**Files:**
- Modify: `config/environments/production.rb`

**Step 1: Set relative_url_root in production**

In `config/environments/production.rb`, after the existing `config.hosts` / `config.host_authorization` block (e.g. after line 89), add:

```ruby
# Serve app under subpath e.g. jaredmelnyk.com/longshot. Set RAILS_RELATIVE_URL_ROOT in Render (e.g. /longshot).
if ENV["RAILS_RELATIVE_URL_ROOT"].present?
  config.action_controller.relative_url_root = ENV["RAILS_RELATIVE_URL_ROOT"]
end
```

**Step 2: Verify**

Run: `RAILS_RELATIVE_URL_ROOT=/longshot bundle exec rails routes | head -5` (from app root).  
Expected: Paths show with `/longshot` prefix (e.g. `root_path` => `/longshot`).

**Step 3: Commit**

```bash
git add config/environments/production.rb
git commit -m "config: add relative_url_root for production subpath /longshot"
```

---

## Task 6: Deploy docs and Render config for long_shot and subpath

**Files:**
- Modify: `render.yaml`
- Modify: `docs/deploy-render.md`

**Step 1: Update render.yaml**

- Change comment from `# Render Blueprint: golf_pool` to `# Render Blueprint: long_shot`.
- Change database name from `golf-pool-db` to `long-shot-db`, and `databaseName` from `golf_pool` to `long_shot` (or keep DB name for existing deploys—see note below).
- Change service name from `golf-pool-web` to `long-shot-web`.
- In envVars, add a comment or env var for subpath: e.g. add `# For subpath at jaredmelnyk.com/longshot add RAILS_RELATIVE_URL_ROOT=/longshot in Environment`.
- Keep `healthCheckPath: /up`. If the app is behind a proxy at /longshot, Render may still health-check at its own root; if the proxy forwards /longshot to Render with path preserved, ensure the health check URL used by Render includes the subpath if required (Render typically hits the service at root; the proxy handles /longshot).

**Note:** If the app is already deployed with database name `golf_pool`, do not change `databaseName` in render.yaml to avoid creating a new DB; only change service/repo names and comments. If this is a fresh deploy, use `long_shot` for databaseName for consistency.

**Step 2: Update docs/deploy-render.md**

- Replace "golf_pool" with "long_shot" where it refers to the repo or app name (e.g. "GitHub repo with the golf_pool app" → "GitHub repo with the long_shot app").
- Replace "golf-pool-web" / "golf-pool-db" with "long-shot-web" / "long-shot-db" in instructions.
- Add a short section (e.g. "Subpath (jaredmelnyk.com/longshot)": set `RAILS_RELATIVE_URL_ROOT=/longshot` in Render Environment; ensure your proxy forwards `jaredmelnyk.com/longshot` to the Render service).
- Update any example URLs to use jaredmelnyk.com/longshot where appropriate.

**Step 3: Commit**

```bash
git add render.yaml docs/deploy-render.md
git commit -m "docs: update Render and deploy docs for long_shot and subpath URL"
```

---

## Task 7: Follow-up feature notes

**Files:**
- Create or modify: `docs/plans/README.md` or add to design doc / a single BACKLOG.md

**Step 1: Add follow-up notes**

Create `docs/plans/BACKLOG.md` (or add a "Follow-up" section to `docs/plans/2026-02-28-longshot-landing-design.md`):

```markdown
# LongShot follow-up items

- **Share/join link for pools** — Add an easy-to-use share/join link so pool creators can invite friends with a single link.
- **LongShot bonus calculation** — Refine how the bonus for picking long-odds players is calculated.
```

**Step 2: Commit**

```bash
git add docs/plans/BACKLOG.md
git commit -m "docs: add backlog items for share link and longshot bonus"
```

---

## Manual steps (not in plan)

- **Rename GitHub repo** to `long_shot` (GitHub repo Settings → General → Repository name). After rename, update Render to use the new repo if connected by name.
- **Render Environment:** Add `RAILS_RELATIVE_URL_ROOT=/longshot` when the app is served at jaredmelnyk.com/longshot.
- **Proxy (e.g. Green Geeks):** Configure so that requests to `jaredmelnyk.com/longshot` (and `jaredmelnyk.com/longshot/*`) are forwarded to the Render web service URL (path can be forwarded as-is or stripped depending on proxy; Rails expects the request path to match the subpath when using relative_url_root).

---

## Verification

- `bundle exec rspec spec/requests/landing_spec.rb` — all pass.
- Visit root in browser: unauthenticated → landing with LongShot copy and CTAs; signed in → redirect to pools.
- Layout shows "LongShot" in header and title.
- With `RAILS_RELATIVE_URL_ROOT=/longshot`, `rails routes` and generated links use `/longshot` prefix.
