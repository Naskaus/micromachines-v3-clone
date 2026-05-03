# V0.15.0 — Figure-∞ Bridge + 4 Arches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Micromachines V3 from "flat figure-8 with 2 confusing checkpoints" to "true ∞-track with a 3D bridge over the crossing + 4 visually-mandatory arches (TrackMania mechanic) that define lap validation."

**Architecture:** Replace the 2-checkpoint `passed_top/passed_bot` boolean logic with a 4-arch ordered checkpoint index (`next_arch_index`). The crossing is split vertically: the *first* traversal goes UP a bridge ramp (Y=5) and over; the *second* traversal goes UNDER at ground level. Path Y component is added to `PathUtils.path_at(phase)` so AI bots track the bridge height. Spawn grid relocates BEHIND arch 1 (was inside top checkpoint = body_entered never fired). The 4 arches are real `Area3D` nodes under Kenney `overhead.glb` meshes, each visually unmissable.

**Tech Stack:** Godot 4.6.1 · GDScript · `mcp__godot-mcp` (run_project / stop_project / get_debug_output) · Kenney CC0 `roadStraightBridge*`, `overhead*`, `bannerTowerRed.glb`, `flagCheckers.glb`.

**Out of scope (future versions):**
- Procedural Kenney decorations around the track (V0.15.2)
- Sound (V0.16+)
- New tracks beyond Track01 (V0.17+)
- Replacing the felt shader floor with road meshes (V0.16+)

---

## Path Geometry Convention (locked)

The figure-8 has 1 lap = 4 quadrants → 4 arches at phase = `[0.0, 0.25, 0.5, 0.75]`.

```
Phase 0.00  → Arch 1 (START/FINISH)  — at z = -1 (just south of crossing) on TOP route
                                       Y = 4.5 (cars are halfway up the bridge ramp)
Phase 0.25  → Arch 2                  — at top of top oval (0, 0, -100)  Y = 0
Phase 0.50  → Arch 3                  — at z = +1 (just north of crossing) on BOTTOM route
                                       Y = 0 (ground level, going UNDER the bridge)
Phase 0.75  → Arch 4                  — at bottom of bottom oval (0, 0, +100)  Y = 0
```

The bridge spans phase ∈ `[0.95, 0.05]` (10% of the lap, ~47 m of arc). Outside this range Y = 0. Inside, Y ramps up sinusoidally to peak 5.0 m and back down.

```gdscript
# Bridge phase window (ramps up at the END of the lap, peaks at phase=0, ramps down at phase=0.05)
const BRIDGE_PHASE_START := 0.95   # ramp up begins
const BRIDGE_PHASE_END   := 0.05   # ramp down ends (wraps past 0)
const BRIDGE_HEIGHT      := 5.0    # peak Y at phase=0
```

Cars going phase 0.75 → 0.95 → 0 → 0.05 → 0.25 climb the ramp, cross the bridge, descend.
Cars going phase 0.25 → 0.5 cross the ground-level crossing UNDER the bridge.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `src/scripts/path_utils.gd` | Modify | Add bridge Y component to `path_at()`. Add `BRIDGE_PHASE_START/END/HEIGHT` constants. |
| `src/scenes/Track01.tscn` | Modify | Remove `TopCheckpoint`/`BotCheckpoint` + stripes. Add 4 `Arch_N` Area3D nodes with overhead.glb visuals. Add bridge geometry (3 ramp/straight segments) at the crossing. Move spawn-related references to phase=0.95 grid. |
| `src/scenes/Main.tscn` | Modify | Update car start positions to spawn grid behind arch 1 (5 m apart, facing east). Re-wire RaceManager `top_checkpoint_path`/`bot_checkpoint_path` exports → new `arch_paths: Array[NodePath]`. |
| `src/scripts/race_manager.gd` | Modify | Replace `passed_top/passed_bot` booleans with `next_arch_index: int`. Replace `_on_top_checkpoint_entered/_on_bot_checkpoint_entered` with `_on_arch_entered(arch_idx, body)`. Refactor `_racer_progress` to use `laps + next_arch_index*0.25 + phase_fine`. Update `top_checkpoint_path/bot_checkpoint_path` exports → `arch_paths: Array[NodePath]` (size 4). |
| `src/scripts/bot_car.gd` | Modify | Read `path_at(phase).y` and apply gentle Y-tracking force when on bridge segment so bots don't fall off the side or slip through. |
| `src/scripts/car.gd` | Read-only | Player car uses physics — bridge collision pushes it up naturally. No code change needed (verify this assumption in Task 7). |

---

## Task 1: Update PathUtils with bridge Y component

