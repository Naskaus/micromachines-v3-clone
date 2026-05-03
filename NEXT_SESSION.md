# NEXT SESSION — Prompt pour reprendre

> **Copier-coller ce prompt en début de session pour zéro perte de contexte.**

---

## Contexte projet

Tu travailles sur **Micromachines V3 Clone** — un clone arcade racing dans Godot 4.6 inspiré de Micro Machines V3 PS1.

**Path** : `/Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/`
**Engine** : Godot 4.6 (binary `/Applications/Godot.app` symlink → `~/Downloads/06_Installers_DMG/Godot.app`)
**MCP actif** : `godot-mcp` (run_project, stop_project, get_debug_output, get_godot_version, get_project_info)
**Git** : repo local committed up to v0.15.0 — pas encore pushé sur GitHub
**User** : Sebastien (FR), itère vite, donne feedback court → pousse à shipper sans surengineering

## État actuel — V0.15.0 (2026-05-03)

**Ce qui marche** :
- 6 racers (P1, P2 + 4 bots) avec modèles Kenney `.glb` colorés
- Track **figure-8** (2 ovales tangents au crossing z=0) avec shader pool felt + lignes blanches
- **4 arches checkpoint** colorées (vert/jaune/orange/rouge) placées en racing order :
  - Arch 1 (vert/start) : phase 0.97 → world (-37, 4, +3.5) — west of crossing
  - Arch 2 (jaune) : phase 0.25 → world (0, 4, -100) — top extremity
  - Arch 3 (orange) : phase 0.53 → world (+37, 4, +3.5) — east of crossing
  - Arch 4 (rouge) : phase 0.75 → world (0, 4, +100) — bottom extremity
- **Lap validation** : `next_arch_index` (0..3). Racer doit passer arch 0 → 1 → 2 → 3 dans l'ordre. Skip une arche → la suivante ignorée. Hit arch 3 → lap += 1, reset à 0.
- **Spawn 6 cars** en grid 3 rows × 2 cols, en arrière de Arch 1 (phases 0.96 / 0.93 / 0.90 sur le bottom oval), tangent-aligned, ±3m perpendiculaire. Plus de spawn DANS un checkpoint area.
- **Ranking** : `laps + next_arch_index*0.25 + phase*0.001` — granularité fine, défait les cheaters qui tournent en rond.
- AI bots suivent le path, catch-up rubber-banding, boost pads × 4, drift smoke + boost flame trail
- Speedometer + minimap, camera shake on boost+collision, 1P/2P selector, eliminated cars vanish

**Code review du V0.15.0** : APPROVED_WITH_NITS (`bridge_y` math pure, signature signal `_on_arch_entered(body, arch_idx)` corrigée après bug initial).

## Reportés à V0.15.1+ (math complexe)

**Bridge 3D au crossing** : `path_utils.gd::bridge_y()` est en place (sinusoide 0→5→0 sur fenêtre [0.95, 0.05]), MAIS :
1. Discontinuité Y à phase=1.0/0.0 (appliqué seulement sur top oval) — fix : appliquer aussi sur bottom oval
2. Phase ≠ proximité au crossing : phase=0.95 = world (-58, 0, +9.5), pas adjacent au crossing → géométrie pont droite ne suit pas le racing line courbe
3. Crossing = tangent (les 2 strands vont EST), pas un X-crossing comme un vrai ∞

**3 options pour V0.15.1** (à discuter avec Seb avant de coder) :
- A. Resserrer fenêtre `[0.99, 0.01]` (~25m total), pont droit sur ce span. Visuel = highway stacké est-est, pas X-crossing.
- B. Redesign path_utils → ovaux qui se chevauchent (centres à ±40 au lieu de ±50). Vrai ∞ avec X-crossing à 60°. Touche tout : path_utils, race_manager, bot_car, minimap.
- C. Lemniscate de Bernoulli (`r²=2a²cos(2θ)`). Courbe ∞ pure. Réécriture totale du path system.

**Bot Y tracking sur le pont** : à câbler dans `bot_car.gd::_physics_process` (P-controller force vers `path_at(phase).y + 0.5` quand y > 0.5). Reporté car bridge geometry pas encore décidée.

## Pitfalls Godot critiques (saved with blood)

1. **GLB external textures DROPPED at headless import** : Kenney `colormap.png` référencé en chemin relatif → Godot le perd. Fix : `set_surface_override_material` au runtime via `_apply_colormap_to_meshes()` (voir `car.gd` / `bot_car.gd`).
2. **Transform3D float constructor ROW-MAJOR** : 9 floats en row-major (xx,yx,zx, xy,yy,zy, xz,yz,zz). East-facing yaw=-90° = `Transform3D(0,0,-1, 0,1,0, 1,0,0, ox,oy,oz)`.
3. **`class_name` registration unreliable** : ne s'enregistre pas toujours avant compilation des autres scripts. Fix : `const PathUtils = preload("res://scripts/path_utils.gd")` partout.
4. **`RigidBody3D.freeze=true` ne stoppe pas physics proprement** : early-return `if freeze: return` au top de chaque `_physics_process` pour cars/bots.
5. **Magnetic pull-back catapulte** : `apply_central_force(direction * magnitude * mass)` escalade vite — supprimé V0.14.2.
6. **Signal bind() args APPEND, not prepend** : `arch.body_entered.connect(_on_arch_entered.bind(i))` envoie `(body, i)` à la callable, pas `(i, body)`. Signature : `func _on_arch_entered(body: Node, arch_idx: int)`.

