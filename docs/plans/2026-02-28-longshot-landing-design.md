# LongShot Landing Page & Rebrand — Design

**Date:** 2026-02-28  
**Status:** Approved

---

## Goal

Add a public landing page for the app, rebrand as **LongShot**, serve the app under the subpath `/longshot` at jaredmelnyk.com, and rename the repo/project to `long_shot`. Unauthenticated visitors see marketing copy and CTAs; logged-in users hitting root are redirected to the pools dashboard.

---

## Scope

**In scope:**

- New public landing page at root with LongShot branding, short overview, core features, and Sign up / Sign in CTAs.
- Rebrand UI to "LongShot" (layout, titles, meta).
- Root route: unauthenticated → landing; authenticated → redirect to `pools#index`.
- Rails served under subpath `/longshot` (relative_url_root).
- Repo/project rename to `long_shot` and doc/config updates.

**Out of scope (follow-up notes):**

- **Share/join link for pools** — Add an easy-to-use share/join link so pool creators can invite friends with a single link.
- **LongShot bonus calculation** — Refine how the bonus for picking long-odds players is calculated.

---

## Routing

- `root` → `landing#index`.
- `LandingController` skips `require_login` for `index`.
- In `landing#index`: if `current_user` present, redirect to `pools_path` and return; else render landing view.
- Sign up, Sign in, Logout, and all existing routes unchanged in behavior; all live under `/longshot` when `relative_url_root` is set.

---

## Landing Page Content

- **Hero:** "LongShot" title, one-line tagline (e.g. "Flexible golf pools for the PGA Tour").
- **What it is:** Golf pool app where you create pools by choosing one or more upcoming PGA Tour events, invite friends (share/join link called out as easy in copy; implementation in a later feature).
- **How it works:** Participants make picks per tournament; scoring based on prize money earned by picks, with a bonus for picking long-odds players.
- **CTAs:** Primary = Sign up; secondary = Sign in (in header and in hero or feature section).

---

## Branding

- Layout: replace "Golf Pool" with "LongShot" (logo text, `application-name` meta, default `<title>`).
- Favicon/icon: keep existing for now (optional later: LongShot-specific icon).
- Keep current emerald/green theme; no new visual system in this phase.

---

## Subpath Configuration

- In Rails: set `config.action_controller.relative_url_root` to `"/longshot"` (e.g. in production via `ENV["RAILS_RELATIVE_URL_ROOT"]` so it works on Render and can be disabled locally).
- Document that the app is intended at `https://jaredmelnyk.com/longshot` and that the proxy (e.g. Green Geeks) must route `jaredmelnyk.com/longshot` (and `jaredmelnyk.com/longshot/*`) to the Render service.

---

## Repo / Project Rename

- Rename GitHub repo to `long_shot` (manual step).
- Update `render.yaml` (service names, any repo references) and `docs/deploy-render.md` to use `long_shot` and the new URL (e.g. jaredmelnyk.com/longshot).

---

## Files to Add/Change

| Action | Path |
|--------|------|
| New | `app/controllers/landing_controller.rb` |
| New | `app/views/landing/index.html.erb` |
| Modify | `config/routes.rb` (root → `landing#index`) |
| Modify | `app/views/layouts/application.html.erb` (LongShot) |
| Modify | `config/environments/production.rb` (relative_url_root) |
| Modify | `render.yaml` |
| Modify | `docs/deploy-render.md` |
| Optional | `docs/plans/` or README note for the two follow-up features |

---

## Success Criteria

- Unauthenticated users visiting root see the LongShot landing page with overview, features, and CTAs.
- Logged-in users visiting root are redirected to the pools index.
- All UI and meta show "LongShot" instead of "Golf Pool".
- In production with `RAILS_RELATIVE_URL_ROOT=/longshot`, all links and redirects use the `/longshot` prefix.
- Deploy docs and Render config reference `long_shot` and jaredmelnyk.com/longshot.
