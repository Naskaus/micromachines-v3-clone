# NEXT SESSION — Prompt pour reprendre

> **Copier-coller ce prompt en début de session pour zéro perte de contexte.**

---

## Contexte projet

Tu travailles sur **Micromachines V3 Clone** — un clone arcade racing dans Godot 4.6 inspiré de Micro Machines V3 PS1.

**Path** : `/Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/`
**Engine** : Godot 4.6 (binary `/Applications/Godot.app` symlink → `~/Downloads/06_Installers_DMG/Godot.app`)
**MCP actif** : `godot-mcp` (run_project, stop_project, get_debug_output, get_godot_version, get_project_info)
**Git** : repo local committed up to v0.14.3 — pas encore pushé sur GitHub
**User** : Sebastien (FR), itère vite, donne feedback court → pousse à shipper sans surengineering

## État actuel — V0.14.3

**Ce qui marche** :
- 6 racers (P1, P2 + 4 bots) avec **vrais modèles Kenney `.glb`** colorés (race, sedan-sports, hatchback-sports, kart-oobi, tractor, race-future)
- Track **figure-8** (2 ovales tangents au crossing z=0) avec shader pool felt + lignes blanches
- AI bots suivent le path via `PathUtils.path_at(phase)`, phase dérivée de la position chaque frame
- Catch-up rubber-banding (player +80% max, bots ±50%)
- Boost pads × 4 (snap factor 1.75, fire trail particles)
- Drift smoke + boost flame trail (CPUParticles3D programmatic)
- Speedometer + minimap (figure-8 outline)
- Camera shake on boost + collision impact (player only)
- 1P/2P selector, race rules, results screen, restart [BACKSPACE]
- Eliminated cars vanish (visible=false + collision disabled)
- Off-track 50% speed malus

**Le BUG critique à fixer en priorité — checkpoints figure-8** :
J'ai mis 2 checkpoints (TopCheckpoint à z=-100 / BotCheckpoint à z=+100) pour valider le sens de la figure-8. **Mais ils sont mal positionnés / mal orientés** :
- Cars spawn à (x=0..15, z=-100, facing west) qui est PILE sur la TopCheckpoint area
- À l'instant du `body_entered`, l'event ne fire pas (car spawn dedans, pas d'entrée)
- Cars cheaters qui restent sur top oval visitent TopCheckpoint plusieurs fois mais le ranking ne reflète pas correctement
- Ranking via `_racer_progress = laps + segment * 0.5 + phase * 0.01` est trop coarse → les positions sont fausses

**Ce qu'il faut faire** :
1. **Plus de checkpoints** (4 ou 6 répartis sur le figure-8) pour bien forcer le sens
2. **Mieux les indiquer visuellement** : pylons jaunes Kenney, flèches au sol, banner arches Kenney
3. **Spawner les cars HORS des checkpoints** (au crossing à z=0 par exemple, facing east → drive into top oval)
4. **Track le checkpoint INDEX** (le racer doit passer 0, 1, 2, 3, 0 dans l'ordre pour valider un tour)

## Roadmap immédiate

**V0.14.4 (next)** : Fix checkpoints figure-8
- Spawn cars au crossing (0, 0, 0) facing east, initial_path_phase = 0
- 4 checkpoints in order : NORTH_TOP (0, -100), CROSSING (0, 0), SOUTH_BOT (0, +100), CROSSING (0, 0)
- Wait, crossing visited 2× per lap → use 4 distinct waypoints :
  - WP1 : top of top oval (0, -100)
  - WP2 : crossing entering bottom (0, 0) going east → discriminate by direction or use slight offset
  - WP3 : bottom of bottom oval (0, +100)
  - WP4 : crossing entering top (0, 0) going west → discriminate similarly
- Ou plus simple : use `_path_phase` derived position + monotonic counter, count lap when racer crosses 4 phase quadrants in order (0 → 0.25 → 0.5 → 0.75 → 0)
- **Indication visuelle** des checkpoints : Kenney `flagCheckers.glb` ou `bannerTowerRed.glb` au-dessus de chaque

**V0.14.5** : Bridge au crossing
- Procédural ramp + plateau + ramp Y=5 au-dessus du crossing
- Path Y component non-zero pour la deuxième traversée → cars passent par-dessus
- Bridge geometry : 3 boxes inclinées

**V0.14.6** : Décorations Kenney
- Path `src/assets/track_pieces/` contient ~90 .glb : `bannerTowerGreen`, `bannerTowerRed`, `barrierWhite`, `barrierRed`, `fenceStraight`, `fenceCurved`, `treeLarge`, `treeSmall`, `grandStand`, `lightPostLarge`, `pylon`, `flagCheckers`, etc.
- Place 30-50 décorations procéduralement autour du figure-8 → effet "vrai circuit"

**V0.15+** : Voir BRIEF.md / PROJECT.md / brainstorming.md du projet

## Fichiers clés

```
src/
├── project.godot                  # Godot config + 8 input actions
├── scripts/
│   ├── path_utils.gd              # PathUtils — figure-8 math (path_at, tangent_at, phase_from_position)
│   ├── car.gd                     # Player car — uses PathUtils, _path_phase from position
│   ├── bot_car.gd                 # AI bot — uses PathUtils, no magnetic pull (catapulte killer)
│   ├── race_manager.gd            # Race state machine + checkpoint lap detection
│   ├── camera_follow.gd           # Multi-target camera with shake
│   ├── minimap.gd                 # Figure-8 minimap
│   └── boost_pad.gd               # Area3D trigger
├── scenes/
│   ├── Main.tscn                  # Cars, camera, HUD, RaceManager wiring
│   ├── Car.tscn / BotCar.tscn     # RigidBody3D + PhysicsMaterial(friction=0)
│   └── Track01.tscn               # Floor + walls + 2 checkpoints + 4 boost pads
└── assets/
    ├── pool_felt.gdshader         # Felt + figure-8 chalk lines
    ├── cars/                      # 49 Kenney car .glb + Textures/colormap.png
    └── track_pieces/              # 90+ Kenney racing-kit .glb (banners, fences, etc.)
```

## Constants importants

- `PathUtils.OVAL_A = 100.0`, `OVAL_B = 50.0`, `OVAL_H = 50.0` (figure-8 dims)
- `PATH_PERIMETER = 471.2` (~2 ovals)
- `TOP_SPEED = 42.0` m/s, `ACCEL = 20.0` m/s², `STEER_TOP_LOSS = 0.15`
- `boost_pad`: factor=1.75, duration=1.2s, snaps velocity instantly
- `PLAYER_RUBBER_MAX = 0.80`, `FULL_GAP = 0.10`
- `RUBBER_MAX = 0.50` (bot vs P1), `DEAD_ZONE = 0.02` rad
- `ELIMINATION_DIST_FROM_LEADER = 120.0` m

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

## Ce qui reste à faire URGENT

1. ⚠️ **Fix checkpoints figure-8** (V0.14.4) — actuellement bug : ranking faux, cheaters peuvent gagner OU le sens n'est pas validé
2. Push sur GitHub (`gh repo create Naskaus/micromachines-v3-clone --private --source=. --push`)
3. V0.14.5 : bridge au crossing
4. V0.14.6 : décorations Kenney

## Prompt à coller en début de session

```
Reprise de Micromachines V3 Clone (V0.14.3 → V0.14.4).
Lis NEXT_SESSION.md à la racine du projet pour le contexte.
Path : /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/
Priority 1 : fixer le bug des checkpoints figure-8 (mauvais sens, mauvais positionnement).
Vérifie git log + état avant de coder.
```
