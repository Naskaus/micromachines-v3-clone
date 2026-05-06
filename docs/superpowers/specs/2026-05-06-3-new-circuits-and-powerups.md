# MV3 — 3 New Circuits + Power-Up System (Phase 4)

> **Status:** Spec only. No code. Captures Seb's brief from 2026-05-06 :
> *« je veux bosser les circuits. tu fais une série de 3 nouveaux
> circuits, complètement différents, décor, type de courses, super powers
> boosters etc... rappelle-toi les trucs cool de Micromachines V3. »*
> **Predecessor:** v0.19.2-rc1 (Phase 3 multiplayer shipped, peloton fix).
> **Goal:** ship circuit variety + power-up combat à la MMV3 PS1.

---

## 1. The MMV3 PS1 (1997) DNA we want to recapture

MMV3 wasn't just racing — it was *toy-table chaos with weapons*. What made
it iconic, in priority order:

1. **Wildly different surfaces.** Sand pit ≠ pool table ≠ workshop ≠
   breakfast tray. Every track was a separate visual world built out of
   household objects at toy scale.
2. **Power-ups as combat.** Mines, missiles, Mr. Frosty (freeze ray),
   smoke screen, magnet, ghost mode. **Single-slot inventory** — pick
   one, use it, hunt the next pickup. Pickups spawn at fixed track
   anchors and respawn after a few seconds.
3. **Surface effects baked into geometry.** Butter slicks on the
   breakfast table. Sand zones. Water puddles. Each circuit had its own
   physics quirk that wasn't just visual flavor.
4. **Off-screen elimination kept the pack tight.** (Already shipped in
   Phase 3 — opt-in via lobby toggle.)
5. **Short loops.** ~30-45s per lap. Three laps = ~90s race. Fast
   sessions, lots of replays.

We already have the racing core. Phase 4 is about making the *world*
match the racing.

---

## 2. The 3 new circuits

Each circuit is one JSON file under `src/circuits/<name>.circuit.json`,
following the schema already in `default.circuit.json`. The schema is
extended (§4) to support new geometry types, surface zones, power-up
spawn anchors, and circuit-specific power-up palettes.

### 2.1 — `workshop.circuit.json` — *L'ATELIER*

**Vibe:** dad's greasy garage workbench. Steel-plate floor, oil stains, a
giant vise as the start gantry. Tools scattered as decor and walls.

| Field | Value | Reason |
|---|---|---|
| `track_geometry.type` | `loop_with_drop` *(NEW)* | Single oval BUT with a vertical drop section: drill-press hole at phase 0.5 → 12m vertical fall onto the lower deck → ramp back up at phase 0.7. |
| `oval_a` / `oval_b` | 90 / 45 | Tighter than Pool Felt (100/50) — feels claustrophobic |
| `arches` | 4, painted as caution-tape stripes | Workshop = utility, not gates |
| `surface_zones` *(NEW)* | 1 oil-slick patch (0.55-0.65) — `grip_factor: 0.4` | Extreme drift zone |
| `boost_pads` | 1 air-compressor blast at phase 0.30, factor 1.5 | Dramatic angled launch |
| `decor.items` | `tool-wrench`, `tool-screwdriver`, `tool-saw`, `nut`, `bolt`, `oil-drum`, `wood-plank`, `vise` | Kenney "Tool Kit" (already in inventory) |
| `decor.scale` | 14.0 | Tools loom large |
| `ambience.felt_color` | `[0.22, 0.20, 0.18]` (steel grey) | Hard surface |
| `ambience.wall_color` | `[0.55, 0.40, 0.25]` (raw wood) | Workbench edge |
| `powerups` *(NEW)* | `["wrench_bumper", "welder_trail", "boost_can"]` | Industrial palette |
| `music` | `industrial_loop` (TBD — Kenney audio bank) | |

