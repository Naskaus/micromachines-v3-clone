# Lessons — Micromachines V3 Clone

Hard-won knowledge. Add new entries on top.

## 2026-05-03 — Decor scale and visibility

**What happened:** Initial decor batch placed `barrierWhite`, `bannerTowerRed/Green`, `grandStandRound` at racing-line scale. Seb: "c'est vraiment 10 a 20x trop petit" — invisible from camera height (22m) on a 200×200m track.

**Root cause:** Kenney `.glb` items are modeled at human scale (1-3m). Our racing track is 200×200m with cars 2-3m. Without scaling up, decor looks like specks.

**Rule:** For decor on a 200m+ track at top-down camera ≥20m above ground, **scale toy items ×8-12 minimum**. Boxes (most blocky) at ×8 are the visual reference. Banners need ×3-4 (already taller). Use the largest car size (~3m) as a sanity-check ratio.

**How to apply:** Always test decor scale after first placement by running the project and checking from camera POV. A "subtle" decoration on a large track is invisible — it's better to err big and downscale than ship invisible.

---

## 2026-05-03 — GLB visual decor needs `_spawn_visual` (no auto-collision)

**What happened:** Hot Wheels `track-narrow-looping.glb` placed via `_spawn_collidable` → cars couldn't drive through them, but they were placed in middle of racing line. Seb: "elles sont vraiment mal place... au milieu de la piste. on peut les traverser".

**Root cause:** The GLBs imported into Godot 4 do NOT auto-generate collision by default. `_spawn_collidable` wraps in StaticBody3D + BoxShape3D AABB. A pure-decoration GLB needs `_spawn_visual` — just the mesh, no body, no collision.

**Rule:** Hot Wheels-style ARCHITECTURAL decor (loops, banked ramps, finish gates) that should NOT block cars must use `_spawn_visual` (raw GLB instance, identity StaticBody3D not added). Items meant to be obstacles (cones, boxes, food kit) use `_spawn_collidable`.

**How to apply:** Before placing decor, ask: "should the car bump into this, or pass through?" If pass-through → `_spawn_visual`. If obstacle → `_spawn_collidable`.

---

## 2026-05-03 — Label3D ground rotation order matters

**What happened:** Painted "START" Label3D at the start line ended up vertical, planted in the ground sideways. Seb: "le start est completement de travers comm si il etiat planter dans le sol a la verticale".

**Root cause:** `Basis.rotated(axis, angle)` is PRE-multiplication (`Basis(axis, angle) * self`), not post. Order matters: `Basis(UP, yaw).rotated(RIGHT, -PI/2)` ≠ `Basis(RIGHT, -PI/2).rotated(UP, yaw)`. Got the order wrong.

**Rule:** For a Label3D laying flat on the ground reading from above:
1. Default Label3D text is in XY plane, top +Y, normal +Z
2. To lay flat: rotate -90° around X axis FIRST → text now XZ plane, normal +Y
3. To yaw: rotate around Y AFTER

```gdscript
var b: Basis = Basis(Vector3.RIGHT, -PI / 2.0)  # lay flat first
b = b.rotated(Vector3.UP, yaw)  # yaw second (pre-multiplied = applied after)
```

**Alternative (cleaner):** use `Basis.from_euler(Vector3(-PI/2, yaw, 0))` directly.

**How to apply:** When placing flat-on-ground Label3D, validate visually after the first attempt. Rotation bugs are 1-line fixes but only spotted in-engine.

---

## 2026-05-03 — Bot rubber-band sign was inverted (long-standing bug)

**What happened:** AI bots never finished races. Seb: "Les IA sont nul pas une seul fini la course". Investigation showed `_bot_top_speed` formula was inverted — bots AHEAD got faster, bots BEHIND got slower.

**Root cause:** `bot_car.gd:312` had `rubber = 1.0 + clamp(t_diff / 0.25, ...) * RUBBER_MAX`. With `t_diff > 0` meaning bot ahead, this made the bot faster (wrong). Catch-up rubber-banding should slow leaders + speed up stragglers.

**Rule:** Catch-up rubber-banding sign convention: `rubber = 1.0 - clamp(diff_signed) * MAX`. Always sanity-check the sign by computing for both sign cases of `diff_signed`.

**How to apply:** When tuning AI behaviors involving signed differences (lap fraction, distance, score), explicitly test the boundary cases (+max diff, -max diff, zero) and verify the speed/behavior moves in the intended direction.

---

## 2026-05-03 — Signal `bind()` args are APPENDED, not prepended

**What happened:** First implementation of `arch.body_entered.connect(_on_arch_entered.bind(i))` had signature `func _on_arch_entered(arch_idx: int, body: Node)`. Crashed with "Cannot convert argument 1 from Object to int" when fired.

**Root cause:** Godot 4's `Callable.bind()` APPENDS bound arguments to the signal's natural args. The signal `body_entered(body)` fires with `body` first, then bound `i` second. Function must be `(body, arch_idx)` not `(arch_idx, body)`.

**Rule:** Signal handler signatures with `bind()`: signal's natural args FIRST, bound args LAST.

**How to apply:** When using `Callable.bind()` for per-item connections (loops adding handlers with index), put bound args at the end of the function signature.

---

## 2026-05-03 — Transform3D 12-float constructor only works in `.tscn`, not GDScript

**What happened:** First version of `decor.gd` used `Transform3D(0.22903, 0, 0.97342, 0, 1, 0, ...)` to construct transforms. Godot crashed with "No constructor of Transform3D matches the signature (float, float, ...)".

**Root cause:** GDScript's `Transform3D` constructor accepts `(Basis, Vector3)` or `(Vector3, Vector3, Vector3, Vector3)` (4 axes), but NOT 12 floats. The 12-float syntax is only for `.tscn` text serialization.

**Rule:** In GDScript runtime code, build Transform3D from 4 Vector3:
```gdscript
Transform3D(
    Vector3(bx_x, bx_y, bx_z),
    Vector3(by_x, by_y, by_z),
    Vector3(bz_x, bz_y, bz_z),
    Vector3(ox, oy, oz)
)
```

**How to apply:** When generating Transform3D programmatically (e.g. from Python helper outputting GDScript), always emit the 4-Vector3 form. The 12-float form is only for `.tscn` files.

