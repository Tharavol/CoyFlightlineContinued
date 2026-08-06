# Handoff

Context for picking this project up on another machine, or in a fresh AI session.
Update this file whenever something below stops being true.

**Last updated:** 2026-08-05

## What this is

**CoyFlightline Continued** — a WoW addon that draws a facing-direction line on the minimap,
zone map and world map while flying. Originally by **Coywolf** for patch 10.0.2
(Jan 2023); rewritten for **Midnight 12.0.7** by **Tharavol** with implementation
help from **Claude (Anthropic)**.

- Upstream: https://www.curseforge.com/wow/addons/coyflightline (project ID `794376`)
- Repo: `Tharavol/CoyFlightline`
- License: MIT, inherited from the original. See [LICENSE](LICENSE).

**Naming.** The display name (`## Title`, README, options panel) is
"CoyFlightline Continued" — the established WoW convention for a community
continuation, chosen over "Resurrected"/"Reborn" because those read as specific
devs' branding. The **addon folder and TOC filename stay `CoyFlightline`** so the
package installs over the original as a drop-in replacement, keeping the install
path and project identity existing users already have. Anywhere the name is
shown to the user it comes from `ns.title`, which reads `## Title` from the TOC.

Note that this is *not* about preserving legacy settings. Coywolf's 10.0.001
declares `## SavedVariables: CoyFlightline_GlobalData` but never writes to it —
the whole addon is one `OnUpdate` with a hardcoded white 1px line and no
configuration — so there is nothing to migrate and nothing to lose. The
folder-name decision stands on the drop-in install path alone; do not plan
around a saved-settings constraint that does not exist.

## Current status

The 12.x rewrite is **written and verified in-game** by Tharavol on 2026-08-01
against patch 12.0.7. The checklist at the bottom of this file passed. Re-run it
after any change to the surface adapters or the show conditions.

> **Verification owed.** The `Publishable 12.0.7` milestone rewrote every surface
> adapter onto a shared base and moved the minimap shape and instance checks onto
> events. That touches both of the areas above, so the checklist has *not* been
> re-run since. Do that before tagging a release.

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

Load order matters: `Core.lua` must come first — it creates `ns.db`, `ns.Surface`
and the geometry helpers everything else uses at file scope. CI enforces this;
see `.github/scripts/validate-toc.sh`.

## Architecture

Everything hangs off a **surface** abstraction. A surface is a table with:

| Member | Meaning |
| --- | --- |
| `key` | unique id, diagnostics only |
| `dbKey` | boolean field in `ns.db` gating this surface |
| `host` | frame the line belongs to; visible == surface usable |
| `lineFrame` | frame the line is drawn in, and whose scale it is measured against |
| `line` | the line texture itself |
| `Update(dirX, dirY)` | position and show the line |

Everything else — `IsAvailable`, `HideLine`, `ApplyStyle`, `RefreshThickness` —
comes from the `ns.Surface` base metatable in `Core.lua`; adapters chain to it
with `setmetatable(Adapter, { __index = ns.Surface })` and override only
`Update`. Both adapters used to carry their own copies, and the copies drifted:
the canvas surfaces re-derived their scale-compensated thickness every frame
while the minimap set it once and went stale for anyone running a rescaled
minimap. Sharing the base is what keeps that from recurring, so resist
reimplementing these per adapter.

`Core.lua` registers them, runs one `OnUpdate` across all of them, and owns the
math. Adding a fourth surface really is one adapter plus a call to
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

## Verification checklist (passed 2026-08-01)

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
8. `/run Minimap:SetScale(1.5)` — the minimap line keeps the same on-screen width
   as the map lines. Set it back to `1`. (Covers the shared `RefreshThickness`.)
9. Zone into a dungeon and back out without relogging — the line disappears
   inside and returns outdoors. (Covers the cached instance state.)

## Open questions / TODO

- **Licensing — resolved.** The CurseForge page lists the original as MIT, so this
  repo carries MIT with copyright lines for both Coywolf and Tharavol. MIT's only
  real obligation is that the copyright and permission notice travel with every
  copy, which `LICENSE` handles. Keep Coywolf's copyright line intact in any
  redistribution.
- **Contacting Coywolf: deliberately skipped.** They have been inactive for years
  and the MIT license already grants everything this project needs. The README
  states plainly that this is an unaffiliated continuation. Revisit only if
  Coywolf resurfaces.
- Frame level on the map surfaces is `canvas:GetFrameLevel() + 150`, carried over
  from the original's `SetFrameLevel(150)`. Not validated against every pin type;
  if the line hides behind something, this is the knob.
- **Packaging exists.** `.pkgmeta` plus `.github/workflows/release.yml` build a
  zip through BigWigsMods/packager on any `v*` tag. Publishing to CurseForge /
  WoWInterface / Wago additionally needs the `CF_API_KEY` / `WOWI_API_TOKEN` /
  `WAGO_API_TOKEN` repository secrets, and CurseForge also needs
  `## X-Curse-Project-ID` in the TOC — see the open question about whether to
  publish under our own project.
- No localization beyond enUS and no Classic TOC variants. Both still
  deliberately out of scope.
- Minimap inset is a flat 1px (`MINIMAP_INSET` in `Minimap.lua`). May need
  adjusting against the actual border art.