**Circuit-specific power-ups:**
- 🔧 **Wrench Bumper** — instant 360° push pulse, 6m radius, knocks
  cars within range backward by 8 m/s. No projectile, no aim. *MMV3
  equivalent: the Bumper.*
- 🔥 **Welder Trail** — drops a 4s fire ribbon behind you for 2s. Cars
  touching it lose 50% speed for 1s and emit smoke. *MMV3 equivalent:
  Smoke Screen + slow-down combo.*

### 2.2 — `breakfast.circuit.json` — *PETIT-DÉJ*

**Vibe:** kitchen table, croissant crumbs everywhere, butter
slicks, syrup pools. Cereal boxes as guard rails. Everything is
edible-shaped.

| Field | Value | Reason |
|---|---|---|
| `track_geometry.type` | `wide_oval_with_shortcut` *(NEW)* | Big oval BUT a pancake-stack ramp lets you cut across the middle if you have boost. Risk/reward. |
| `oval_a` / `oval_b` | 110 / 55 | Wider than Pool Felt — gives the shortcut room |
| `arches` | 5 (one per pastry: croissant / donut / waffle / pancake / muffin) | Themed banners replace plain colors |
| `surface_zones` *(NEW)* | 2 butter slicks (0.20, 0.70) — `grip_factor: 0.3` | Long sliding patches |
| `surface_zones` | 1 syrup pool (0.85) — `grip_factor: 1.5`, `speed_malus: 0.6` | Sticky — you SLOW in syrup |
| `boost_pads` | 1 toaster-launch at phase 0.50 (jump shortcut), factor 1.6 | The shortcut entry boost |
| `decor.items` | `donut`, `croissant`, `pancake-stack`, `cereal-box`, `milk-carton`, `apple`, `coffee-cup`, `sugar-cube` | Kenney "Food Kit" (already in inventory) |
| `decor.scale` | 16.0 | Food at toy scale = giant |
| `ambience.felt_color` | `[0.92, 0.85, 0.70]` (linen tablecloth cream) | Warm breakfast |
| `ambience.wall_color` | `[0.85, 0.55, 0.30]` (wooden table edge) | |
| `powerups` *(NEW)* | `["sticky_syrup", "sugar_rush", "boost_can"]` | Edible palette |
| `music` | `cafe_jazz_loop` | Mood |

**Circuit-specific power-ups:**
- 🥞 **Sticky Syrup** — drops a 3m syrup puddle behind you that lasts
  6s. Cars driving through it: speed × 0.5 for 2s. *MMV3 equivalent: the
  Goo Mine.*
- ⚡ **Sugar Rush** — 4s super-boost (factor 1.8 vs normal boost 1.25).
  Diabetes incoming. *MMV3 equivalent: Turbo.*

### 2.3 — `bathroom.circuit.json` — *SALLE DE BAIN*

**Vibe:** white-tile floor, water puddles, toothpaste tubes as ramps,
soap bars as moving obstacles, rubber duck as start marshal. Maximum
slipperiness.

| Field | Value | Reason |
|---|---|---|
| `track_geometry.type` | `tight_indoor_circuit` *(NEW)* | Multi-segment closed loop with sharp 90° turns. NOT a figure-8. Tighter, more technical. |
| `oval_a` / `oval_b` | n/a — `path_segments` array of waypoints | Custom polyline track |
| `arches` | 4 (towel-rail-shaped) | Themed |
| `surface_zones` *(NEW)* | 3 water puddles spread (0.15, 0.45, 0.80) — `grip_factor: 0.25` | Hyper-slip zones |
| `surface_zones` | 1 bath-mat zone (0.95) — `grip_factor: 2.0` (extra grip pre-finish) | Recovery before finish |
| `boost_pads` | 0 — the toothpaste tube ramps already provide jumps | Less arcade boost, more skill |
| `ramps` | 2 toothpaste-tube ramps (phases 0.25 & 0.65), tilt 18°, longer 14m | Long jumps over the tub |
| `decor.items` | `soap-bar`, `toothbrush`, `rubber-duck`, `toothpaste-tube`, `cotton-bud`, `shampoo-bottle`, `bath-toy` | Kenney + custom Blender 3D for any missing |
| `decor.scale` | 18.0 | Bathroom items HUGE at toy scale |
| `ambience.felt_color` | `[0.95, 0.95, 0.97]` (white tile) + tile grid shader | Clean clinical look |
| `ambience.wall_color` | `[0.70, 0.85, 0.92]` (pastel bathroom blue) | |
| `powerups` *(NEW)* | `["soap_slide", "water_mine", "boost_can"]` | Bathroom palette |
| `music` | `lounge_synth_loop` | Cool, slippery |

