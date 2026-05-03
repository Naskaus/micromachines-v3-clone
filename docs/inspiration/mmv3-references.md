# Micro Machines V3 — Visual References

> Captured 2026-05-03 from Seb. Inspiration for V0.16+ (post-bridge/arches refactor).
> Images live in `mmv3-refs/`.

## The DNA we're chasing

MMV3's signature is **household objects scaled UP, cars scaled DOWN**. The track is *painted/chalked on the surface itself* — there is rarely a "road mesh." The world is recognizable everyday stuff, and the player's brain fills in the toy-scale.

This is the inverse of modern racers (sterile asphalt, fictional locations). MMV3 wins on charm, not realism.

## Reference catalog

### `pool_table_playing_cards.png` — POOL TABLE (V3, V5)
- **Surface:** bright green felt with thin chalk/paint white lines marking the racing line
- **Obstacle/ramp:** giant playing card (Queen of Clubs) lying flat = jump ramp. Used for the **bridge / jump-over-the-crossing** concept.
- **Border:** wooden pool cue running along one edge as the boundary wall
- **HUD:** top-right `0.36 × LAPS 3` minimalist serif/sans, top-left position icon, ag.ru watermark
- **Camera:** ~70° tilt, top-down with mild perspective. Cars feel like dinky F1 toys.

**For us:** our current `pool_felt.gdshader` already nails the felt + chalk lines look. The playing card as bridge is a brilliant alternative to the box-mesh bridge in V0.15.0 — replace `BridgePlateau` with a giant Queen of Clubs Mesh (texture sourced from a CC0 card sprite + a thin BoxMesh). V0.16 candidate.

---

### `workshop_calculator_paint.png` — WORKSHOP (V4 maybe)
- **Surface:** painted concrete with traffic-light stripes (red/white/yellow) at start
- **Obstacles:** giant calculator buttons = bumps, paint cans, tape measure roll, wrench
- **Walls:** masking-tape barriers (yellow/black hazard tape)
- **Color palette:** muted grays + bright safety-orange/yellow accents

**For us:** the calculator is a classic. Could use it as a multi-button bumpy section (each button = a small ramp). Tape-measure as a curved rail — sweeps along the inside of a corner. V0.17+.

---

### `wood_desk_start_text.png` — WOOD DESK / "START" (V0.15 polish ?)
- **Surface:** dark wood grain
- **Painted track:** thick white painted line + thick painted "START" word in red serif on the floor
- **Cars:** purple toy cars, very chunky low-poly
- **Camera:** very high tilt, almost straight top-down, simpler than V3 reference

**For us:** the painted "START" text on the floor is an easy V0.15.x win. Add a `MeshInstance3D` with a Label3D / Decal at the spawn line saying `START` in white-painted-on-asphalt. Boosts readability of the start line beyond just an arch. V0.15.1 polish.

---

### `desk_pencils_book.png` — DESK / SCHOOL (V2 candidate)
- **Surface:** desk wood
- **Obstacles:** pens (green felt-tip, blue ballpoint), pencils, eraser, "How to..." book with cover art = vertical wall
- **Track:** painted/chalked white lines weaving between objects
- **Color:** warm beige + bright primary colors of stationery

**For us:** the BIGGEST insight here is **objects-as-track-furniture, not as decoration.** We have `pylon.glb`, `barrierWhite.glb`, etc. — but the MMV3 vibe is to use NON-RACE objects (pens, books, erasers) as obstacles. Add a "stationery pack" of low-poly pens/erasers/books as track-side obstacles in V0.17. The "How to..." book is gold — generate a low-poly book Mesh with a placeholder cover via blender-mcp.

---

### `picnic_plaid_donut.png` — PICNIC BLANKET
- **Surface:** plaid/tartan red+blue+white grid fabric, very high-frequency texture
- **Obstacles:** giant donut (with sprinkles!), what looks like a plate or coffee cup
- **Track:** subtle painted line on the plaid (low contrast — purposefully harder visibility, makes it more chaotic)

**For us:** plaid shader = 5 lines of GLSL. Easy V0.18+ track. The donut is iconic — generate a torus mesh with a pink frosting albedo + sprinkle decals. Use as a non-collidable spectacle OR a circular bumper. The chaos of low track-contrast on plaid is a *design feature*, not a flaw.

---

### `filing_cabinet_office.png` — OFFICE / FILING CABINET
- **Surface:** wood desk with vertical filing cabinet drawers as a backdrop wall
- **Obstacle:** giant ruler/thermometer with measurement markings (red gradient)
- **Camera:** more horizontal — almost side-view, cars are small dots
- **Vibe:** vertical urban-feeling track inside an office

**For us:** the vertical thermometer/ruler with markings is a *reused texture trick* — a flat plane with a measurement decal. Cheap to make, high visual impact. V0.17+.

---

### `garden_grass_dirt_path.png` — GARDEN
- **Surface:** bright green grass (looks like a low-poly grass mesh + texture)
- **Track:** dirt-brown beige path painted/printed on the grass
- **Obstacles:** none visible in this frame — minimalist "open garden" track

**For us:** grass shader trivial. Garden is the simplest possible MMV3 track — good candidate for an early "second track" after the pool table. Path is a brown decal/mesh. V0.16.

---

## Cross-cutting design rules extracted

1. **Track = painted lines on a surface, not road meshes.** Save modeling time, lean into the toy-scale feel.
2. **Obstacles = familiar objects, not cones/barriers.** Cones/pylons feel sterile; pencils/calculators/donuts feel alive.
3. **HUD is minimal.** Top-right: lap counter + timer in serif font. Top-left: position icons. That's it. No speed, no minimap (we have a minimap — it's nice-to-have but not MMV3-canonical).
4. **Camera tilt: 60-75°.** Not pure top-down. Slight perspective so players see what's ahead.
5. **Cars are chunky and brightly colored.** Our Kenney `.glb` cars already match.
6. **Surface texture is high-contrast and recognizable.** Felt, plaid, wood grain, grass — all instantly readable.
7. **Color palette per track is unified.** Pool table = green+white. Workshop = gray+orange. Don't mix.

## V0.16+ track ideas, ranked by effort

| Track | Effort | Why |
|---|---|---|
| **Pool table v2** (current Track01 reskin with playing-card bridge) | Low | Re-use pool_felt shader, add card mesh, easy win |
| **Garden** | Low | Grass shader + dirt path decal, no obstacles |
| **Wood desk + "START" text** | Low | Just add a desk-grain shader + a START decal at spawn |
| **Picnic plaid** | Medium | New plaid shader + donut mesh + low-contrast lane |
| **Workshop** | Medium-High | Multiple obstacle types (calculator, paint cans, tape) |
| **Office/filing cabinet** | High | Vertical scene = camera rework |
| **Desk with stationery** | Medium | Pen/eraser/book obstacle pack |

## Notes for V0.15.0 (current plan) — DO NOT add scope

The plan saved at `docs/superpowers/plans/2026-05-03-figure-infinity-bridge-arches.md` is:
- bridge geometry (box-mesh placeholder)
- 4 arches (box-mesh placeholder)
- 4-arch ordered checkpoint validation

These references are for **V0.15.1+** polish (replacing placeholders with Kenney/MMV3-flavored meshes) and **V0.16+** new tracks. Do NOT pull them into V0.15.0 scope.