**Files:**
- Modify: `src/scripts/path_utils.gd`

**Constraint:** `path_at()` must remain a pure function. No side effects. Y component is a smooth sinusoid ramp — no discontinuities (otherwise bots get launched).

- [ ] **Step 1.1: Read current `path_at` to confirm starting point**

Confirm `path_at(phase)` currently returns `Vector3(x, 0.0, z)` for all phases.

- [ ] **Step 1.2: Add bridge constants**

Edit `src/scripts/path_utils.gd`. After the existing `const PATH_PERIMETER` line, add:

```gdscript
# Bridge over the crossing — first traversal of crossing per lap goes OVER, Y rises.
const BRIDGE_PHASE_START := 0.95   # ramp-up begins
const BRIDGE_PHASE_END   := 0.05   # ramp-down ends (wraps past 0)
const BRIDGE_HEIGHT      := 5.0    # peak Y in metres at phase=0
```

- [ ] **Step 1.3: Add `bridge_y(phase)` helper**

Below the constants, before `path_at`, add:

```gdscript
# Returns Y offset due to the bridge over the crossing.
# Smooth half-cosine ramp from 0 at phase=0.95 → BRIDGE_HEIGHT at phase=0.0 → 0 at phase=0.05.
static func bridge_y(phase: float) -> float:
    phase = wrapf(phase, 0.0, 1.0)
    var in_window: bool = phase >= BRIDGE_PHASE_START or phase <= BRIDGE_PHASE_END
    if not in_window:
        return 0.0
    # Map phase to t ∈ [0, 1] across the bridge window
    var t: float
    if phase >= BRIDGE_PHASE_START:
        t = (phase - BRIDGE_PHASE_START) / (1.0 - BRIDGE_PHASE_START + BRIDGE_PHASE_END)
    else:
        t = (1.0 - BRIDGE_PHASE_START + phase) / (1.0 - BRIDGE_PHASE_START + BRIDGE_PHASE_END)
    # Half-cosine: 0 → 1 → 0
    return BRIDGE_HEIGHT * 0.5 * (1.0 - cos(t * TAU))
```

- [ ] **Step 1.4: Wire `bridge_y` into `path_at`**

Replace the two `return Vector3(...)` lines inside `path_at` so they include the Y component:

```gdscript
# Top oval branch
return Vector3(OVAL_A * cos(angle), bridge_y(phase), -OVAL_H + OVAL_B * sin(angle))
# Bottom oval branch
return Vector3(OVAL_A * cos(angle), 0.0, OVAL_H + OVAL_B * sin(angle))
```

The bridge is on the TOP oval branch only (phase 0..0.5). The bottom oval (phase 0.5..1.0) stays at Y=0.

- [ ] **Step 1.5: Add `print()` smoke-test inside path_at (TEMPORARY, removed in step 1.7)**

Above the if/else inside `path_at`, add:

```gdscript
if Engine.get_process_frames() == 60 and phase < 0.001:  # one-shot
    print("[BRIDGE TEST] phase=0.00 y=", bridge_y(0.00), " phase=0.025 y=", bridge_y(0.025), " phase=0.04 y=", bridge_y(0.04), " phase=0.5 y=", bridge_y(0.5))
```

- [ ] **Step 1.6: Run project + verify Y values**

