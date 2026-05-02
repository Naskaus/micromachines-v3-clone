# Brainstorm Raw — Micromachines V3 Clone

Session: 2026-05-02
Mode: /spark CODE

## Seb's original ask

> "create a new GAMES folder : /spark : new game project : like Micromachine V3 sur PS1. pas besoin d'accelerer ou freiner. le system accelere tout seul. juste tourner gauche droite, avec juste deux bouton actifs. comme a l'epoque sur la ps1 2 manettes mais 4 joueiurs possibles. 2 par manettes. il faut retrouver la meme dynamique la meme physique les memes decors que a l'epoque. utilise tous les skuills possible. MCP godot, etc..."

## Distilled requirements

| Requirement | Locked |
|---|---|
| Auto-acceleration (no throttle/brake input) | YES |
| 2-button control per player (left/right only) | YES |
| 4 players max | YES |
| 2 controllers, 2 players per controller | YES (split-pad like PS1 original) |
| Same physics/dynamics as MMV3 PS1 | TARGET (drifty arcade) |
| Same decor as MMV3 PS1 | TARGET (toy-scale household environments) |
| Use godot-mcp + all relevant skills | YES |

## Design decisions made (no Seb input requested — per "never block on ambiguity" rule)

1. **Engine:** Godot 4.6 + GDScript. (Free, fast iteration, godot-mcp already set up.)
2. **Bucket:** New `naskaus/games/` folder, parallel to `ops/lab/vitrine/`. Games are their own category, distinct from lab experiments.
3. **Naming:** `micromachines-v3-clone` (lowercase-hyphenated per spark convention).
4. **Project structure:** `BRIEF.md` + `PROJECT.md` + `CLAUDE.md` + `README.md` + `.mcp.json` + `/src/` Godot project + `/docs/` + `/assets/`.
5. **MVP scope (V0):** 1 car, 1 flat plane, auto-accel + left/right. Pause for Seb feedback before scaling.
6. **Camera:** orthographic-ish top-down with slight tilt (~5-10°) — MMV3 was 3D under perspective camera. Pure top-down feels too flat.
7. **Multiplayer rendering:** single shared screen, "fall off the edge" elimination — the actual MMV3 mechanic.
8. **Input map:** 8 actions baked into `project.godot` from day 1 (`p1_left, p1_right, p2_left, p2_right, p3_left, p3_right, p4_left, p4_right`) so V1 multiplayer drop-in is trivial.
9. **Aesthetic:** placeholder cubes/cylinders for V0-V1. PS1 chunky shader is V4 polish work.
10. **No Pi5 deploy.** Local desktop game. Export targets: macOS / Windows / Linux. (Web export deferred — bad gamepad support.)

## Open Questions (flagged for Seb's V1 review)

1. **Drift model:** low lateral friction (slip-by-physics) vs scripted drift impulse on sharp turns? V0 tries pure low-friction, fallback if it feels wrong.
2. **Track 1 IRL:** breakfast table or pool table for the first real track? Pool = simpler geometry (rectangular, fewer obstacles).
3. **Camera tilt angle:** 0° (true top-down) vs 10° (slight perspective like MMV3). V0 starts at 0° for simplicity.
4. **Top speed value:** picked 18 m/s as a starting guess. Tune by feel.
5. **Turn rate:** picked 2.5 rad/s. Tune by feel.

## Risks not in PROJECT.md

- **Godot binary missing on Mac.** Detected at scaffold time — `mcp__godot-mcp__get_godot_version` returned ENOENT. User must `brew install --cask godot` OR download from godotengine.org before first run. Documented in CLAUDE.md `Critical Setup` section.
- **godot-mcp scene format compatibility:** the MCP creates `.tscn` files in a specific Godot version. If user installs Godot 4.7 vs 4.6, scenes might need a one-click upgrade in the editor.

## Skills/MCPs used in this session

- `naskaus-start` — session bootstrap
- `spark` (CODE mode) — project scaffolding (this skill)
- `godot-mcp` — version check (failed gracefully, Godot not installed; will resume on V0 build)
- (deferred to V0 build) `superpowers:brainstorming` for V1 feature additions
- (deferred) `gemini-research` for MMV3 physics references if V0 feel is off

## Next session checklist

1. Install Godot 4.6 via `brew install --cask godot`
2. Open `src/project.godot` in Godot — accept any auto-import prompts
3. Run scene `Main.tscn` (F5)
4. Drive the car around the flat plane
5. Tune `TOP_SPEED`, `TURN_RATE`, `DRIFT_FRICTION` in `car.gd` until it feels right
6. Once V0 feels right → trigger `superpowers:writing-plans` for V1 (4-player multiplayer + first real track)
