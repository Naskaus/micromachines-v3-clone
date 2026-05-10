# CLAUDE.md — Micromachines V3 Clone

> Read this BEFORE any action on this project.
> Last updated: 2026-05-02.

---

## Project

```
micromachines-v3-clone/
├── BRIEF.md            # 10-line project pitch
├── PROJECT.md          # Full project bible
├── CLAUDE.md           # This file
├── README.md           # GitHub-ready
├── .mcp.json           # MCP config (godot-mcp + n8n-naskaus)
├── docs/
│   └── brainstorm_raw.md
├── assets/
│   └── prompts.md      # Imagen + Veo prompts for placeholder art
└── src/                # Godot 4 project (open this in Godot)
    ├── project.godot
    ├── scenes/
    ├── scripts/
    └── assets/
```

- **What:** Micro Machines V3 (PS1 1997) clone — top-down arcade racing, auto-accel, 2-button steering, 4 players on 2 controllers.
- **Stack:** Godot 4.6 + GDScript.
- **Status:** **V0.20.3-rc1** — arch-based freestyle engine + NavigationAgent3D Tier 2 nav. 2 tracks (Billard + Workshop), track picker live, multi en sleep mode. Awaiting Seb playtest validation.
- **Repo:** GitHub `Naskaus/micromachines-v3-clone` PUBLIC. Live at `mv3.naskaus.com` (Phase 3 multi v0.19.2-rc1 deployed; V0.20.x rebuild not yet redeployed — still local).

## Setup — DONE (2026-05-02)

**Godot 4.6.1.stable** is installed at `/Users/bpia/Downloads/06_Installers_DMG/Godot.app`.

The godot-mcp server (default install) looks for `/Applications/Godot.app`. We solved this with a symlink:

```bash
# Already in place — only re-run if /Applications/Godot.app disappears
ln -s /Users/bpia/Downloads/06_Installers_DMG/Godot.app /Applications/Godot.app
```

Verified: `mcp__godot-mcp__get_godot_version` returns `4.6.1.stable.official.14d19694e`.
Verified: `mcp__godot-mcp__run_project` on `Main.tscn` boots cleanly with **0 errors / 0 warnings** on Metal 4.0 / Apple M4 Max.

## Working Rules — This Project Specifically

1. **godot-mcp first.** Use `mcp__godot-mcp__*` tools (create_scene, add_node, save_scene, run_project) over manual `.tscn` editing whenever possible. Manual `.tscn` editing is risky — Godot's binary-ish format is fragile.
2. **V0 means V0.** The MVP is ONE car driving on ONE flat plane with auto-accel + left/right steering. Do not build multiplayer, tracks, HUD, sound, or art until Seb confirms the V0 control feels right.
3. **Tune by playing, not by reading.** Drift, top speed, turn rate — all numbers must be tuned in-engine. No theoretical physics deep-dives.
4. **Comment WHY, not WHAT, on tuning constants.** Example:
   ```gdscript
   const TOP_SPEED := 18.0  # MMV3 cars feel ~18-22 m/s on the breakfast table
   ```
5. **Never block on a number.** Pick one, comment the reasoning, ship the iteration. Seb will tweak by feel.
6. **Reference material:** YouTube "Micro Machines V3 PS1 gameplay" — use `mcp__gemini-research__research_web` if you need a quick refresher on the physics/feel.
7. **Lean MVP > perfect art.** Placeholder cubes/cylinders are FINE for V0-V1.

## Identity

- **User:** Sebastien (Seb), Fondateur & AI Architect de NASKAUS
- **Machine:** MacBook Pro M4 Pro 48GB 1TB
- **Project root:** `/Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/`

## Available Tools

| MCP | Use for |
|---|---|
| `godot-mcp` | All scene/node/script/run operations (REQUIRES Godot binary) |
| `gemini-research` | Quick lookups on Micro Machines V3 physics, drift mechanics, PS1 visuals |
| `mcp-image` | Generate placeholder car/track texture art if needed |
| `blender` | Generate low-poly car/track 3D models if needed |
| `context7` | Godot 4 GDScript docs |

## Deployment

This is a **local-only desktop game.** No Pi5 deploy. No Tailscale. No Cloudflare.

Final builds (much later) will export to:
- macOS `.app`
- Windows `.exe`
- Linux `.x86_64`

Web (HTML5) export is possible but multi-controller support is poor in browsers — desktop only for now.

## Working Style

1. Always start with `mcp__godot-mcp__get_godot_version` — if it errors, Godot is not installed (see Critical Setup).
2. Use `superpowers:brainstorming` before adding any new feature outside the current Vx scope.
3. After any meaningful iteration, **mark the task in `tasks/todo.md`** (create the file if missing) so progress is tracked.
4. After Seb confirms V0 feels right, write a plan for V1 via `superpowers:writing-plans`.

## Lessons Learned

(none yet — first session 2026-05-02)