**Circuit-specific power-ups:**
- 🧼 **Soap Slide** — 3-second trail of soap bubbles. Cars driving
  through it: `grip_factor` × 0.2 for 2s — they slide everywhere
  uncontrollably. *MMV3 equivalent: the Slick (Mario Kart-style banana
  but more brutal).*
- 💧 **Water Mine** — proximity bomb. Drop and forget. Triggers when
  any car gets within 4m, pushes them straight up 6m and resets their
  forward velocity to 0. Pure mayhem. *MMV3 equivalent: the Mine.*

---

## 3. Power-up framework (cross-circuit)

A new system, NOT in the codebase yet. The 3 circuits above all assume
this exists.

### 3.1 — Inventory model

- **Single slot per car.** No stacking. *MMV3 truth — the tension comes
  from "do I use it now or save it?".*
- **Pickup = Area3D `PowerUpBox`** on track. On `body_entered` with a
  `Car`/`BotCar`/`GhostCar`, grant a random power-up from the
  `circuit.powerups` palette. Disappear for `respawn_seconds: 4.0`,
  then reappear.
- **Use:** P1 = `SPACE`, P2 = `RSHIFT`, mobile = HUD button (right-bottom
  thumb zone). Bots use it heuristically (in front of opponent: offensive;
  behind: defensive; near walls: skip).

### 3.2 — Power-up types (engine-side)

A `PowerUp` is a struct:
```
{
  id: String,                          # "wrench_bumper", "soap_slide", ...
  kind: enum {INSTANT_AOE, TRAIL, MINE, SELF_BUFF, PROJECTILE},
  duration_self: float,                # how long the user is buffed
  duration_world: float,               # how long the effect lingers in the world
  hud_icon: String,                    # path to icon in assets/powerups/
  audio_use: String,                   # SFX key on AudioManager
  audio_hit: String,                   # SFX key on hit
}
```

Each kind has a small handler in a new `src/scripts/powerup_manager.gd`:
- `INSTANT_AOE` — emit pulse, query bodies in radius, push outward.
- `TRAIL` — spawn a `TrailPatch` (Area3D + visible decal) that lasts
  `duration_world`.
- `MINE` — same but triggers on proximity instead of immediately.
- `SELF_BUFF` — calls `car.apply_boost()` or `car.apply_grip_modifier()`.
- `PROJECTILE` — homing or straight-line, hits first body it touches.

### 3.3 — MP synchronization

Power-up spawns must be deterministic across clients (same seed +
respawn timer driven by server). When a player USES a power-up:
1. Client sends `{"type": "powerup_use", "id": "...", "x":..., "z":...}`
   to server.
2. Server stamps a sequence number, broadcasts `powerup_event` to all
   peers including sender.
3. All clients render the visual + run the local effect on whatever
   bodies it should touch. Authority = server gives sequence, no client
   can fire a power-up they don't have.

This piggybacks on the v0.19.0 server-authoritative bookkeeper. The
server tracks `inventory[player_id] -> str | null`.

### 3.4 — Default power-up (`boost_can`)

Every circuit's palette includes `boost_can` — the basic 1.25× boost
already in the engine. Acts as the safety/baseline pickup so players
always have something useful to use.

