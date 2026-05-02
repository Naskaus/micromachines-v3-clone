# PROJECT — Micromachines V3 Clone

## TL;DR

A faithful, lean clone of **Micro Machines V3** (Codemasters, PS1 1997). Top-down arcade racer with toy-scale tracks set on household objects (breakfast table, pool table, garden, bathroom). Trademark: **only 2 buttons per player** (turn left, turn right), auto-acceleration. Up to **4 players on 2 controllers** by splitting each pad in half — the gimmick that defined the PS1 multiplayer era.

## Problem

Modern racing games over-engineer controls (gas, brake, drift, brake-tap, e-brake, NOS, gear shift, camera...). The 1997 Micro Machines V3 nailed peak couch multiplayer chaos with **two buttons** and **half a controller per player**. No modern game preserves that exact feel + couch-co-op gimmick.

## Solution

Rebuild the core loop in Godot 4 with disciplined scope:
1. Auto-acceleration only (no throttle input)
2. 2 inputs: left, right
3. Drifty momentum-driven 3D physics under a top-down (or 5° tilted) camera
4. Single shared screen — slowest player gets eliminated when knocked off-screen
5. 4-player split-controller input map from day 1

## Architecture

```
src/
├── project.godot          # Godot 4 project + 8 input actions (P1-P4 left/right)
├── icon.svg               # placeholder icon
├── scenes/
│   ├── Main.tscn          # entry point — loads track + spawns car
│   ├── Track01.tscn       # flat plane + walls (V0 placeholder)
│   ├── Car.tscn           # RigidBody3D + mesh + camera follow
│   └── HUD.tscn           # speed + score (V1)
├── scripts/
│   ├── car.gd             # auto-accel + 2-button steering + drift
│   ├── camera_follow.gd   # smooth top-down chase cam
│   ├── track.gd           # respawn zones + checkpoints (V1)
│   └── input_map.gd       # central player→action lookup
└── assets/
    ├── models/            # car + track geometry (V1+ — placeholders for now)
    ├── textures/          # PS1 affine textures
    └── sounds/            # engine loop, collision, music
```

## Stack

| Layer | Tech | Why |
|---|---|---|
| Engine | Godot 4.6 | Free, GDScript, native 3D, great input system |
| Language | GDScript | Fast iteration, hot reload, no compile step |
| Physics | Godot RigidBody3D + PhysicsMaterial | Built-in, tunable for arcade feel |
| Camera | Camera3D, orthogonal-ish | Top-down with slight tilt (~5-10°) |
| Input | Godot InputMap (ProjectSettings) | 8 actions: `p1_left, p1_right, p2_left, p2_right, ...` |
| Aesthetic (later) | Custom shader | PS1 vertex jitter + affine texture mapping |

## Data Model

V0 has no persistent data. V1+ scoreboard = simple dict:
```gdscript
var scores := { "P1": 0, "P2": 0, "P3": 0, "P4": 0 }
```

## Roadmap

| Version | Scope | Effort |
|---|---|---|
| **V0 — Feel** (now) | 1 car, 1 flat track, auto-accel, L/R steering, drift tuning | 1 session |
| V1 — Multiplayer | 4 cars, split-pad input, single-screen camera (frames the leader), respawn on fall | 1-2 sessions |
| V2 — First real track | Breakfast table track (cereal box, milk carton, toast obstacles) | 2-3 sessions |
| V3 — Polish | HUD, lap counter, score, sound, menu | 2 sessions |
| V4 — Asset pass | PS1 shader, low-poly cars (8 models), collision sfx | 2 sessions |
| V5 — Track pack | Pool table, garden, bathroom + AI bots | open-ended |

## Risks

| Risk | Mitigation |
|---|---|
| **Physics feel is wrong** (too floaty, too sticky, no slide) | Tune in V0 BEFORE building anything else. Compare side-by-side with YouTube footage of MMV3. |
| **4-player input map clashes** (gamepad axis vs button mapping per OS) | Use Godot's InputMap and test on actual gamepads early (V1). Fall back to keyboard for testing. |
| **Camera struggles to frame 4 cars on one screen** | Adopt MMV3 rule: camera follows the leader, others get knocked off-screen → respawn. Don't try to keep all 4 visible. |

