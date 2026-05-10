# Track Creator — Arch-Based Freestyle (V1)

**Date** : 2026-05-10
**Status** : Design approved, awaiting implementation plan
**Replaces** : `2026-05-06-3-new-circuits-and-powerups.md` (Phase 4 spec — paramétrique + power-ups, abandonnée)

## Vision

Le créateur de circuit n'est PAS un outil custom. **Godot Editor IS l'éditeur.** Seb duplique une scène, place des `ArchMarker` numérotés et du décor à l'œil dans le viewport 3D, F6 pour tester. Claude (LLM) assiste via `godot-mcp` pour générer/déplacer des nœuds en langage naturel.

**Mécanisme de course** : pas de path préd-défini, pas de spline, pas de phase. **N arches numérotées dans un ordre = le circuit.** La voiture passe dans Arch_1, puis Arch_2, etc., en boucle (3 tours). Si elle rate une arche, le compteur n'avance pas → demi-tour obligatoire. Pas de murs, pas de respawn — le scoring force l'ordre.

## Décisions verrouillées

| Q | Réponse |
|---|---|
| Géométrie du track | **Aucune** — c'est l'ordre des arches qui définit la course. Sol = simple plan/mesh décoratif. |
| Murs / respawn | **Aucun mur, aucun respawn.** Si arche ratée → compteur n'incrémente pas, demi-tour. |
| Arches min/max | **2 ≤ N ≤ 10** par circuit |
| Arche bidirectionnelle | **OK** — la voiture valide quel que soit le sens de traversée tant que c'est l'arche attendue |
| Taille zone arche | **8m × 4m** (généreux, MMV3-style) |
| HUD prochaine arche | Existant gardé (`→ Prochaine : VERTE` + glow x4 sur la prochaine du player) |
| Spawn | Un nœud `Spawn` placé en 3D, code génère 6 positions auto en grille 2×3 derrière, orienté vers Arch_1 |
| Boost pads + ramps | Nœuds 3D placés librement dans le viewport (plus de phases) |
| Power-ups | **NON en V1** (reportés V2) |
| Multi (Phase 3) | **Live mais sleep** — bouton actif limité aux tracks officielles, custom tracks = solo only V1 |
| V1 scope (β) | Moteur arch-based + `Track_Pool_Felt.tscn` rebuild + `Track_Workshop.tscn` nouveau (à 4 mains) |

## Architecture

### Structure de toute Track_<X>.tscn

```
Track_Workshop.tscn (Node3D root, script: track_scene.gd)
├── Floor             # MeshInstance3D — sol customisable (texture, taille)
├── Spawn             # Node3D — position+rotation grille départ (orienté vers Arch_1)
├── Arches            # Node3D parent
│   ├── Arch_1        # Node3D + child MeshInstance3D (visuel) + Area3D 8m×4m (détection)
│   ├── Arch_2
│   ├── ...
│   └── Arch_N        # 2 ≤ N ≤ 10
├── BoostPads         # Node3D parent — drops de BoostPad.tscn placés librement
├── Ramps             # Node3D parent — drops de Ramp.tscn placés librement
└── Decor             # Node3D parent — tout MeshInstance3D ici devient du décor non-collidable
```

### Scripts

| Fichier | Rôle | LOC estimé |
|---|---|---|
| `track_scene.gd` | **NEW** — orchestrateur attaché au root de chaque Track_<X>.tscn. Énumère children, broadcast au race_manager via signal `track_ready` | +200 |
| `arch_marker.gd` | **NEW** — script attaché à chaque Arch_*. Area3D + visuel + signal `car_passed(car, arch_index)` | +60 |
| `path_utils.gd` | **DELETE** | -84 |
| `circuit_loader.gd` + `circuits/*.json` | **DELETE** (remplacés par .tscn) | -89 |
| `race_manager.gd` | Refactor : retire phase logic, intègre arch validation, leader resolution via arches_passed | -200 / +150 |
| `bot_car.gd` | Refactor : steer-toward-next-arch au lieu de path-following | -100 / +80 |
| `camera_follow.gd` | Adjust : leader = car avec `arches_passed × 10000 + 1/dist_to_next` | -30 / +30 |
| `boost_pad.gd` | Tweak : retire phase, garde 100% spatial | -20 / +5 |

