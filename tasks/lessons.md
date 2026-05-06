# Lessons — Micromachines V3 Clone

Hard-won knowledge. Add new entries on top.

## 2026-05-06 — `Node3D` n'a PAS de propriété `modulate`

**What happened:** Phase 3 implementation, `ghost_car.gd` héritait de `CharacterBody3D` (donc Node3D). J'ai écrit `modulate = Color(0.5, 0.5, 0.5, 0.5)` pour le mode spectateur. Godot crashed au parse: `Identifier "modulate" not declared in the current scope`.

**Root cause:** `modulate` est une propriété de `CanvasItem` (Control / Node2D). Les nœuds 3D héritent de `Node3D`, pas de `CanvasItem`, donc pas de modulate.

**Rule:** Pour grey-out / dimmer / teinter un Node3D, modifier les **materials** des `MeshInstance3D` enfants directement (`set_surface_override_material(i, mat)` avec `albedo_color` et `emission_energy_multiplier` ajustés). Pas `modulate`.

**How to apply:** Dès qu'un effet visuel "darken" ou "alpha" est requis sur du 3D, écrire un helper `_apply_X_tint(node, on)` qui descend récursivement le node tree et patche les materials. C'est exactement le pattern de `ghost_car._apply_spectator_tint()`.

---

## 2026-05-06 — Ne JAMAIS escalader `collision_layer` sans vérifier les `Area3D` mask

**What happened:** Phase 3 voulait collisions physiques entre cars au figure-8 crossing. J'ai mis `collision_layer = 2` et `mask = 1 | 2` sur `car.gd`, `bot_car.gd` et `ghost_car.gd`. Smoke test passé (Godot parse 0 erreurs). Web build deployé. Seb playtest: « Solo : booster marche plus ». Le `BoostPad` (Area3D) avait son `collision_mask` par défaut à layer 1 — il ne voyait plus les cars passées sur layer 2.

**Root cause:** Les `Area3D` ont leur propre `collision_mask` qui définit quelles **layers** ils monitorent. Changer la `collision_layer` d'une car la fait disparaître pour toute Area3D qui ne mask que la layer d'origine. Le passage en `CharacterBody3D` pour `ghost_car` (vs Node3D) suffisait pour le crossing collision — pas besoin d'escalader la layer.

**Rule:** **Ne JAMAIS changer `collision_layer` par défaut (1) sans auditer toutes les `Area3D` du projet** (BoostPad, FinishLine, checkpoints, pickups). Si on doit séparer des couches (ex. cars = layer 2), il FAUT mettre à jour les masks de chaque Area3D qui doit continuer à les voir.

**How to apply:** Avant de toucher à `collision_layer` ou `collision_mask`, faire `grep -rn "extends Area3D"` pour lister toutes les Area3D du projet, et vérifier chaque mask. Sinon: garder layer 1 partout (RigidBody3D / CharacterBody3D collisionnent quand même entre eux sur la même layer).

---

## 2026-05-06 — `_check_eliminations()` distance-based ≠ MMV3 feel

**What happened:** Le V0.6 avait ajouté `ELIMINATION_DIST_FROM_LEADER = 120m` dans `race_manager._check_eliminations()` pour virer les stragglers. Phase 3 a ajouté `elimination_manager.gd` (MP off-screen elim). Seb playtest solo: « à la fin de la course il reste plus que moi et le premier. Tous les autres sont out. Il faudrait essayer de garder le peloton, c'est plus marrant ». La distance 120m est trop courte pour un figure-8 de 200m+ avec rubber-banding agressif.

**Root cause:** L'élimination par distance est un héritage TrackMania, pas MMV3. MMV3 garde le peloton serré via la leader-cam partagée + élim off-screen *seulement quand un joueur tombe vraiment hors-écran*. La règle 120m flat éliminait des bots qui faisaient simplement un tour de retard normal.

**Rule:** En **solo**, le peloton doit rester intact toute la course. Le `POST_FIRST_FINISH_TIMEOUT 18s` cut quand même quand le 1er a fini. Pas besoin d'élimination distance solo. En **MP**, l'élimination off-screen est opt-in via le toggle lobby (3 vies / perma).

**How to apply:** Quand Seb dit "plus marrant" / "garder X", c'est une feature design lock — ne pas supprimer ou ré-introduire X dans une refonte future sans sa validation explicite. Le solo feel a été lockée 2026-05-04 (« garde ces réglages pour le moment »).

---

## 2026-05-06 — Smoke test du protocole ≠ playtest réel

**What happened:** Phase 3 multi shippé en v0.19.0-rc1. WSS smoke test Python avec uv websockets PASSED (create / join / set_options / register_bot / start / state forward / race_state @ 5Hz / elim_event). Godot parse: 0 erreurs. Web build HTTP 200 sur mv3.naskaus.com. Rapport FR + Telegram envoyés. Seb playtest: « MULTI tous les problèmes soulevés sont toujours présents. Pas de bots, pas de cam commune, pas d'élimination. Boosters marchent en desktop pas mobile ». 4 régressions critiques côté gameplay malgré tous les tests verts.

**Root cause:** Le smoke test WSS validait le **protocole serveur** (messages bien échangés), pas le **gameplay client** (visuels, états, collisions, contrôles). Les bugs étaient :
1. `_state_runs_locally = host` → le host gardait sa cam locale au lieu du leader-cam partagé
2. Bots non rendus côté peer (probable timing du race_start_signal)
3. `collision_layer = 2` cassait BoostPad

Aucun de ces 3 ne se voit en smoke test serveur. Seul le playtest réel (Mac + phone, 2 instances Godot) les révèle.

**Rule:** **Pour toute feature qui touche au rendu/contrôles/physique, le smoke test du protocole + parse Godot ne suffisent jamais.** Il faut soit (a) lancer 2 instances Godot localement et tester en split-screen, soit (b) être explicite avec Seb : *« code shippé, smoke OK, mais playtest réel = ton job »* et NE PAS dire « tout shippé avec succès » dans le rapport.

**How to apply:** Avant de générer le rapport final d'une session multiplayer/UI/physique :
1. Si Godot 2-instance test possible localement → faire le test
2. Sinon → le rapport doit dire explicitement *« smoke test ≠ gameplay test »* et lister précisément ce qui n'a PAS été vérifié
3. Ne jamais marquer "SHIPPED" sans avoir vu la feature fonctionner soit chez moi, soit confirmation Seb

---

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

