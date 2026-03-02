# Mobile Sidebar Drawer Implementation Plan

> **For Claude:** Use superpowers:executing-plans to implement this plan task-by-task in another chat.

**Where:** Run from the `long_shot` app root. Have the Rails server running for Task 4 (manual verification).

**Goal:** On viewports &lt;768px, hide the left sidebar and show a hamburger that opens an overlay drawer; desktop keeps the current sidebar. Scope: drawer only (no header/content changes).

**Architecture:** One Stimulus controller toggles drawer open/closed and handles backdrop click. Layout uses the same nav markup for both desktop (visible aside) and mobile (drawer panel); responsive Tailwind classes show/hide and position. No new dependencies.

**Tech Stack:** Rails ERB layout, Tailwind CSS, Stimulus (already in use via importmap).

**Design reference:** `docs/plans/2026-03-01-mobile-sidebar-drawer-design.md`

---

## Task 1: Add Stimulus sidebar controller

**Files:**
- Create: `app/javascript/controllers/sidebar_controller.js`

**Step 1: Create the controller**

Create `app/javascript/controllers/sidebar_controller.js` with this content. The controller toggles the drawer panel and backdrop, sets `aria-expanded` on the hamburger, and only calls `close()` in `connect()` when both panel and backdrop targets exist (so it doesn’t throw when the user is logged out and the sidebar isn’t in the DOM).

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "toggle"]

  connect() {
    if (this.hasPanelTarget && this.hasBackdropTarget) this.close()
  }

  toggle() {
    if (this.panelTarget.classList.contains("translate-x-0")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.panelTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/sidebar_controller.js
git commit -m "feat: add Stimulus sidebar controller for mobile drawer"
```

---

## Task 2: Update layout — hamburger, drawer wrapper, and data attributes

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Wrap the sidebar in a drawer structure and add hamburger**

- In the header, when `current_user` is present, add a hamburger button visible only on mobile (`md:hidden`). The button should have `data-controller="sidebar"` (we'll attach the controller to a parent that wraps both header button and drawer).
- Controller must wrap both the hamburger and the drawer, so wrap the whole page content (header + flex container) in one `data-controller="sidebar"` div, OR wrap only the hamburger + the drawer in a single wrapper. Simpler: put `data-controller="sidebar"` on the body or on a wrapper that contains both the hamburger and the drawer. Easiest: a wrapper div that contains the header and the flex row, and inside it: hamburger in header, and drawer (backdrop + panel) in the flex row.
- Structure to achieve:
  - Header: add hamburger button (only when `current_user`), with `data-sidebar-target="toggle"` and `data-action="click->sidebar#toggle"`.
  - Keep the existing `<aside>` but make it the drawer panel on mobile: on small screens it’s fixed, off-canvas, and slides in; on `md:` it stays as the current visible sidebar. So we need two things: (1) the current aside for desktop, (2) on mobile the same aside is the drawer panel. Easiest: one aside, with responsive classes — on mobile it’s fixed, full height, -translate-x-full by default, and the controller adds translate-x-0 when open; on md it’s static, w-48, etc. So the aside gets two sets of classes: mobile (fixed left-0 top-0 h-full w-48 -translate-x-full transition ... z-50) and md (md:relative md:translate-x-0 md:w-48 md:flex-shrink-0). And we need a backdrop only on mobile (hidden by default, shown when open).
- Add a backdrop element that’s only visible on mobile, with `data-sidebar-target="backdrop"` and `data-action="click->sidebar#close"`.

Implement as follows:

1. Add a wrapper with `data-controller="sidebar"` around the part of the page that has the header and the main flex (so the controller can see both the toggle and the drawer). For example, wrap the entire content from header through the end of the flex div.
2. In the header, after the logo and before the `<nav>`, add the hamburger (only when `current_user`):

```erb
<% if current_user %>
  <button type="button" class="md:hidden p-2 -ml-2 rounded-md text-gray-600 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-emerald-500" aria-label="Open menu" aria-expanded="false" data-sidebar-target="toggle" data-action="click->sidebar#toggle">
    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
  </button>
<% end %>
```

3. Keep the existing `<div class="flex min-h-screen">` and the `<aside>`. Add a mobile-only backdrop before the aside: `<div data-sidebar-target="backdrop" class="hidden fixed inset-0 bg-black/50 z-40 md:hidden" ...></div>`. Give the aside `data-sidebar-target="panel"` and the responsive classes so on mobile it’s a fixed overlay drawer and on md it’s the current sidebar.

**Exact layout changes:**

Replace the body content (from `<header>` through the closing `</div>` of the flex) with the structure below. Use this as the reference — apply the same structure to your existing ERB (keep your existing nav links and conditional “This pool” block).

```erb
<body class="bg-gray-50 font-sans">
  <div data-controller="sidebar">
    <header class="flex justify-between items-center px-4 py-3 border-b border-gray-200 bg-white">
      <div class="flex items-center gap-2">
        <% if current_user %>
          <button type="button" class="md:hidden p-2 -ml-2 rounded-md text-gray-600 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-emerald-500" aria-label="Open menu" aria-expanded="false" data-sidebar-target="toggle" data-action="click->sidebar#toggle">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
          </button>
        <% end %>
        <%= link_to "LongShot", root_path, class: "text-xl font-semibold text-gray-900 no-underline hover:text-gray-900" %>
      </div>
      <nav class="flex items-center gap-4">
        <% if current_user %>
          <span class="text-gray-700"><%= current_user.name %></span>
          <%= button_to "Sign out", logout_path, method: :delete, form: { class: "inline-block" }, class: "rounded px-3 py-1.5 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 border border-gray-300" %>
        <% else %>
          <%= link_to "Sign in", login_path, class: "text-emerald-600 hover:underline font-medium" %>
          <%= link_to "Sign up", signup_path, class: "rounded px-3 py-1.5 text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700" %>
        <% end %>
      </nav>
    </header>
    <div class="flex min-h-screen">
      <% if current_user %>
        <div data-sidebar-target="backdrop" class="hidden fixed inset-0 bg-black/50 z-40 md:hidden" data-action="click->sidebar#close" aria-hidden="true"></div>
        <aside data-sidebar-target="panel" class="fixed left-0 top-0 z-50 h-full w-48 -translate-x-full transition-transform duration-200 ease-out bg-white border-r border-gray-200 p-4 pt-20 md:relative md:translate-x-0 md:pt-4 md:flex-shrink-0">
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
        ...
      </div>
    </div>
  </div>
</body>
```

Keep the rest of the file (flash, main, yield) unchanged inside the `<div class="flex-1 min-w-0">`. The controller’s `connect()` already guards with `hasPanelTarget && hasBackdropTarget`, so when the user is logged out and the sidebar/backdrop are not in the DOM, it won’t throw.

**Step 2: Commit**

```bash
git add app/views/layouts/application.html.erb app/javascript/controllers/sidebar_controller.js
git commit -m "feat: mobile sidebar drawer with hamburger and overlay"
```

---

## Task 3: Drawer visibility and desktop sidebar

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Confirm responsive behavior**

- On viewport &lt; 768px: aside is `fixed`, `-translate-x-full` by default; when open, controller adds `translate-x-0`. Backdrop is `md:hidden` so it only shows on mobile; it’s `hidden` by default and controller removes `hidden` when open.
- On viewport ≥ 768px: aside has `md:relative md:translate-x-0` so it’s always visible and in flow. Backdrop is `md:hidden` so it never shows. Hamburger is `md:hidden` so it’s not shown on desktop.

If anything is off (e.g. sidebar missing on desktop), fix the Tailwind classes. Ensure the aside has both `w-48` on desktop and the same width for the drawer on mobile: it already has `w-48` in the snippet; add `md:w-48` if you split mobile vs desktop width.

**Step 2: Optional — close drawer on nav link tap (Turbo)**

So that after navigating the drawer closes, add `data-action="click->sidebar#close"` to each sidebar link. That way when a user taps a link, the drawer closes. Optional; implement if you want.

**Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "fix: ensure sidebar responsive visibility and optional close on nav tap"
```

---

## Task 4: Manual verification

**Step 1: Desktop**

- Log in, view any page. Sidebar should be visible on the left; no hamburger in the header.
- Resize to &lt; 768px (or use device toolbar): sidebar should disappear, hamburger appear.

**Step 2: Mobile**

- At &lt; 768px, click hamburger: drawer slides in from left, backdrop appears. Click backdrop: drawer closes.
- Click hamburger again, then click a nav link: navigates and (if you added the close action) drawer closes.
- Check `aria-expanded` on the hamburger: toggles between true/false when opening/closing.

**Step 3: Logged out**

- At any width, no hamburger, no sidebar (unchanged from current behavior).

**Step 4: Commit if any fixes**

```bash
git add -A && git status
# If changes: git commit -m "fix: mobile drawer behavior or a11y"
```

---

## Summary

- **Task 1:** Create `sidebar_controller.js` with panel, backdrop, toggle targets; open/close/toggle and aria-expanded. Commit.
- **Task 2:** Wrap layout in `data-controller="sidebar"`; add hamburger (with toggle target and action); add backdrop (target + close action); add panel target and responsive classes to aside; guard `connect()` when targets missing. Commit.
- **Task 3:** Confirm responsive classes; optionally close drawer on nav link click. Commit.
- **Task 4:** Manual verification (desktop, mobile, logged out); fix and commit if needed.

Execution: open a new chat, paste this plan or point to `docs/plans/2026-03-01-mobile-sidebar-drawer-implementation.md`, and use the executing-plans skill to run through each task.