## Workflow

À chaque modif :
1. `mcp__godot-mcp__stop_project` puis `run_project` puis `get_debug_output`
2. Vérifier 0 errors avant de commit
3. `git add -A && git commit -m "vX.Y.Z: description"`
4. Phrasing FR court à Seb : "Fait X, ça change Y, va tester"

## Règle Seb

- **Ship vite, itère vite** — petits commits incrementaux
- **Vérifier visuellement** quand possible (debug prints, screenshots si dispo)
- **Ne pas prétendre que c'est fait** sans vérification
- **0 erreur Godot** avant chaque ship
- **Toujours commit avant de quitter**

## Constants importants

- `PathUtils.OVAL_A = 100.0`, `OVAL_B = 50.0`, `OVAL_H = 50.0`
- `PATH_PERIMETER ≈ 471 m`
- `BRIDGE_PHASE_START = 0.95`, `BRIDGE_PHASE_END = 0.05`, `BRIDGE_HEIGHT = 5.0` (dormant — wired top branch only, pas utilisé encore)
- `TOTAL_LAPS = 3`, `MIN_LAP_TIME = 4.0` s, `ELIMINATION_DIST_FROM_LEADER = 120.0` m
- `TOP_SPEED = 42 m/s`, `ACCEL = 20 m/s²`
- `boost_pad`: factor=1.75, duration=1.2s
- `PLAYER_RUBBER_MAX = 0.80`, `RUBBER_MAX = 0.50` (bot vs P1)

## Fichiers clés

```
src/
├── project.godot
├── scripts/
│   ├── path_utils.gd          # Figure-8 math + bridge_y() (dormant)
│   ├── car.gd                  # Player car
│   ├── bot_car.gd              # AI bot
│   ├── race_manager.gd         # 4-arch ordered validation
│   ├── camera_follow.gd        # Multi-target camera + shake
│   ├── minimap.gd              # Figure-8 minimap
│   └── boost_pad.gd            # Area3D trigger
├── scenes/
│   ├── Main.tscn               # 6 cars (new spawn grid) + RaceManager wired with arch_paths
│   ├── Car.tscn / BotCar.tscn  # RigidBody3D + PhysicsMaterial(friction=0)
│   └── Track01.tscn            # Floor + walls + 4 arches (Arch_1..Arch_4) + 4 boost pads
└── assets/
    ├── pool_felt.gdshader      # Felt + figure-8 chalk lines
    ├── cars/                   # 49 Kenney car .glb + Textures/colormap.png
    └── track_pieces/           # 90+ Kenney racing-kit .glb
```

## Git history (récent)

```
v0.15.0    : 4 arches + ranking refactor + spawn grid (4 commits squashable, ou tagged on 452f551+)
v0.14.3-baseline : safety net tag avant V0.15.0 (= dac2b4d)
v0.14.3-handoff → v0.14.3 (2-checkpoint validation) → v0.14.2 (kill magnetic pull) → v0.14.1 → v0.14 (figure-8) → v0.13.x (Kenney) → v0.12 → v0.10.x → v0.9.x
```

## TODO

- [x] V0.15.0 : 4 arches + ranking + spawn fix (DONE 2026-05-03)
- [ ] V0.15.1 : décider A/B/C bridge geometry + l'implémenter
- [ ] V0.15.2 : remplacer arches box-mesh par Kenney `overhead.glb` + bannerTowerRed
- [ ] V0.15.3 : décorations Kenney (~30-50 .glb procédural autour du circuit)
- [ ] Push GitHub : `gh repo create Naskaus/micromachines-v3-clone --private --source=. --push`
- [ ] V0.16+ : MMV3-style tracks (pool table cards, garden, picnic plaid — voir `docs/inspiration/mmv3-references.md`)
- [ ] V0.17+ : sound

## Mémoire associée

- `~/.claude/projects/-Users-bpia-Documents-Seb-Coding-naskaus-lab/memory/projects/micromachines-v3-clone.md`
- `~/.claude/projects/-Users-bpia-Documents-Seb-Coding-naskaus-lab/memory/feedback/godot-game-iteration.md`
- `docs/superpowers/plans/2026-05-03-figure-infinity-bridge-arches.md` (plan original V0.15.0, partiellement exécuté — bridge tasks 3+6 reportées)
- `docs/inspiration/mmv3-references.md` (7 screenshots MMV3 PS1 + analyse design)

## Prompt à coller en début de session

```
Reprise de Micromachines V3 Clone (V0.15.0 → V0.15.1).
Lis NEXT_SESSION.md à la racine du projet pour le contexte.
Path : /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/
Priority 1 : décider option A/B/C pour le bridge 3D au crossing puis l'implémenter (voir section "Reportés à V0.15.1+").
Vérifie git log + état avant de coder. Workflow : stop_project → edit → run_project → get_debug_output → 0 errors → git commit vX.Y.Z → terse FR update.
```
