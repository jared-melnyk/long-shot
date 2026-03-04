## LongShot

LongShot is an app where you create golf pools for PGA Tour events. Create a pool, add tournaments, invite your crew, and see who really knows their long shots.

### Pick windows and visibility

- **Picks open** exactly **4 days before a tournament starts**. Before then, you’ll see when they open—no peeking at anyone else’s lineup.
- Make or edit picks until the tournament starts; once play begins, picks are **locked**. No take-backs.
- **Before the tournament starts**: You see your own picks; for everyone else you only see “Pick submitted” or “No pick”—so nobody can copy your sleeper picks.
- **After the tournament starts**: All picks are revealed. Time to compare, gloat, or commiserate.

On the pool page you get your own picks plus a table of every member: full lineups when they’re visible, or just that satisfying “Pick submitted” / “No pick” before lock.

### Pool membership

- Each pool has a **creator** who sets up tournaments and can remove members.
- **Standings** show every member and their total—that’s the leaderboard you’re trying to top.
- From Standings: leave the pool yourself, or (if you’re the creator) remove someone. Keep it competitive, keep it fair.

### Development

- **Ruby / Rails**: see `Gemfile` for the exact Rails and Ruby versions.
- **Database**: PostgreSQL (configured in `config/database.yml`).
- **Tests**: run the RSpec suite with:

  ```bash
  bundle exec rspec
  ```

- **Deployment**: see [`docs/deploy-render.md`](docs/deploy-render.md) for deploying to Render and connecting a custom domain.
