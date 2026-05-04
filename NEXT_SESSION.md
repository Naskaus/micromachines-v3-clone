# NEXT SESSION — MicroNaskarV3

> **Copier-coller ce prompt en début de session pour zéro perte de contexte.**
> Last updated: 2026-05-04 (after V0.17.0-alpha + design pack v1 + multiplayer playtest)

---

## Prompt à coller

```
Je reprends le travail sur MicroNaskarV3 (clone arcade racing PS1, Godot 4.6,
deployé sur mv3.naskaus.com). État actuel: V0.17.0-alpha. Solo OK. Multiplayer
2 joueurs en réseau OK pour create/join/start MAIS 6 design gaps identifiés
2026-05-04 qui touchent à l'ADN MMV3.

Lis les 3 docs avant de toucher au code:
1. /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/CLAUDE.md
2. /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/docs/superpowers/specs/2026-05-04-mv3-multiplayer-mmv3-feel.md (LE PLAN)
3. /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/docs/superpowers/specs/2026-05-03-micronaskar-v3-design-pack.md (visuels livrés)

Le plan multiplayer attend mon GO sur 3 forks (A=authority, B=camera, C=elimination).
Lis le plan, propose un résumé 5 lignes, puis pose-moi les questions d'approbation
des Forks (§2 du plan) + les 5 questions ouvertes (§7).
```

---

## État actuel — V0.17.0-alpha (2026-05-04)

**SHIPPED depuis V0.14.3 (2026-05-03 AM):**
- V0.15.x: figure-8 6-arches checkpoint system, jump ramp, décor 270 toy items + 18 food items, audio Kenney
- V0.16.x: Web export GLES Compat (mv3.naskaus.com live), TouchInput mobile, leaderboard totem PS1, mute buttons, fullscreen toggle, bot rubber-banding fix critique
- V0.17.0-alpha: **multiplayer foundation** — Pi5 Python WSS server (port 8060, room codes 4 digits, max 6 players), Cloudflare tunnel `wss://mv3-server.naskaus.com`, autoload `network_client.gd`, scripts `multiplayer_manager.gd` + `multiplayer_menu.gd` + `ghost_car.gd`. UI lobby Create/Join/Start fonctionne. 2 joueurs peuvent rejoindre une salle et démarrer une course.

**Solo (V0.17.0-alpha):** ✅ Le feel est BON. Seb a explicitement dit "garde ces réglages pour le moment". Ne pas toucher aux constantes solo.

**Multiplayer (V0.17.0-alpha):** ⚠️ Fonctionne techniquement (réseau OK, ghosts rendus) mais 6 design gaps (voir plan).

---

## Les 6 design gaps (Seb 2026-05-04 playtest)

| # | Symptôme | Fix prévu | Phase |
|---|---|---|---|
| P1 | Pas de bots dans les rooms MP | Host envoie aussi les états des bots | 3.1 |
| P2 | Les 2 humains terminent toujours 1ers | Host = autorité ranking, broadcast race_state @ 5Hz | 3.2 |
| P3 | Chacun a sa propre vue | Shared leader-cam (seul le leader cadre) | 3.3 |
| P4 | Stragglers off-screen non éliminés | Système 3-vies + respawn back of pack | 3.3 |
| P5 | Voitures se traversent | Ghost cars deviennent CharacterBody3D + CollisionShape3D | 3.4 |
| P6 | Besoin d'un gros peloton | Auto-fill 6 cars (humains + bots) | 3.1 |

---

## Architecture multiplayer actuelle

```
Mac (Seb host)                                     Phone (peer)
  └─ Godot client                                    └─ Web build (mv3.naskaus.com)
      ├─ network_client.gd (WS client)                   ├─ network_client.gd
      ├─ race_manager.gd (LOCAL ranking)                 ├─ race_manager.gd (LOCAL ranking) ← bug P2
      ├─ multiplayer_manager.gd                          ├─ multiplayer_manager.gd
      │   └─ send local state @ 20Hz                     │   └─ send local state @ 20Hz
      │   └─ spawn ghost_car per peer ← visual only      │   └─ spawn ghost_car per peer ← visual only
      └─ camera_follow → local car (P3 bug)              └─ camera_follow → local car (P3 bug)
                ▲                                                 ▲
                └────────── WSS relay (Pi5) ─────────────────────┘
                            mv3-server.naskaus.com
                            (mv3_server.py, port 8060)
                            PURE RELAY — no auth, no physics
```

## Architecture cible (Phase 3 plan)

```
Mac (Seb HOST = AUTHORITATIVE)                     Phone (CLIENT = render only)
  └─ Godot client                                    └─ Web build
      ├─ network_client.gd                               ├─ network_client.gd
      ├─ race_manager.gd (FULL SIM)                      ├─ race_manager.gd (RENDER MODE)
      │   ├─ ranking, laps, eliminations                 │   └─ display server's race_state
      │   ├─ bots AI                                     │
      │   └─ broadcast race_state @ 5Hz                  │
      ├─ multiplayer_manager.gd                          ├─ multiplayer_manager.gd
      │   └─ send local human state @ 20Hz               │   └─ send local human state @ 20Hz
      │   └─ ALSO send all bot states @ 20Hz             │
      ├─ ghost_car.gd (PHYSICAL — CharacterBody3D)       ├─ ghost_car.gd (PHYSICAL)
      ├─ elimination_manager.gd (NEW)                    ├─ elimination_manager.gd
      │   └─ track off-screen 1.5s → -1 life → respawn   │
      └─ camera_follow → SHARED LEADER (from race_state) └─ camera_follow → SHARED LEADER
                ▲                                                 ▲
                └────────── WSS relay (Pi5) ─────────────────────┘
                            mv3-server.naskaus.com v0.18.0
                            (broadcast race_state added, still relay-only)
```