**Bilan LOC** : ~-393 supprimées, ~+525 ajoutées = **+132 nettes** (codebase plus lisible).

## Data flow (une course, du clic à l'arrivée)

1. Menu solo → "Choose track" → liste auto des `res://scenes/tracks/Track_*.tscn`
2. Player picks `Track_Workshop.tscn` → `get_tree().change_scene_to_file()`
3. `track_scene.gd._ready()` :
   - Collecte `Arches/Arch_*` triés par name (Arch_1, Arch_2, ...)
   - Calcule 6 spawn slots autour de Spawn (grille 2×3, orientée vers Arch_1)
   - Énumère BoostPads/Ramps/Decor
   - Émet signal `track_ready(arches_ordered, spawn_slots, boost_pads, ramps)`
4. `race_manager` reçoit le signal, attribue à chaque car `next_arch_index = 0` (= Arch_1)
5. Loop :
   - `Arch_i.Area3D` détecte `body_entered(car)` → émet `car_passed(car, i)`
   - `track_scene` filtre : `car.next_arch_index == i` ?
     - **OUI** → `car.next_arch_index = (i + 1) % N`, `car.arches_passed += 1`
     - **NON** → silently ignored
   - Si `car.arches_passed == N × LAPS (3)` → `car.finished = true`
6. Camera follow leader = `argmax(car.arches_passed × 10000 + 1.0 / dist_to_next_arch)`
7. Bot AI : `steer_toward(arches_ordered[next_arch_index].global_position)` avec rubber-band existant

## Multi (Phase 3) — compatibilité

Le multi reste live (`v0.19.2-rc1` sur mv3.naskaus.com + server Pi5) **avec une condition** : aujourd'hui les 6 arches sont hardcoded dans `mv3_server.py`. Pour V1 :

- Le bouton "Create Room" / "Join Room" reste actif
- Liste de tracks limitée aux tracks officielles (Pool Felt + Workshop) en V1
- Le host envoie `track_id: "pool_felt" | "workshop"` dans le `register_player` message
- Le server load la même `arches_ordered` côté serveur (mock authoritative bookkeeper)
- Custom tracks (créées par Seb après V1) = solo only jusqu'à V1.5

V1.5 (futur) : sérialiser `arches_ordered` (positions Vec3) dans le init message → server valide générique. Hors scope V1.

## V1 deliverables

1. ✅ `track_scene.gd` + `arch_marker.gd` + scaffolding
2. ✅ Refactor `race_manager.gd` + `bot_car.gd` + `camera_follow.gd` solo
3. ✅ `Track_Pool_Felt.tscn` (rebuild de Track01 en arch-based, parité gameplay validée)
4. ✅ `Track_Workshop.tscn` (nouveau circuit fait à 4 mains, ~30 nœuds Kenney workshop pack)
5. ✅ Track picker dans le menu solo
6. ✅ Multi en sleep (bouton actif limité aux tracks officielles)
7. ✅ Tag `v0.20.0-rc1`, deploy mv3.naskaus.com

## Hors scope V1 (V2+)

- Power-ups (boost can, oil slick, mine, sugar rush, etc.)
- Petit-déj + Bathroom circuits
- Track picker for custom tracks in multi mode
- Editor in-game UI (drag arches via touch on phone) — pas demandé

## Estimation

**2-3 sessions Claude.** Pas de blockers techniques connus. Le plus gros risque : refactor `race_manager.gd` (811 LOC) sans casser le flow existant — mitigé par le fait que `Track_Pool_Felt.tscn` doit avoir parité gameplay avec Track01 actuel (test de non-régression).

## Pitfalls Godot connus (rappel)

1. `Node3D` n'a pas `modulate` — utiliser materials
2. `RigidBody3D.collision_layer = 1` par défaut, ne PAS changer (BoostPad mask=1)
3. Web export = GLES Compatibility renderer obligatoire
4. Manual `.tscn` editing = risqué, préférer godot-mcp pour les modifs structurelles
5. `RigidBody3D.freeze = true` ne stoppe pas physics → `if freeze: return` early-return
6. GLB external textures DROPPED at headless import → material_override runtime