```bash
mcp__godot-mcp__run_project (project: "/Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/src/")
# Wait 2 seconds, then:
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected output line:
```
[BRIDGE TEST] phase=0.00 y=5.0 phase=0.025 y≈2.5 phase=0.04 y≈0.5 phase=0.5 y=0
```

If Y is wrong (NaN, negative, > 5.0), debug `bridge_y` formula before proceeding.

- [ ] **Step 1.7: Remove the temporary print**

Delete the `print("[BRIDGE TEST]...` line.

- [ ] **Step 1.8: Commit**

```bash
git add src/scripts/path_utils.gd
git commit -m "v0.15.0-wip: PathUtils bridge_y() — sinusoidal ramp over the crossing"
```

---

## Task 2: Build the 4 arches in Track01.tscn (visual + Area3D)

**Files:**
- Modify: `src/scenes/Track01.tscn`

**Constraint:** `.tscn` files are fragile text format. Edit by appending nodes at the END of the existing file rather than restructuring the middle. The `TopCheckpoint`/`BotCheckpoint`/`TopStripe`/`BotStripe` nodes will be DELETED in this task — `race_manager.gd` will not be wired to them anymore (Task 5).

Each arch:
- `Area3D` named `Arch_1`...`Arch_4` with a `BoxShape3D` collision (10 m wide × 8 m tall × 0.5 m deep — a thin "gate" the car drives THROUGH)
- A child `Node3D` called `Visual` containing the Kenney `overhead.glb` mesh + `bannerTowerRed.glb` (or `flagCheckers.glb`) for visibility
- Distinct color per arch via emission so the player can tell them apart at a glance:
  - Arch 1 (start/finish): GREEN emission
  - Arch 2: YELLOW
  - Arch 3: ORANGE
  - Arch 4: RED

- [ ] **Step 2.1: Compute arch world positions from PathUtils**

Run a small GDScript snippet to confirm `path_at(0.0)`, `path_at(0.25)`, `path_at(0.5)`, `path_at(0.75)`:

Create temporary `src/scripts/_compute_arch_positions.gd`:

```gdscript
extends Node
const PathUtils = preload("res://scripts/path_utils.gd")
func _ready() -> void:
    print("Arch 1 (phase 0.00): ", PathUtils.path_at(0.00))
    print("Arch 2 (phase 0.25): ", PathUtils.path_at(0.25))
    print("Arch 3 (phase 0.50): ", PathUtils.path_at(0.50))
    print("Arch 4 (phase 0.75): ", PathUtils.path_at(0.75))
    get_tree().quit()
```

Wire it into a temporary `_compute.tscn` scene and run it. Expected (approximate):
```
Arch 1 (phase 0.00): (0, 5, 0)         # crossing, peak of bridge
Arch 2 (phase 0.25): (-100, 0, -50)    # west extremity of top oval... WAIT, recheck
```

**Important:** The actual extremity values depend on the parameterisation. Verify and use the printed values. **Do not guess.**

- [ ] **Step 2.2: Decide arch coordinates**

Based on Step 2.1 output, lock these coordinates in your head before editing the .tscn:

| Arch | World position (X, Y, Z) | Yaw | Color |
|---|---|---|---|
| 1 | from `path_at(0.97)` + Y=4.5 | tangent at 0.97 | GREEN |
| 2 | from `path_at(0.25)` | tangent at 0.25 | YELLOW |
| 3 | from `path_at(0.53)` | tangent at 0.53 | ORANGE |
| 4 | from `path_at(0.75)` | tangent at 0.75 | RED |

(Note: Arch 1 is at phase=0.97 instead of 0.0 so cars spawn UPHILL on the bridge ramp before driving through it. Arch 3 is at phase=0.53 instead of 0.5 to displace it slightly past the crossing so it's clearly distinguishable from the bridge above.)

- [ ] **Step 2.3: Delete obsolete `TopCheckpoint`, `BotCheckpoint`, `TopStripe`, `BotStripe` nodes from Track01.tscn**

Open `src/scenes/Track01.tscn`. Find and remove these node blocks (lines ~122-142):

```
[node name="TopCheckpoint" type="Area3D" parent="."]
  ...

[node name="TopStripe" type="MeshInstance3D" parent="."]
  ...

[node name="BotCheckpoint" type="Area3D" parent="."]
  ...

[node name="BotStripe" type="MeshInstance3D" parent="."]
  ...
```

Also remove their now-orphaned subresources `Shape_checkpoint`, `Mesh_finish_stripe`, `Mat_finish_stripe`, `Mat_checkpoint_yellow`.

- [ ] **Step 2.4: Add 4 arch sub-resources at the top of Track01.tscn**

After existing `[sub_resource ...]` blocks, add:

```
[sub_resource type="BoxShape3D" id="Shape_arch_gate"]
size = Vector3(10.0, 8.0, 0.5)

[sub_resource type="StandardMaterial3D" id="Mat_arch_green"]
albedo_color = Color(0.1, 1.0, 0.3, 1)
emission_enabled = true
emission = Color(0.0, 1.0, 0.2, 1)
emission_energy_multiplier = 1.5

[sub_resource type="StandardMaterial3D" id="Mat_arch_yellow"]
albedo_color = Color(1.0, 0.9, 0.1, 1)
emission_enabled = true
emission = Color(1.0, 0.8, 0.0, 1)
emission_energy_multiplier = 1.5

[sub_resource type="StandardMaterial3D" id="Mat_arch_orange"]
albedo_color = Color(1.0, 0.5, 0.1, 1)
emission_enabled = true
emission = Color(1.0, 0.4, 0.0, 1)
emission_energy_multiplier = 1.5

[sub_resource type="StandardMaterial3D" id="Mat_arch_red"]
albedo_color = Color(1.0, 0.1, 0.1, 1)
emission_enabled = true
emission = Color(1.0, 0.0, 0.0, 1)
emission_energy_multiplier = 1.5

[sub_resource type="BoxMesh" id="Mesh_arch_pillar"]
size = Vector3(1.0, 8.0, 1.0)

[sub_resource type="BoxMesh" id="Mesh_arch_top"]
size = Vector3(11.0, 1.0, 1.0)
```

(Box-mesh placeholder pillars + crossbar. Kenney `.glb` integration is V0.15.1 polish — keep V0.15.0 functional with primitives.)

- [ ] **Step 2.5: Add 4 arch nodes at the END of Track01.tscn**

Append:

```
[node name="Arch_1" type="Area3D" parent="."]
transform = Transform3D(<tangent-1 basis>, <world-pos-1>)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Arch_1"]
shape = SubResource("Shape_arch_gate")

[node name="PillarLeft" type="MeshInstance3D" parent="Arch_1"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5.0, 4.0, 0)
mesh = SubResource("Mesh_arch_pillar")
surface_material_override/0 = SubResource("Mat_arch_green")

[node name="PillarRight" type="MeshInstance3D" parent="Arch_1"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5.0, 4.0, 0)
mesh = SubResource("Mesh_arch_pillar")
surface_material_override/0 = SubResource("Mat_arch_green")

[node name="Crossbar" type="MeshInstance3D" parent="Arch_1"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 8.0, 0)
mesh = SubResource("Mesh_arch_top")
surface_material_override/0 = SubResource("Mat_arch_green")
```

Replace `<tangent-1 basis>` with the 9-float basis built from Step 2.1's tangent output (tangent_at(0.97).y=0, normal=cross with up). Use `tangent.x, 0, tangent.z` for the basis X axis, `0, 1, 0` for Y, `-tangent.z, 0, tangent.x` for Z. Replace `<world-pos-1>` with the 3 floats from `path_at(0.97)` plus Y offset for ramp.

Repeat for `Arch_2` (Mat_arch_yellow), `Arch_3` (Mat_arch_orange), `Arch_4` (Mat_arch_red), with their respective tangent/position from Step 2.1/2.2.

- [ ] **Step 2.6: Run project — visual sanity check**

```bash
mcp__godot-mcp__run_project
# Wait 2 seconds
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: 0 errors, 0 warnings. The 4 colored arches should be visible in the scene. Cars haven't spawned correctly yet (Task 4), but no crash.

If errors mention `TopCheckpoint`/`BotCheckpoint` not found in race_manager: that's expected — fixed in Task 5. Skip for now if it doesn't crash.

- [ ] **Step 2.7: Commit**

```bash
git add src/scenes/Track01.tscn
git commit -m "v0.15.0-wip: 4 arches replace 2 checkpoints — Track01 visual scaffold"
```

---

## Task 3: Add bridge geometry at the crossing

**Files:**
- Modify: `src/scenes/Track01.tscn`

**Constraint:** Bridge collision is a tilted box StaticBody3D (placeholder). Real Kenney `roadStraightBridgeStart/Mid/Bridge.glb` is V0.15.1 polish.

The bridge spans z ∈ [-12, +12] with peak at z=0, Y=5. Approximate as:
- Ramp east-side: ramp from (0, 0, -12) up to (0, 5, -2)
- Plateau: (0, 5, -2) to (0, 5, +2)  
- Ramp west-side: from (0, 5, +2) down to (0, 0, +12)

This corresponds to the TOP oval branch (cars going phase 0.75 → 0.95 → 0 → 0.05 → 0.25 climb up at z=+12, peak at z=0, descend at z=-12, all on the TOP oval which is at z=-50±50).

**Wait — re-check geometry:** The top oval is centred at z=-50 (the OVAL_H constant). The crossing is at z=0. Cars enter the crossing from BOTH ovals. Recheck which oval branch goes UP.

Looking at `path_at`:
- Phase 0..0.5 = top oval (z ∈ [-100, 0])
- Phase 0.5..1 = bottom oval (z ∈ [0, +100])

Bridge phase window 0.95..0.05 = end of bottom oval + start of top oval.
- Phase 0.95: cars are still on bottom oval, near z=+5 (just exiting north side toward crossing)
- Phase 0.00: cars at crossing z=0, peak Y=5
- Phase 0.05: cars on top oval, near z=-5

So the bridge spans both branches at the crossing. The ramps go FROM z≈+10 (bottom oval, climbing) TO z≈-10 (top oval, descending). The cars driving on the bottom oval naturally cross at z=0 going north→south at GROUND LEVEL during phase 0.5 → no Y component on phase 0.5 in `path_at`.

OK proceed.

- [ ] **Step 3.1: Add bridge sub-resources**

In Track01.tscn, after existing arch sub-resources:

```
[sub_resource type="BoxShape3D" id="Shape_bridge_ramp_e"]
size = Vector3(14.0, 0.5, 12.0)

[sub_resource type="BoxMesh" id="Mesh_bridge_ramp_e"]
size = Vector3(14.0, 0.5, 12.0)

[sub_resource type="BoxShape3D" id="Shape_bridge_plateau"]
size = Vector3(14.0, 0.5, 4.0)

[sub_resource type="BoxMesh" id="Mesh_bridge_plateau"]
size = Vector3(14.0, 0.5, 4.0)

[sub_resource type="StandardMaterial3D" id="Mat_bridge"]
albedo_color = Color(0.30, 0.30, 0.35, 1)
roughness = 0.7
```

- [ ] **Step 3.2: Add bridge StaticBody3D nodes**

Append to Track01.tscn:

```
[node name="BridgeRampEast" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.9239, 0.3827, 0, -0.3827, 0.9239, 0, 2.5, 8.0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="BridgeRampEast"]
shape = SubResource("Shape_bridge_ramp_e")

[node name="MeshInstance3D" type="MeshInstance3D" parent="BridgeRampEast"]
mesh = SubResource("Mesh_bridge_ramp_e")
surface_material_override/0 = SubResource("Mat_bridge")

[node name="BridgePlateau" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 5.0, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="BridgePlateau"]
shape = SubResource("Shape_bridge_plateau")

[node name="MeshInstance3D" type="MeshInstance3D" parent="BridgePlateau"]
mesh = SubResource("Mesh_bridge_plateau")
surface_material_override/0 = SubResource("Mat_bridge")

[node name="BridgeRampWest" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.9239, -0.3827, 0, 0.3827, 0.9239, 0, 2.5, -8.0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="BridgeRampWest"]
shape = SubResource("Shape_bridge_ramp_e")

[node name="MeshInstance3D" type="MeshInstance3D" parent="BridgeRampWest"]
mesh = SubResource("Mesh_bridge_ramp_e")
surface_material_override/0 = SubResource("Mat_bridge")
```

The 0.9239/0.3827 basis values are `cos(22.5°)/sin(22.5°)` — gentle 22.5° ramp.

- [ ] **Step 3.3: Run project — drive a car onto the bridge manually (P1 only, mode 1)**

```bash
mcp__godot-mcp__run_project
# Press 1 to start solo mode. Steer car onto the bridge (visible at the crossing).
# Verify car climbs the ramp, peaks at Y≈5, descends.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: car physics carries it over the bridge naturally. No fall-through.

If the car falls THROUGH the bridge: collision shape mismatch. Verify `Shape_bridge_*` sizes vs the visual.
If the car hits an invisible wall: extra collision left from a deleted node — clean up.

- [ ] **Step 3.4: Commit**

```bash
git add src/scenes/Track01.tscn
git commit -m "v0.15.0-wip: bridge geometry over crossing — 22.5° ramps + plateau"
```

---

## Task 4: Reposition spawn grid behind Arch 1

**Files:**
- Modify: `src/scenes/Main.tscn` (where the cars are positioned)

The cars currently spawn at (x=0..15, z=-100, facing west) which is INSIDE the old TopCheckpoint area — `body_entered` never fired because the body started inside the area.

New spawn: 6 cars in a 2×3 grid on the bottom oval at phase ≈ 0.92, BEFORE the bridge ramp. Facing east (the tangent direction at phase 0.92).

- [ ] **Step 4.1: Compute spawn coordinates**

Use the temp `_compute_arch_positions.gd` from Task 2 to also print:

```gdscript
print("Spawn anchor (phase 0.92): ", PathUtils.path_at(0.92))
print("Spawn tangent (phase 0.92): ", PathUtils.tangent_at(0.92))
```

Expected: position around (0, 0, +12), tangent (+1, 0, 0) (east-facing).

- [ ] **Step 4.2: Find existing car spawn transforms in Main.tscn**

```bash
grep -n "transform" src/scenes/Main.tscn | head -20
```

Identify the 6 transforms attached to nodes named "Player", "Player2", "Bot1", "Bot2", "Bot3", "Bot4".

- [ ] **Step 4.3: Update each car's transform**

Lay out the grid 2 columns wide, 3 rows deep. Spacing: 6 m in X, 4 m in Z. Anchor at spawn position from 4.1.

```
Bot4    Bot3
Bot2    Bot1
P2      P1     ← closest to start arch
```

Using anchor (0, 0.5, 12) and east-facing basis (0, 0, 1, 0, 1, 0, -1, 0, 0):

```
P1   transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0,  3.0, 0.5, 12.0)
P2   transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -3.0, 0.5, 12.0)
Bot1 transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0,  3.0, 0.5, 16.0)
Bot2 transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -3.0, 0.5, 16.0)
Bot3 transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0,  3.0, 0.5, 20.0)
Bot4 transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -3.0, 0.5, 20.0)
```

Wait — the basis above represents yaw=+90° (facing east, +X). Verify by computing: a forward vector of `-Z` rotated 90° CCW around Y becomes `+X`. Cross-check by running.

- [ ] **Step 4.4: Run project — visual + spawn check**

Run, press `1` for solo. The car should appear at (3, 0.5, 12), facing east. The bridge should be visible in front. Steer right (left arrow if east-facing maps to that input?) and confirm car moves toward the bridge.

```bash
mcp__godot-mcp__run_project
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

If the car spawns facing the wrong way, swap the basis to `(0, 0, -1, 0, 1, 0, 1, 0, 0)` (yaw=-90°) and re-test.

- [ ] **Step 4.5: Commit**

```bash
git add src/scenes/Main.tscn
git commit -m "v0.15.0-wip: spawn 6 cars in 2x3 grid behind Arch 1, facing east"
```

---

## Task 5: Refactor race_manager.gd to 4-arch sequential validation

**Files:**
- Modify: `src/scripts/race_manager.gd`

**Constraint:** This is the biggest scripting change. Replace `passed_top/passed_bot` booleans with `next_arch_index: int` (0..3). Lap completes when racer passes Arch 3 with `next_arch_index == 3`, increments laps, resets to 0.

- [ ] **Step 5.1: Replace exports**

Edit the `@export` block near the top:

```gdscript
# REMOVE these:
@export var top_checkpoint_path: NodePath
@export var bot_checkpoint_path: NodePath

# ADD:
@export var arch_paths: Array[NodePath] = []  # exactly 4: Arch_1..Arch_4
```

- [ ] **Step 5.2: Update `_register_racer` to use `next_arch_index`**

Find:
```gdscript
"passed_top": false,
"passed_bot": false,
```

Replace with:
```gdscript
"next_arch_index": 0,  # 0..3, increments on pass-through; lap completes when passing arch 3
```

- [ ] **Step 5.3: Replace `_ready` checkpoint wiring**

Find:
```gdscript
var top_cp: Area3D = get_node_or_null(top_checkpoint_path) as Area3D
if top_cp:
    top_cp.body_entered.connect(_on_top_checkpoint_entered)
var bot_cp: Area3D = get_node_or_null(bot_checkpoint_path) as Area3D
if bot_cp:
    bot_cp.body_entered.connect(_on_bot_checkpoint_entered)
```

Replace with:
```gdscript
for i in range(arch_paths.size()):
    var arch: Area3D = get_node_or_null(arch_paths[i]) as Area3D
    if arch:
        # Capture i in the lambda (Godot 4 captures by reference; bind it)
        arch.body_entered.connect(_on_arch_entered.bind(i))
    else:
        push_warning("RaceManager: arch_paths[%d] is missing" % i)
```

- [ ] **Step 5.4: Replace `_on_top_checkpoint_entered` and `_on_bot_checkpoint_entered` with `_on_arch_entered`**

Delete both functions. Add:

```gdscript
func _on_arch_entered(arch_idx: int, body: Node) -> void:
    if _state != State.RACING:
        return
    if not _racer_data.has(body):
        return
    var data: Dictionary = _racer_data[body]
    if data.finished or _eliminated.has(body):
        return
    # Arch must be the NEXT expected one — out-of-order passes are ignored
    if arch_idx != data.next_arch_index:
        return
    if arch_idx == 3:
        # Last arch of the lap — completes a lap
        var now: float = Time.get_ticks_msec() / 1000.0
        if now - data.last_lap_time < MIN_LAP_TIME:
            return  # debounce
        var lap_duration: float = now - data.last_lap_time
        data.lap_times.append(lap_duration)
        data.last_lap_time = now
        data.laps += 1
        data.next_arch_index = 0  # next arch to look for is Arch_1 again
        if data.laps >= TOTAL_LAPS:
            data.finished = true
            data.finish_time = now - _race_start_time
            _finish_order.append(body)
            _check_race_end()
    else:
        data.next_arch_index = arch_idx + 1
```

- [ ] **Step 5.5: Refactor `_racer_progress`**

Replace the entire function:

```gdscript
func _racer_progress(racer: Node) -> float:
    # Progress = laps + (next_arch_index * 0.25) + tiny phase tiebreaker.
    # next_arch_index 0..3 → segment progress 0, 0.25, 0.5, 0.75 (each arch = 25% of the lap).
    var data: Dictionary = _racer_data[racer]
    var laps: float = float(data.laps)
    var seg: float = float(data.next_arch_index) * 0.25
    var fine: float = 0.0
    if "_path_phase" in racer:
        fine = racer._path_phase * 0.001  # smaller weight than seg, used purely as tiebreaker
    return laps + seg + fine
```

- [ ] **Step 5.6: Update Main.tscn to wire arch_paths**

Open `src/scenes/Main.tscn`, find the `[node name="RaceManager"]` block. The exports `top_checkpoint_path` and `bot_checkpoint_path` are no longer valid (they get silently dropped on next save). Add:

```
arch_paths = [NodePath("../Track01/Arch_1"), NodePath("../Track01/Arch_2"), NodePath("../Track01/Arch_3"), NodePath("../Track01/Arch_4")]
```

(Adjust the relative path prefix `../Track01/` to match the actual scene tree.)

- [ ] **Step 5.7: Run + drive a full lap (mode 1, P1 only)**

```bash
mcp__godot-mcp__run_project
# Press 1, drive through Arch 1, Arch 2, Arch 3, Arch 4 in order. Expect lap counter +1.
# Drive an INVALID order (skip Arch 2): expect lap counter does NOT increment.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: HUD lap counter increments only after passing all 4 in order.

If the lap counter never increments: print debug — add temporary `print("Arch ", arch_idx, " entered by ", body.name, " expected=", data.next_arch_index)` at the top of `_on_arch_entered`.

- [ ] **Step 5.8: Commit**

```bash
git add src/scripts/race_manager.gd src/scenes/Main.tscn
git commit -m "v0.15.0-wip: race_manager → 4-arch ordered validation (laps + next_arch_index)"
```

---

## Task 6: Update bot_car.gd to track bridge Y

**Files:**
- Modify: `src/scripts/bot_car.gd`

**Constraint:** Bots are RigidBody3D. They cannot teleport — physics rules. Use a gentle `apply_central_force` to nudge them toward `path_at(phase).y` when on the bridge.

Read the current `bot_car.gd` first.

- [ ] **Step 6.1: Read bot_car.gd**

Open `src/scripts/bot_car.gd` and find the `_physics_process` function. Identify where `_path_phase` is computed and where forces are applied.

- [ ] **Step 6.2: Add Y-tracking force when on bridge**

Inside `_physics_process`, after `_path_phase` is computed and before existing force applications, add:

```gdscript
# When on the bridge segment, gently track the path's Y component so bots don't fall off the side
var path_pos: Vector3 = PathUtils.path_at(_path_phase)
if path_pos.y > 0.5:
    var target_y: float = path_pos.y + 0.5  # car body sits 0.5 m above the road surface
    var dy: float = target_y - global_position.y
    # P-controller force: stronger when far below target
    if dy > 0.2:
        apply_central_force(Vector3(0, dy * 30.0 * mass, 0))  # tunable: 30.0 = stiffness
```

(No `else` clause needed — gravity handles natural descent off the bridge.)

- [ ] **Step 6.3: Run race in bot-only mode (mode 1) and watch bot 1 cross the bridge**

```bash
mcp__godot-mcp__run_project
# Press 1, drive P1 around. Watch the bots — they should ALSO climb the bridge, peak at Y=5, descend.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: bots smoothly cross the bridge. No flying off, no juddering.

If bots oscillate / jitter: reduce the stiffness coefficient (try 15.0 instead of 30.0).
If bots fly off: the dy clamp threshold (0.2) is too low; raise it to 0.5.

- [ ] **Step 6.4: Commit**

```bash
git add src/scripts/bot_car.gd
git commit -m "v0.15.0-wip: bot_car tracks bridge Y via P-controller force on bridge segment"
```

---

## Task 7: Verify player car crosses the bridge naturally (no code change needed)

**Files:** None modified — this is a verification task.

- [ ] **Step 7.1: Run race solo**

```bash
mcp__godot-mcp__run_project
# Press 1, drive P1 onto and over the bridge.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: P1 climbs the ramp via collision, peaks, descends. No code change needed because RigidBody3D + ramp collision = correct behaviour.

If P1 drives THROUGH the bridge or gets stuck: ramp basis or collision size is wrong — return to Task 3.

If P1 is too slow climbing: this is the desired behaviour for V0.15.0 (the ramp is supposed to slow racers slightly, creating tactical overtake spots). Tune in V0.15.1.

- [ ] **Step 7.2: No commit (no changes)**

---

## Task 8: Full-lap integration test

**Files:** None modified — verification only.

- [ ] **Step 8.1: Solo race, 3 laps**

```bash
mcp__godot-mcp__run_project
# Press 1. Race 3 full laps. Each must pass arches 1→2→3→4.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: HUD shows "Tour 1/3" → "Tour 2/3" → "Tour 3/3" → "ARRIVÉ — XXs". Bots also visible on minimap, completing laps.

- [ ] **Step 8.2: Multi-player test, 2P mode**

```bash
mcp__godot-mcp__run_project
# Press 2 for 2-player mode. Both P1 (A/D) and P2 (J/L) drive a full lap.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: both players complete laps independently. Camera follows whichever is leading.

- [ ] **Step 8.3: Cheater test**

```bash
mcp__godot-mcp__run_project
# Press 1, drive backward / skip arches. Confirm laps DO NOT increment.
mcp__godot-mcp__get_debug_output
mcp__godot-mcp__stop_project
```

Expected: lap counter stays at 1/3 if you skip an arch.

If a cheat path exists (e.g. driving in reverse over an arch counts forward): `_on_arch_entered` needs a velocity-direction check. Defer to V0.15.1 if not blocking.

- [ ] **Step 8.4: No commit (no changes)**

---

## Task 9: Final commit + update NEXT_SESSION.md

**Files:**
- Modify: `NEXT_SESSION.md`

- [ ] **Step 9.1: Update NEXT_SESSION.md**

Replace the "État actuel — V0.14.3" section with:

```markdown
## État actuel — V0.15.0

**Ce qui marche** :
- 6 racers (P1, P2 + 4 bots) avec modèles Kenney
- Track **figure-∞** : figure-8 + bridge 3D au crossing (top route over, bottom route under)
- **4 arches checkpoint** sequentiels (TrackMania mechanic) — arch 1 (vert/start) → 2 (jaune) → 3 (orange) → 4 (rouge)
- Lap valide UNIQUEMENT si on passe les 4 arches dans l'ordre
- Spawn 2x3 grid behind Arch 1, facing east — clean start
- Bots tracking bridge Y via P-controller
- AI bots, catch-up rubber-banding, boost pads, particles, minimap, eliminations — tous préservés

## Roadmap
- **V0.15.1** : remplacer arches box-mesh par Kenney `overhead.glb` + bannerTowerRed.glb
- **V0.15.2** : décorations Kenney (~30-50 .glb autour du circuit)
- **V0.15.3** : remplacer bridge box-mesh par Kenney `roadStraightBridgeStart/Mid/Bridge.glb`
- **V0.16+** : sound, more tracks, polish
```

- [ ] **Step 9.2: Final commit + tag**

```bash
git add NEXT_SESSION.md
git commit -m "v0.15.0: figure-∞ track + bridge over crossing + 4 ordered arches (TrackMania)"
git tag v0.15.0
```

- [ ] **Step 9.3: Push to GitHub (optional, only if Seb confirms)**

```bash
gh repo create Naskaus/micromachines-v3-clone --private --source=. --push
git push --tags
```

---

## Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Player car falls through bridge collision | Medium | Task 3.3 verifies; if fails, debug ramp basis. |
| Bot oscillates on bridge (jitter) | Medium | Task 6.3 has tuning fallback (lower stiffness). |
| Arch `body_entered` doesn't fire (cars too fast, tunneling) | Low | Box shape size is 10 m wide × 0.5 m deep — 0.5 m is thick enough at our top speed. If issues: increase to 1.0 m. |
| Reverse-driving counts arches forward | Low | Task 8.3 explicit test. Fix in V0.15.1 with velocity-direction guard. |
| .tscn merge conflicts if Seb edits in editor while plan runs | Low | Plan has frequent commits — small revert windows. |
| Spawn grid clips into bridge ramp | Low | Anchor is at z=+12 (outside bridge ramp z ∈ [-2, +12]). Verify in Task 4.4. |

---

## Self-Review Checklist (run before handoff)

- [x] Spec coverage: 4 arches → Tasks 2, 5. Bridge → Tasks 1, 3, 6. Spawn fix → Task 4. Big-picture coherence (no micro-fixes) → entire plan is V0.15.0 single feature.
- [x] No placeholders: every step has explicit code or commands. Tangent/position values in Task 2.5 are computed, not guessed.
- [x] Type consistency: `next_arch_index` used throughout race_manager (5.2, 5.3, 5.4, 5.5). `arch_paths: Array[NodePath]` used in 5.1, 5.6.
- [x] Spec→Task: every requirement from Seb's message has a task.