---

## Files importants

| File | LOC | Rôle | Touché par Phase 3 ? |
|---|---|---|---|
| `server/mv3_server.py` | ~130 | WSS relay | ✅ +40 LOC (race_state passthrough) |
| `src/scripts/network_client.gd` | 188 | WS autoload, signals room/peer | ✅ +30 LOC |
| `src/scripts/multiplayer_manager.gd` | 117 | Send state, spawn/update ghosts | ✅ +80 LOC (bot sync) |
| `src/scripts/race_manager.gd` | 700 | Race orchestrator (laps, ranking, leader, elimination) | ✅ +120 LOC (auth split) |
| `src/scripts/camera_follow.gd` | 87 | Multi-target chase cam (déjà support leader-cam) | ✅ +25 LOC (`is_on_screen`) |
| `src/scripts/ghost_car.gd` | 127 | Visual-only Node3D pour peers remote | ✅ +60 LOC (→ CharacterBody3D) |
| `src/scripts/car.gd` | 435 | Local human/bot RigidBody3D | ✅ +5 LOC (collision_mask) |
| `src/scripts/bot_car.gd` | 408 | AI bot path-following | (probably untouched) |
| `src/scripts/elimination_manager.gd` | — | NEW ~100 LOC | ✅ NEW |

---

## GitHub state

- **Repo:** `Naskaus/micromachines-v3-clone` PUBLIC
- **Last tag:** `v0.17.0-alpha` (2026-05-03)
- **Branch:** main, 0 ahead origin/main au moment où je rédige
- **Pi5 services:** `mv3-server.service` active, Cloudflare tunnel actif
- **Live URL game:** https://mv3.naskaus.com
- **Live URL WSS:** wss://mv3-server.naskaus.com

## Pi5 commands

```bash
# Verify WSS server status
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 "sudo systemctl status mv3-server.service"

# Tail server logs
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 "sudo journalctl -u mv3-server.service -f"

# Redeploy server after edits
scp -i ~/.ssh/id_claude_mcp server/mv3_server.py seb@100.119.245.18:/opt/mv3-server/mv3_server.py
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 "sudo systemctl restart mv3-server.service"
```

---

## Design pack v1 (livré 2026-05-03)

12 PNG sous `assets/branding/` :
- 2 logos (`logos/micronaskar_v3_logo_horizontal.png` + `_square.png`)
- 4 backgrounds (`backgrounds/bg_menu_main_16x9.png`, `bg_menu_portrait_9x16.png`, `bg_podium_results.png`, `hero_splash_keyart.png`)
- 6 helmets (`helmets/helmet_01_green.png` ... `helmet_06_purple.png`)

Pas encore intégrés in-engine. Voir doc `2026-05-03-micronaskar-v3-design-pack.md` pour code GDScript de loading.

Stack: Z-Image Turbo BF16 local sur ComfyUI 0.19.0 (port 8000, MPS M4 Max). Reproductible via `/tmp/zimage_batch.py`. Logos peuvent bénéficier d'un V2 via Gemini Nano Banana 2 quand quota free tier reset.

---

## Pitfalls Godot saved with blood (rappel V0.14.x)

1. **GLB external textures DROPPED at headless import** → fix `set_surface_override_material` + colormap atlas runtime via `_apply_colormap_to_meshes()` recursif.
2. **`Transform3D` float constructor row-major** : basis stocké en 3 ROWS, pas COLUMNS. East-facing yaw=-90° = `Transform3D(0,0,-1, 0,1,0, 1,0,0, ...)`.
3. **`class_name` registration pas fiable** → `const PathUtils = preload("res://scripts/path_utils.gd")`.
4. **`RigidBody3D.freeze=true` ne stoppe pas physics proprement** → `if freeze: return` early-return dans `_physics_process`.
5. **Magnetic pull-back forces escaladent** → kill them, use `_path_phase = PathUtils.phase_from_position(global_position)` chaque frame.
6. **Signal bind() args APPEND not prepend** : `_on_arch_entered(body, arch_idx)` pas `(arch_idx, body)`.
7. **Web export = GLES Compatibility renderer** (Forward+ ne marche pas browser).
8. **Audio = ALWAYS check mute_button.gd state before AudioStreamPlayer3D.play()**.

---

## Approval gate (Phase 3 NE PAS DÉMARRER avant ça)

**Avant tout code, Seb doit valider:**

1. **Fork A — Authority model:** A1 (host-authoritative) recommandé. Alternatives A2 (server) et A3 (lock-step relay) listées dans le plan §2.
2. **Fork B — Camera in MP:** B1 (shared leader-cam) recommandé. Alternatives B2 (split view, status quo) et B3 (multi-target zoom) listées.
3. **Fork C — Elimination penalty:** C1 (3 lives + respawn back of pack) recommandé. Alternatives C2 (perma-elim) et C3 (no penalty) listées.
4. **5 questions ouvertes §7 du plan:** lives count, elimination semantics, bot auto-fill, host advantage warning, mobile UX.

Une fois validé → invoque `superpowers:executing-plans` sur le plan.
