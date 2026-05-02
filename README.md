# Micromachines V3 Clone

> Top-down arcade racing — Micro Machines V3 (PS1 1997) reimagined. 4 players, 2 controllers, 2 buttons each.

## Status

**WIP — V0 prototype phase.** One car, one flat track, auto-acceleration, left/right steering. Tuning the feel before adding anything else.

## Quick Start

### 1. Install Godot

```bash
brew install --cask godot
# or download from https://godotengine.org/download/macos/
```

### 2. Open the project

```bash
cd src/
open -a Godot project.godot
# or just open Godot, click "Import" → select src/project.godot
```

### 3. Run

Press `F5` in the Godot editor (or `Cmd+B` to run).

## Controls

### Keyboard (testing)

| Player | Left | Right |
|---|---|---|
| P1 | A | D |
| P2 | J | L |
| P3 | ← | → |
| P4 | Numpad 4 | Numpad 6 |

### Gamepad — split-controller (real Micro Machines style)

| Player | Pad | Buttons |
|---|---|---|
| P1 | Pad 1 — D-pad | D-pad Left / D-pad Right |
| P2 | Pad 1 — face buttons | □ Square / ○ Circle |
| P3 | Pad 2 — D-pad | D-pad Left / D-pad Right |
| P4 | Pad 2 — face buttons | □ Square / ○ Circle |

## Design Pillars

1. **Auto-accelerate.** No throttle. Cars drive themselves.
2. **Two buttons per player.** Left, right. That's it.
3. **Single shared screen.** Slowpokes get knocked off — respawn after 2s.
4. **Drift physics.** Tight, slidey, momentum-driven. Arcade, not sim.
5. **Toy-scale tracks.** Breakfast table, pool table, garden, bathroom.

## Roadmap

See [PROJECT.md](./PROJECT.md) for the full V0→V5 roadmap.

## License

Private. © 2026 Naskaus.
