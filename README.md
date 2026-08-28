# foxwar

The state of the persistent [Foxhole](https://www.foxholegame.com/) war, in your terminal.

`foxwar` pulls the official Foxhole War API, the Steam player count, and
foxholestats.com's event log, and renders the war at a glance: the victory-town
race, per-side casualties and casualty rate, an ASCII front-line map with
**invasion alerts**, and a live feed of base captures.

Single file, Python 3.8+, standard library only. No install step beyond dropping
it on your `PATH`.

```
                                          Basin
                                   SpkWds        Howl
              Kuura         Callum        Reachn        Clnshd
       PariPk        Nevish        Moors         ViperP        Morgen
Olavis        Gutter        Stncrd        Callhn        Wethr‼        Godcrf
       Palntn        Frran⚔        LinnM⚔        Marba⚔        Stlic⚔        Lykos⚔
              Fshmn⚔        KngCa⚔        DEADL⚔        Clahs‼        Tempes
       Oarbr⚔        Westgt        LochM⚔        Drownd        EndlsS        Finger
              Stema         Sablpr        Umbral        Allods        Wresta        Pipers
                     Origin        Hrtlnd        Shackl        Reaver        Tyrant
                            AshFld        GrtMrc        Termin        Onyx
                                   RedRiv        Acrith
                                          Kaloka

colonial  warden  contested ⚔  neutral   ‼ invasion alert

War #140   Day 75

Victory towns   24 Colonial   17 Warden   (need 34 to win)
  ████████████████████████████████

Casualties         196,806  46.5% Colonial  +3,539/hr
                   226,121  53.5% Warden  +3,912/hr
  ████████████████████████████████
Total dead         422,927   (7,452/hr, 9-min avg)
Enlistments         85,800
Steam players        3,064  in-game now

 ‼ INVASION ALERT (2)   Clahstr 14/min  Wethrd 18/min

Recent events  (foxholestats.com)
  20:48  Colonials took Callahan's Boot Town Base T1 - Deadlands
  20:54  Colonials took The Baths Construction Yard - The Drowned Vale
  20:58  Colonials took The Baths Factory - The Drowned Vale
```

## Install

```sh
git clone https://github.com/erlendrosok/foxwar
cd foxwar
./install.sh              # -> ~/.local/bin/foxwar
./install.sh --service    # also enable the foxwar-poll systemd user service
foxwar
```

Or just drop the single `foxwar` file anywhere on your `PATH` and `chmod +x` it.
Requires Python 3.8+ and nothing else — no `pip install`.

## Commands

| Command | What it shows |
| --- | --- |
| `foxwar` | Summary: victory-town race, per-side casualties + rate, players, invasion alerts, last 8 events |
| `foxwar map` | ASCII hex map, coloured by control. `⚔` contested, `‼` invasion alert |
| `foxwar regions` | Table of every region: control, per-side dead, per-side rate (deaths/hr) |
| `foxwar events [N]` | Last N base/structure events (default 30), from foxholestats |
| `foxwar watch [SECS]` | Live view — map + most-active regions + events + summary, redrawn every `SECS` (default 60) |
| `foxwar poll [SECS]` | Headless: keeps casualty tracking fresh, prints new events. For a spare pane or a service |
| `foxwar tmux` | One compact line for a `tmux` status bar (cached; safe to call every refresh) |

Flags: `--shard 1|2|3` (default 1), `--no-color`, `--blink` (blink the `‼` markers).

## tmux status bar

`foxwar tmux` prints something like `FH140 d75  VT 24-17 C+7  ☠ 47/53  3.0k  ‼2`.
It serves a cached line instantly and refreshes in the background, so it's cheap
to call on every status redraw:

```tmux
set -g status-right '#[fg=red] ⚔ #(~/.local/bin/foxwar tmux) #[default] %H:%M '
set -g status-right-length 90
```

## Continuous tracking (optional)

The **event log** works with zero setup — it comes straight from foxholestats.

The **casualty rate** (and the rate-based invasion alerts) is computed locally
from repeated War-API samples, so it needs a few minutes of history. Any live
`foxwar watch` builds it; for always-on tracking without a terminal open, run
`foxwar poll` as a systemd user service — `./install.sh --service` does this, or
by hand:

```sh
cp foxwar-poll.service ~/.config/systemd/user/
systemctl --user enable --now foxwar-poll.service
journalctl --user -u foxwar-poll -f      # watch captures scroll by
```

Without it, `foxwar` still works — it just shows casualty **totals** instead of
`/hr` rates until enough history accumulates.

## How it works

| Data | Source |
| --- | --- |
| War state, victory towns, per-region casualties, base ownership | Official Foxhole War API (`war-service-live.foxholeservices.com`) |
| Concurrent players | Steam `GetNumberOfCurrentPlayers` (app 505460) — **global**, not per-shard |
| Event log (captured / building / lost / upgraded) | Scraped from [foxholestats.com](https://foxholestats.com)'s Live Event Log (72 h of history; there is no official events endpoint) |

Everything is cached under `~/.cache/foxwar/` and revalidated with ETags where
the API supports it.

### Control & invasion alerts

- A region is **contested** (`⚔`) when both factions hold at least one base
  (town, relic, or keep) in it — each has a foothold.
- A real Foxhole invasion — an enemy-held *border base* pushing into a hex you
  still fully own, which ends the moment they take a town/relic base — is not
  exposed by any API. foxwar approximates an **invasion alert** (`‼`) as:
  - a base **captured or started** there in the last 45 minutes
    (per foxholestats), in a hex the gaining faction doesn't already hold; **or**
  - a fully-owned **front-line** hex whose casualty rate is clearly elevated —
    above a floor *and* either past an absolute threshold or several times the
    median active region ("clearly the main push", even on a quiet evening).

The map's `⚔` / `‼` and per-region rates make the active front obvious at a
glance.

## Configuration

All optional, via environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `FOXWAR_SHARD` | `1` | Live shard (1–3) |
| `FOXWAR_INVASION_WINDOW` | `2700` | Seconds a logged capture keeps a region flagged |
| `FOXWAR_HOT_RATE` | `10` | deaths/min that always counts as a hot front line |
| `FOXWAR_HOT_FLOOR` | `4` | deaths/min below which a region is never "hot" |
| `FOXWAR_HOT_REL` | `3` | …or this multiple of the median active region |
| `FOXWAR_HOT_COOLDOWN` | `1800` | Seconds a region stays "hot" after the rate drops |
| `FOXWAR_RATE_MIN` | `2` | Minutes of history before rates are shown |
| `FOXWAR_FHS_TTL` | `120` | Seconds to cache the foxholestats scrape |
| `FOXWAR_TMUX_TTL` | `300` | Seconds before the `tmux` line refreshes in the background |

## Caveats

- **The event log depends on foxholestats.com's HTML.** If they change their
  markup or go down, foxwar falls back to its last cache and then shows
  "event log unavailable" — nothing crashes, but events stop updating.
- **Casualty rates warm up.** They appear after ~2 minutes of history and
  sharpen toward a 30-minute average over the following half hour.
- **The Steam count is game-wide** (all shards plus players in menus). There is
  no reliable public per-shard population.
- Region control is inferred from base ownership; a lone enemy relic base is
  treated as a foothold (so the region reads contested).

## Not affiliated

Not affiliated with Siege Camp / Foxhole or with foxholestats.com. Foxhole is a
trademark of its owners. Be considerate with poll intervals — the defaults are.

## License

[MIT](LICENSE).