---

## 4. Schema additions for `*.circuit.json`

Backward-compatible — old circuits (`default.circuit.json`,
`picnic.circuit.json`) keep working.

```json
{
  "name": "...",
  "version": "0.20.0",
  "track_geometry": {
    "type": "figure_8" | "loop_with_drop" | "wide_oval_with_shortcut" | "tight_indoor_circuit",
    "oval_a": 100.0, "oval_b": 50.0, "oval_h": 50.0,
    "drop_phase": 0.5, "drop_height": 12.0,            // NEW for loop_with_drop
    "shortcut_phase_in": 0.5, "shortcut_phase_out": 0.7, // NEW for wide_oval_with_shortcut
    "path_segments": [[x,z], [x,z], ...]                // NEW for tight_indoor_circuit
  },
  "arches": [...],
  "ramps": [...],
  "boost_pads": [...],
  "surface_zones": [                                    // NEW
    {"phase_start": 0.20, "phase_end": 0.30, "grip_factor": 0.3, "speed_malus": 1.0, "kind": "butter"},
    {"phase_start": 0.85, "phase_end": 0.90, "grip_factor": 1.5, "speed_malus": 0.6, "kind": "syrup"}
  ],
  "powerup_anchors": [                                  // NEW
    {"phase": 0.15, "respawn_seconds": 4.0},
    {"phase": 0.50, "respawn_seconds": 4.0},
    {"phase": 0.85, "respawn_seconds": 4.0}
  ],
  "powerups": ["wrench_bumper", "welder_trail", "boost_can"],   // NEW — palette
  "spawn": {...},
  "decor": {...},
  "ambience": {...},
  "music": "..."
}
```

---

## 5. Phased implementation (~4-5 sessions)

### Phase 4.1 — Wire CircuitLoader to engine (1 session)

The CircuitLoader is foundation only today (data loaded but engine
hardcoded). This phase makes it actually drive Track01. NO new circuits
yet — just refactor.

- `Track01.tscn` → driven by `CircuitLoader.current_circuit()`
- `decor.gd` reads `circuit.decor`
- `race_manager._ready()` reads `circuit.arches` and dynamically
  positions Arch_1..Arch_N (currently hard-wired in scene)
- Lobby UI: dropdown to pick circuit

**Deliverable:** "Pool Felt v1" still races identically, but the data
flows from JSON.

### Phase 4.2 — New geometry types (1 session)

Add `loop_with_drop`, `wide_oval_with_shortcut`, `tight_indoor_circuit`
to `path_utils.gd`. Each gets its own `path_at(phase)`,
`tangent_at(phase)`, `phase_from_position(pos)` implementation.

Test geometry with placeholder decor on each.

**Deliverable:** 3 ribbons of asphalt, recognisably different shapes.

### Phase 4.3 — Surface zones + power-up framework (1 session)

- `surface_zones` parsed by track builder, render as transparent
  decals on the track surface.
- `car.gd` and `bot_car.gd`: every frame check current phase against
  zones, multiply `_off_track_factor()` and grip accordingly.
- `powerup_manager.gd` (NEW) — handles inventory, spawns, server sync.
- `PowerUpBox.tscn` (NEW) — Area3D + glowing pickup mesh.
- 1 power-up implemented end-to-end: `boost_can` (rebadging existing
  boost) — proves the pipeline.

**Deliverable:** drive through butter, you slide. Drive over a power-up
box, you get a boost. Press SPACE to use.

### Phase 4.4 — Implement the 6 circuit-specific power-ups (1-2 sessions)

`wrench_bumper`, `welder_trail`, `sticky_syrup`, `sugar_rush`,
`soap_slide`, `water_mine`. Each needs visual FX, audio SFX, and MP
sync (server stamps sequence numbers).

Bot AI heuristic for usage: simple priority table by distance to nearest
opponent + own state.