## Agent Prompt Seed

> You are a Godot 4 game-dev agent working on a Micro Machines V3 clone. The vibe to nail is **PS1 1997 arcade chaos** — chunky, drifty, fun. Always favor playable iteration over polish. Never add a feature outside the current Vx scope without checking with Seb. Use the godot-mcp MCP to edit scenes/scripts. Never block on tuning values — pick a number, comment why, move on.

## Tuning History (BASELINE — DO NOT REGRESS)

### V0.1 — 2026-05-02 — locked, confirmed by Seb "trop bien"

| Constant | Value | Reason |
|---|---|---|
| `TOP_SPEED` | 28.0 m/s | Cruise speed — feels arcade |
| `ACCEL` | 50.0 m/s² | Snappy launch — must overcome residual damping |
| `TURN_RATE` | 3.4 rad/s | Yaw at full speed — nervous like MMV3 |
| `TURN_RATE_LOW_SPEED` | 2.0 rad/s | Less twitchy at low speed |
| `LATERAL_GRIP` | 8.0 | Straight = straight |
| `DRIFT_GRIP` | 3.0 | Slide-out feel during hard turns |
| `HARD_TURN_SPEED_FACTOR` | 0.7 | Drift kicks in at 70% top speed |
| Car `PhysicsMaterial.friction` | 0.0 | **CRITICAL** — non-zero kills auto-accel (default friction 1.0 + gravity 20 → friction max 20N > our thrust) |
| Car `linear_damp` | 0.5 | Natural deceleration when no thrust |
| `physics/3d/default_gravity` | 20.0 | Snappy arcade weight |

**Lesson learned (the friction-blocks-thrust bug):** RigidBody3D default friction is 1.0. Combined with `gravity=20`, max static friction = `μ·m·g = 20 N`. Initial `ACCEL=12` → 12 N thrust < 20 N friction → car wouldn't move until angular torque (turning) broke static friction. Fix: `PhysicsMaterial(friction=0.0)` on the Car. Document in any future car variant.

## Track Layout (V0.1)

```
                        WallBack (z=+30)
              ┌────────────────────────────────┐
              │                                │
              │       □ pillar     □ pillar    │
              │      (-10,10)     (10,10)      │
              │                                │
              │           Car spawn (0, 10)    │
              │              ↓ drives -Z       │
              │   ▭ Petite (-20, 5, 15°)       │
              │                ▭ Moyenne       │
              │                 (20, -5, 25°)  │
              │      □ pillar     □ pillar     │
              │     (-10,-10)    (10,-10)      │
              │       ▭ Grosse (0, -22, 40°)   │
              │                                │
              └────────────────────────────────┘
                       WallFront (z=-30)
```

- Petite : tilt 15°, hauteur max ~1.3m
- Moyenne : tilt 25°, hauteur max ~2.5m
- Grosse : tilt 40°, hauteur max ~4.2m

In-air: car keeps `axis_lock_angular_x/z` so it stays flat (no flips). Forward thrust + gravity → parabolic arc.

## Open Questions

1. **Camera tilt:** pure orthographic (true top-down) or perspective with 5-10° tilt? MMV3 used a slight perspective tilt.
2. **Drift model:** simulate via low lateral friction (slip), or scripted drift impulse on sharp turns? Start with low friction, fall back if it feels bad.
3. **Track 1 art direction:** breakfast table or pool table? Pool table is geometrically simpler (rectangular, no obstacles).
4. **Multiplayer screen split or single shared screen?** MMV3 = single shared, fall-off-screen elimination. Decision: single shared.
5. **Godot install:** binary not detected on Mac at `/Applications/Godot.app`. Need `brew install --cask godot` or download from godotengine.org BEFORE first run.

## Out of Scope (V0-V3)

- Online multiplayer
- Custom car loadouts
- AI bots (until V5)
- Mobile / touch controls
- Localization
