# CoyFlightline

> **This is a community continuation, not the original project.** CoyFlightline was
> created by [Coywolf](https://www.curseforge.com/wow/addons/coyflightline) and last
> released for patch 10.0.2 in January 2023. This repository picks it up for Midnight
> and is maintained by Tharavol. It is not affiliated with or endorsed by Coywolf.
> Redistributed under the original MIT license — see [Credits](#credits) and [LICENSE](LICENSE).

A World of Warcraft addon that draws a line from your position in the direction you are facing, so you can see where a flight will actually take you.

The line appears on three surfaces:

- the **minimap**
- the **zone map** (Shift+M)
- the **world map** (M)

By default it is drawn while flying, while skyriding, and while travelling on a flight path. It is never drawn in instances (the game does not report your facing there).

Targets **WoW Midnight, patch 12.0.7** (Interface `120007`).

## Install

Copy or link this folder into your AddOns directory so that the path looks like:

```
World of Warcraft\_retail_\Interface\AddOns\CoyFlightline\CoyFlightline.toc
```

Then `/reload` or restart the client.

## Settings

`ESC` → Options → AddOns → CoyFlightline, or `/cfl`.

| Setting | Default | Notes |
| --- | --- | --- |
| Enable CoyFlightline | on | Master switch |
| Minimap / Zone map / World map | on | Per-surface toggles |
| While flying | on | `IsFlying()` |
| While skyriding | on | `C_PlayerInfo.GetGlidingInfo()` |
| On a flight path | on | `UnitOnTaxi("player")` |
| Line colour | White | White, Yellow, Cyan, Magenta, Green |
| Line thickness | 1 | 1–6 px |
| Line opacity | 100% | 10–100% |

### Slash commands

```
/cfl                     open the options panel
/cfl on | off            master switch
/cfl minimap             toggle the minimap line
/cfl zonemap             toggle the zone map line
/cfl worldmap            toggle the world map line
/cfl thickness <1-6>     line thickness
/cfl alpha <0.1-1>       line opacity
/cfl color <name>        white, yellow, cyan, magenta, green
/cfl color <r> <g> <b>   custom colour, each 0-1
/cfl status              show the current settings
/cfl reset               restore defaults
```

Arbitrary colours are only reachable from the slash command — the Settings API has no built-in colour-picker control.

## Layout

| File | Purpose |
| --- | --- |
| `Core.lua` | Ray/shape clipping, show conditions, surface registry, the update driver |
| `WorldMap.lua` | World map and zone map surfaces (both are `MapCanvasMixin` frames) |
| `Minimap.lua` | Minimap surface — circular clipping, minimap-rotation aware |
| `Config.lua` | Saved variables, options panel, slash commands |

A "surface" is a small adapter that knows where its host frame is and where the player sits inside it. All of them share the geometry and the show-condition logic in `Core.lua`, so adding another surface is a few dozen lines.

## Credits

- **Coywolf** (`coywolf333`) — original concept and implementation ([CurseForge project 794376](https://www.curseforge.com/wow/addons/coyflightline)), released 2023-01-06 for patch 10.0.2. The core idea and the facing-to-vector math are theirs.
- **Tharavol** — Midnight (12.x) update and ongoing maintenance.
- **Claude (Anthropic)** — implementation assistance for the 12.x rewrite.

This repository preserves Coywolf's release as its first commit so that authorship is traceable; see [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE), matching the license Coywolf published the original under.
Copyright © 2023 Coywolf, © 2026 Tharavol.
