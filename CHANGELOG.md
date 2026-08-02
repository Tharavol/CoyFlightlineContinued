# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
versions follow [Semantic Versioning](https://semver.org/). This continuation
starts a fresh version line at 1.0.0; the original author's
`<expansion major>.<minor>.<build>` scheme is kept only for the 10.0.001 entry
below, which records his release. The supported client version is declared by
`## Interface` in the TOC and is no longer duplicated in the version number.

## [1.0.1] - 2026-08-02

### Fixed

- **The line no longer breaks up into dots on the zone map.** `SetThickness` is
  measured in the parent frame's coordinate space, and the map canvases are
  scaled — the zone map fits a whole zone into a small window, so its canvas
  scale sits well below 1.0 and a nominally 1px line landed on less than one
  physical pixel, which the renderer sampled into a dotted trail. Thickness is
  now divided by the line frame's effective scale (`ns.ScaledThickness`), so the
  drawn width stays constant on screen. Because the canvas is rescaled as the
  map zooms, the map surfaces re-derive it each frame rather than once in
  `ApplyStyle`. The minimap is unscaled, so nothing changes there.

## [1.0.0] - 2026-08-01

First release for WoW Midnight. Effectively a rewrite; the behaviour of the
original is preserved and extended.

### Added

- Flight line on the **minimap**, clipped to the minimap circle and aware of the
  `rotateMinimap` CVar (the line locks to straight-up when the minimap rotates).
  Square-minimap addons are honoured through the community `GetMinimapShape()`
  convention.
- Flight line on the **zone map** (`BattlefieldMapFrame`, Shift+M).
- Options panel under ESC → Options → AddOns → CoyFlightline, built on the
  current Settings API.
- `/cfl` slash commands for every setting, plus `/cfl status` and `/cfl reset`.
- Saved settings in `CoyFlightline_GlobalData` — the TOC declared this variable
  in 10.0.001 but nothing ever wrote to it. Includes a `dbVersion` field for
  future migrations.
- The line is now also drawn while skyriding (`C_PlayerInfo.GetGlidingInfo()`)
  and while travelling on a flight path (`UnitOnTaxi("player")`), both toggleable.

### Fixed

- **The line no longer drifts when the world map is zoomed or panned.** 10.0.001
  parented the line to `WorldMapFrame.ScrollContainer` — the fixed viewport —
  and multiplied normalized map coordinates by the viewport's size, which is
  only correct at default zoom with no panning. The line frame now attaches to
  `mapFrame:GetCanvas()` (`ScrollContainer.Child`), which is the frame that
  actually scales and pans, and is what Blizzard's own map pins use.
- The world map is no longer touched at file scope. Both map surfaces attach via
  `EventUtil.ContinueOnAddOnLoaded`, which is required for the zone map because
  `Blizzard_BattlefieldMap` is load-on-demand.

### Changed

- Updated `## Interface` from `100002` to `120007`.
- Lines are clipped to their container mathematically (ray/rectangle and
  ray/circle intersection in `Core.lua`) instead of being drawn deliberately
  over-long and cropped by `SetClipsChildren`. This removes the
  `5 * (width + height) / 7` hypotenuse approximation and makes the endpoint
  exact on every surface.
- Map lookups use the `MapCanvasMixin` accessors `:GetCanvas()` and `:GetMapID()`
  rather than reaching into `.ScrollContainer` and `.mapID` directly.
- `CoyFlightline.lua` was split into `Core.lua`, `WorldMap.lua`, `Minimap.lua`
  and `Config.lua`. One `OnUpdate` driver now services every surface, with an
  early-out so a grounded player costs almost nothing.
- TOC gained `Version`, `IconTexture`, `Category-enUS` and `X-License` metadata,
  and credits all three contributors.
- Added a `LICENSE` file carrying the MIT license the original was published
  under, with copyright lines for both Coywolf and Tharavol.
- Renamed the displayed title to **CoyFlightline Continued** to make it clear
  this is an unaffiliated community continuation. The addon folder is
  deliberately still `CoyFlightline`, so this installs over the original and
  existing saved settings carry across.

### Notes

- Patch 12.0.0's new "secret values" restrictions target combat information;
  nothing this addon calls is affected. None of the 138 globals removed in 12.0.0
  were used here either.
- `GetPlayerFacing()` remains `#noinstance` and returns `nil` in dungeons, raids,
  battlegrounds and arenas, so the line is simply absent there.

## [10.0.001] - 2023-01-06

Original release by **Coywolf** for WoW 10.0.2, published on
[CurseForge](https://www.curseforge.com/wow/addons/coyflightline).

- Draws a white 1px direction line on the world map while flying, using
  `GetPlayerFacing()` and `C_Map.GetPlayerMapPosition()`.
