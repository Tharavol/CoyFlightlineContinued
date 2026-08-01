# Handoff

Context for picking this project up on another machine, or in a fresh AI session.
Update this file whenever something below stops being true.

**Last updated:** 2026-08-01

## What this is

`CoyFlightline` — a WoW addon that draws a facing-direction line on the minimap,
zone map and world map while flying. Originally by **Coywolf** for patch 10.0.2
(Jan 2023); rewritten for **Midnight 12.0.7** by **Tharavol** with implementation
help from **Claude (Anthropic)**.

- Upstream: https://www.curseforge.com/wow/addons/coyflightline (project ID `794376`)
- Repo: `Tharavol/CoyFlightline`
- License: MIT, inherited from the original. See [LICENSE](LICENSE).

## Current status

The 12.x rewrite is **written but not yet verified in-game.** Nothing in this
repo has been run against a live client. Work through the checklist at the
bottom before treating any of it as proven, and record the result here.

## Repo layout and history

The first commit is Coywolf's **unmodified** 10.0.001 release, so the entire
rewrite is reviewable as a single diff against it. Preserve that commit.

```
CoyFlightline.toc   Interface 120007, metadata, load order
Core.lua            geometry, show conditions, surface registry, OnUpdate driver
WorldMap.lua        world map + zone map surfaces
Minimap.lua         minimap surface
Config.lua          saved variables, Settings panel, /cfl commands
```

Load order matters: `Core.lua` must come first — it creates `ns.db` and the
geometry helpers everything else uses.

## Architecture

Everything hangs off a **surface** abstraction. A surface is a table with:

| Member | Meaning |
| --- | --- |
| `key` | unique id, diagnostics only |
| `dbKey` | boolean field in `ns.db` gating this surface |
| `IsAvailable()` | host frame exists and is visible |
| `Update(dirX, dirY)` | position and show the line |
| `HideLine()` | hide the line |
| `ApplyStyle()` | re-read colour/thickness from the db |

`Core.lua` registers them, runs one `OnUpdate` across all of them, and owns the
math. Adding a fourth surface means writing one adapter and calling
`ns.RegisterSurface`.

Coordinates are a y-down pixel space with origin at the host frame's `TOPLEFT`,
which is the space `C_Map` normalized coordinates already use. Facing converts
to a unit vector as `(-sin θ, -cos θ)` — that mapping is inherited from Coywolf's
original and is correct; don't "fix" the signs.

## WoW API facts established during the 12.x update

Worth keeping, because re-deriving them costs a lot of searching:

- **Interface number for 12.0.7 is `120007`** (`major * 10000 + minor * 100 + patch`).
- **The canvas is not the scroll container.** `WorldMapFrame.ScrollContainer` is
  the fixed viewport; `WorldMapFrame:GetCanvas()` (== `ScrollContainer.Child`) is
  what zooms and pans. Normalized map coordinates must be multiplied by the
  *canvas* size. Getting this wrong was the main bug in 10.0.001, and it only
  shows up once you zoom or drag the map.
- **`GetPlayerFacing()` still exists in 12.x** and is still `#noinstance`: it
  returns `nil` in dungeons, raids, battlegrounds and arenas. The nil-guard is
  load-bearing, not defensive padding.
- **12.0.0's "secret values" do not affect this addon.** They restrict operations
  on Lua values along tainted paths and target combat information
  (`COMBAT_LOG_EVENT` now errors on registration). Nothing here is combat-related.
  None of the 138 globals removed in 12.0.0 were used by this addon either.
  Reference: https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- **`Blizzard_BattlefieldMap` is load-on-demand** — the zone map addon only loads
  when the user first opens the zone map, so it must be hooked through
  `EventUtil.ContinueOnAddOnLoaded`, never at file scope.
- **`Settings.RegisterAddOnSetting` changed signature in 11.0.2** and is now
  `(categoryTbl, variable, variableKey, variableTbl, variableType, name, default)`.
  `Config.lua` uses that form and wraps the whole panel build in `pcall`, so a
  future signature change degrades to "no options panel, slash commands still
  work" instead of a load error. If the panel is missing, check that first.
- `Settings.CreateDropdown` was `Settings.CreateDropDown` before 11.x; both names
  are probed.

## Dev loop

There is no test framework for WoW addons — verification is in-game only.

The addon has to live under `Interface\AddOns\CoyFlightline\`. On the original
machine the user moves/links it there themselves; do not write to the WoW
directory without being asked.

Then in game: `/console scriptErrors 1`, and `/reload` after every change.
Saved variables are only flushed to disk on logout or `/reload`, so check
`WTF\Account\<ACCOUNT>\SavedVariables\CoyFlightline.lua` after one of those.

## Verification checklist (not yet run)

1. `/reload` — no Lua errors, addon not flagged out-of-date.
2. Fly outdoors — line on minimap, zone map (Shift+M) and world map (M), all
   pointing the same way.
3. **Zoom and pan the world map — the line must stay anchored to the player dot.**
   This is the specific regression 10.0.001 fails.
4. Turn in place — all three lines rotate together, none spills past the minimap
   circle or the map edges.
5. `/console rotateMinimap 1` — the minimap line locks to straight-up; map lines
   are unaffected. Set it back to `0`.
6. Take a flight path — the line tracks the taxi heading. Enter a dungeon — the
   line disappears.
7. Options panel — toggle each surface, change colour/thickness/opacity, `/reload`,
   confirm the settings persisted.

## Open questions / TODO

- **Licensing — resolved.** The CurseForge page lists the original as MIT, so this
  repo carries MIT with copyright lines for both Coywolf and Tharavol. MIT's only
  real obligation is that the copyright and permission notice travel with every
  copy, which `LICENSE` handles. Keep Coywolf's copyright line intact in any
  redistribution.
- Frame level on the map surfaces is `canvas:GetFrameLevel() + 150`, carried over
  from the original's `SetFrameLevel(150)`. Not validated against every pin type;
  if the line hides behind something, this is the knob.
- No packaging (`.pkgmeta`, release workflow), no localization beyond enUS, no
  Classic TOC variants. All deliberately out of scope so far.
- Minimap inset is a flat 1px (`MINIMAP_INSET` in `Minimap.lua`). May need
  adjusting against the actual border art.