**Deliverable:** real mayhem. Side-by-side Pool Felt v1 race vs Workshop
race feel different — same physics core, completely different tactics.

### Phase 4.5 — Asset polish + lobby selector (0.5 session)

- 3 circuit JSONs finalized with Kenney decor + (where missing) Blender
  custom 3D assets generated via `blender-mcp`.
- HUD power-up slot icon (right-side mobile thumb zone).
- Lobby UI dropdown: 4 circuits to choose from (Pool Felt v1, Workshop,
  Breakfast, Bathroom).
- Music per circuit.

**Deliverable:** v0.20.0 "MMV3 Toy Chaos" — public release, share via
Telegram, ready for couch playtest.

---

## 6. Open questions for next session

1. **Power-up balance.** Should pickups be guaranteed (always grant
   something useful) or RNG (sometimes a wrench, sometimes a syrup)?
   *Reco: per-circuit RNG over palette of 3-4 — keeps tension.*
2. **Mobile use button.** Where in the HUD? Below the brake / steering?
   *Reco: bottom-right corner, glow when inventory non-empty.*
3. **Bot fairness.** Should bots get power-ups too? *Reco: yes, MMV3
   bots used items aggressively. Balance via skill modifier.*
4. **Multiplayer rollback.** What if server rejects a power-up use
   (sequence mismatch)? *Reco: client visual fires anyway, then snaps
   back if rejected within 200ms — feel > correctness.*
5. **Track geometry parameterization.** Should `tight_indoor_circuit`
   accept arbitrary polyline waypoints, or constrain to a small set
   of templates? *Reco: arbitrary waypoints — circuits are JSON-authored
   anyway, no need to artificially constrain.*

---

## 7. File-by-file change manifest (estimate ~1 800 LOC across phases)

| File | Phase | LOC est. |
|---|---|---|
| `src/scripts/path_utils.gd` | 4.2 | +200 (3 new geometry types) |
| `src/scripts/circuit_builder.gd` (NEW) | 4.1 | +250 (instantiates Track01 from JSON) |
| `src/scripts/decor.gd` | 4.1 | +60 (reads circuit.decor) |
| `src/scripts/surface_zone.gd` (NEW) | 4.3 | +80 |
| `src/scripts/powerup_manager.gd` (NEW) | 4.3 | +250 |
| `src/scripts/powerups/*.gd` (NEW, ~6 files) | 4.4 | +400 (one per type) |
| `src/scenes/PowerUpBox.tscn` (NEW) | 4.3 | new scene |
| `src/scripts/car.gd` + `bot_car.gd` | 4.3 | +60 (zone effects + inventory) |
| `src/scripts/multiplayer_menu.gd` | 4.5 | +60 (circuit dropdown) |
| `server/mv3_server.py` | 4.4 | +60 (powerup_use sequence stamping) |
| `src/circuits/workshop.circuit.json` (NEW) | 4.5 | new |
| `src/circuits/breakfast.circuit.json` (NEW) | 4.5 | new |
| `src/circuits/bathroom.circuit.json` (NEW) | 4.5 | new |
| `src/scenes/Main.tscn` | various | wiring |

---

## 8. Out of scope (Phase 5+)

- Tournament mode (best-of-3, championship points)
- Custom car skins / cosmetics
- More than 4 circuits (sand pit, garden v2, school desk are easy
  follow-ons once the framework is in)
- Replay system
- Voice/text chat
- Leaderboards (DB-backed)

---

## 9. Approval gate

Before starting Phase 4.1:
1. Seb reads this spec.
2. Seb confirms the 3 circuit themes (workshop / breakfast / bathroom)
   or proposes alternates.
3. Seb confirms the power-up framework (single-slot inventory, RNG
   from circuit palette, server-stamped sequence in MP).
4. Seb answers the 5 open questions in §6.
5. Then `superpowers:executing-plans` opens Phase 4.1.
