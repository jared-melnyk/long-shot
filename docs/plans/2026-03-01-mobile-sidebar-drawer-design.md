# Mobile Sidebar Drawer — Design

**Date:** 2026-03-01  
**Scope:** Left sidebar → hamburger + overlay drawer on mobile only. No header or content changes this round.

## Goal

On viewports below 768px, hide the always-visible left sidebar and replace it with a hamburger button that opens an overlay drawer from the left. Desktop (≥768px) keeps the current sidebar layout.

## Behavior

- **Breakpoint:** Tailwind `md` (768px). Below: hamburger + drawer. At or above: current sidebar, no hamburger.
- **Header:** Logo left. Right: hamburger (visible only below `md`) + existing auth (Sign in/Sign up or user + Sign out).
- **Drawer:** Same links as current sidebar (Pools, Tournaments, Golfers, Sync, and conditional “This pool” block). Slides in from left, overlays page. Semi-transparent backdrop. Close on: backdrop tap, close button, or (optional) on nav link tap.
- **Accessibility:** `aria-expanded` and `aria-label` on hamburger; focus management / trap when drawer is open (optional but recommended).
- **Implementation:** One Stimulus controller toggles open/close; Tailwind for layout and transitions. No new dependencies.

## Out of scope (this round)

- Header responsive tweaks (e.g. collapsing auth).
- Bottom tab bar or other nav patterns.
- Content-area responsive changes beyond ensuring no horizontal overflow.

## Approval

Approach A (overlay drawer) approved. Scope limited to sidebar/drawer.
