# MV3 Multiplayer — MMV3 Feel Plan (Phase 3)

> **Status:** Plan only. No code written. Approved scope from Seb 2026-05-04.
> **Predecessor:** V0.17.0-alpha multiplayer foundation (room create/join/start, ghost cars, peer state @ 20Hz).
> **Goal:** Bring online multiplayer up to the iconic Micro Machines V3 (PS1 1997) feel.

---

## 1. Problems observed (Seb's 2026-05-04 playtest)

Solo race feel = 👍 **DO NOT TOUCH SOLO PARAMS.** All the issues below are *multiplayer-only*.

| # | Symptom | Root cause |
|---|---------|------------|
| **P1** | Only the 2 humans race — no bots, no peloton | `multiplayer_manager.gd` spawns ghost cars only for human peers; the host's `bot_paths` aren't synced to remote clients. |
| **P2** | Both humans always finish 1st | Each client runs its OWN `race_manager.gd` and only registers its OWN car as a "racer" + ghost cars are visual-only. No authority on ranking → both clients believe they're the leader. |
| **P3** | Each player has their own chase cam | `camera_follow.gd` set_leader_target(local_car) on each client. The iconic MMV3 single shared "leader cam" mechanic is not active in MP. |
| **P4** | Stragglers don't get eliminated when they fall off-screen | Only the `ELIMINATION_DIST_FROM_LEADER = 120m` rule exists, but it's evaluated against the local client's leader (which is always the local car in MP), so it never triggers. |
| **P5** | Cars pass through each other (no contact) | `ghost_car.gd` is pure visual `Node3D` — no `CollisionShape3D`, no `RigidBody3D`/`StaticBody3D`. The local human's `RigidBody3D` car has no body to collide with. |
| **P6** | Need a big peloton (8-12 cars) for that "Hot Wheels chaos" feel | Currently MP grid = 1 local + N ghosts. Bots need to be added on top. |

---

## 2. Design decisions (the 3 forks Seb needs to validate before coding)

### Fork A — Authority model

**Question:** Who decides "where is each car / who is leading / who is eliminated"?

| Option | Description | Pros | Cons | Reco |
|---|---|---|---|---|
| **A1. Host-authoritative** | Host runs the full simulation (bots, physics, ranking). Clients send only their *input* (steer, boost). Host broadcasts world state @ 20Hz. | True MMV3 feel. Host's bots = real. Ranking trustworthy. | Host gets advantage (zero latency). Host disconnect kills the room. ~3 days work. | ✅ |
| **A2. Server-authoritative** | Rewrite `mv3_server.py` from relay to game server (Python physics or just bookkeeping). | Fair to all players. Survives host disconnect. | 5-7 days work. Pi5 might struggle with physics @ 20Hz × N cars. | Phase 4 |
| **A3. Stay relay + lock-step ranking** | Keep relay server. Each client runs the same physics deterministically. Use commit/reveal protocol for ranking. | Lightweight. | Determinism in Godot 4 is hard. Floating-point divergence kills it. | ❌ |

**Reco: A1 (host-authoritative)** — best feel/cost ratio. Phase 4 can promote to A2 if the game scales.

### Fork B — Camera in multiplayer

**Question:** What does the camera show during a 2-6 player online race?

| Option | Description | Pros | Cons | Reco |
|---|---|---|---|---|
| **B1. Pure shared leader-cam** | Both clients show the SAME view: a single chase cam following the current race leader. Same camera_follow.gd already supports this in solo. | Authentic MMV3 feel. Triggers the "hold the leader position or get eliminated" tension. | Some players will hate not seeing their own car when they're last (which is the point). | ✅ |
| **B2. Split view** | Each client sees its own car (current behaviour). | Comfortable. | Not MMV3. P4 elimination cannot work. | ❌ |
| **B3. Shared multi-target zoom-out** | Camera frames ALL cars (`set_targets_to(all_cars)`), zooms out adaptively (already implemented in camera_follow.gd lines 60-87). | All cars visible always. | Cars become tiny. Loses MMV3 tension because nobody falls off. | Demo-mode only |

**Reco: B1 (shared leader-cam)** — this is the MMV3 DNA. The friction it creates (last player can't see themselves) IS the gameplay loop.

### Fork C — Off-screen elimination penalty

**Question:** What happens to a player whose car falls off-screen?

| Option | Description | Pros | Cons | Reco |
|---|---|---|---|---|
| **C1. Respawn at back of pack, -1 life** | After 1.5s off-screen, car is teleported behind the last visible car, player loses 1 of 3 lives. 0 lives = eliminated. | True MMV3 (3-lives system). Allows comebacks. | Need life UI. | ✅ |
| **C2. Permanent elimination on first off-screen** | One mistake = out. | Brutal. Short games. | Frustrating for casuals. | ❌ |
| **C3. Soft respawn, no penalty** | Just teleport back, no lives lost. | Forgiving. | Removes tension. | ❌ |

**Reco: C1 (3 lives)** — exactly how MMV3 works.

---

## 3. Implementation phases

Total estimated effort: **~3-4 sessions of focused work** (host-authoritative pivot is the heaviest).

### Phase 3.1 — Bots in MP rooms (1 session)
**Depends on:** Fork A1 host-authoritative decision.

Changes:
- `mv3_server.py` v0.18.0: add a `"role"` field to `joined`/`player_joined` messages (`"human"` or `"bot"`).
- `multiplayer_manager.gd`: when this client is host, also send bot states (one MultiplayerManager._send_bot_state() loop per local bot, with synthetic `player_id` like `-1, -2, -3, -4`).
- `multiplayer_manager.gd` (client-side): treat `peer_state` from `player_id < 0` as a bot peer → spawn ghost car with bot color set.
- Race grid: when host creates room, auto-fill peloton up to 6 cars with bots (e.g. 2 humans + 4 bots).

**Deliverable:** Both players see the full peloton (humans + bots) racing in lockstep. Host's bots appear as ghost cars on the client.

### Phase 3.2 — Authoritative ranking + race state sync (1 session)
**Depends on:** Phase 3.1.

Changes:
- `mv3_server.py`: new message type `{"type": "race_state", "leader_id": ..., "rankings": [...], "eliminated": [...], "lap_counts": {...}}` broadcast by host @ 5Hz.
- `race_manager.gd` (host path): unchanged — keeps computing ranking authoritatively. Add `_broadcast_race_state()` if `_is_network_race` and `NetworkClient.is_host()`.
- `race_manager.gd` (client path): when `_is_network_race` and NOT host, replace local ranking computation with the server's `race_state` message. Render-only mode.
- HUD: now both clients show the SAME ranking, the SAME leader.

**Deliverable:** Client correctly displays "P2 - 2nd place" if the host says so.

### Phase 3.3 — Shared leader-cam + off-screen elimination (1 session)
**Depends on:** Phase 3.2 (need authoritative leader_id).

Changes:
- `race_manager.gd` MP path: every frame, look up the leader car node by `leader_id` from `race_state` message. Pass it to `camera_follow.set_leader_target()`.
- `camera_follow.gd`: extend with `is_on_screen(node3d) -> bool` helper using `Camera3D.is_position_in_frustum()` + a margin (e.g. 8m beyond frustum edge = "off-screen").
- New script `elimination_manager.gd` (~80 lines): per car, count consecutive frames off-screen. If > 90 frames (1.5s @ 60fps), trigger respawn with -1 life. If lives == 0, freeze + grey + add to `_eliminated`.
- HUD: 3-heart life icons per human player (top corners).
- Respawn logic: teleport car to `path_at(leader_phase - 0.05)` with leader's yaw, reset linear_velocity to half-speed.

**Deliverable:** P1 falling behind for 1.5s gets respawned at the back. After 3 such events, P1 is eliminated and host's bot wins. Both clients see the same elimination event.

### Phase 3.4 — Physical car-to-car collisions (1 session)
**Depends on:** none — can run in parallel with 3.3 if a second session is available.

Changes:
- `ghost_car.gd`: extend `Node3D` → `CharacterBody3D`. Add a `CollisionShape3D` (BoxShape3D matching the car, ~3.5×1.5×7m). Set `collision_layer = 2` (cars), `collision_mask = 1 | 2` (world + cars).
- `car.gd` (local human/bot): change `collision_mask` to include layer 2 (other cars).
- Update `update_state(pos, yaw, speed)` in ghost_car: instead of teleporting via `global_position = pos`, use `move_and_slide()` toward `pos` (kinematic interp), so physics engine can handle the contact response.
- Tune push-force / mass differential: ghost car should feel "solid" but not heavier than the local car.
- Test: at the figure-8 crossing, two cars at perpendicular angles should bump and bounce, not phase through.

**Deliverable:** "ça se tape, ça se pousse" — Seb's exact words.

### Phase 3.5 — Polish & balance (0.5 session)
- Tune `ELIMINATION_DIST_FROM_LEADER` for MP (probably tighter, ~80m, since shared cam already hides far cars).
- Add audio sting on elimination (life lost).
- Add "—1 LIFE" floating text on the respawn point.
- Validate on web build (`mv3.naskaus.com` with mobile touch input).

---

## 4. File-by-file change manifest

Estimate: ~600-800 LOC added/modified across these files.

| File | Change | LOC est. |
|---|---|---|
| `server/mv3_server.py` | New `race_state` broadcast, role field on joins, version bump v0.18.0 | +40 |
| `src/scripts/multiplayer_manager.gd` | Bot state sync (host), `is_host()` helper, race_state forwarding | +80 |
| `src/scripts/network_client.gd` | New signals: `race_state_received`, `bot_peer_joined`. `is_host()` getter. | +30 |
| `src/scripts/race_manager.gd` | MP-mode auth split (host computes / client renders), broadcast loop @ 5Hz, leader_id lookup for camera | +120 |
| `src/scripts/camera_follow.gd` | `is_on_screen(node)` helper using camera frustum | +25 |
| **NEW** `src/scripts/elimination_manager.gd` | Off-screen tracker per car, respawn logic, lives system | ~100 |
| `src/scripts/ghost_car.gd` | Convert Node3D → CharacterBody3D, add CollisionShape3D, kinematic move toward target | +60 |
| `src/scripts/car.gd` | collision_mask update | +5 |
| `src/scenes/Main.tscn` | Wire elimination_manager, life icons UI | (scene edit) |
| **NEW** `src/scenes/HUD/Lives.tscn` | 3-heart per player UI | new scene |
| `tasks/todo.md` | Update | +20 |
| `CLAUDE.md` | Update Phase 3 status | +30 |

---

## 5. Testing strategy

### 5.1 Local 2-window test
1. Launch Godot editor, run Main.tscn → window 1 = host, create room.
2. Run a second instance: `Godot.app/Contents/MacOS/Godot --path src/` → window 2 = client, join room with code.
3. Validate each phase before moving on.

### 5.2 Cross-network test (web build)
After Phase 3.4: rebuild web export, push to Pi5 `/var/www/mv3/`, test on:
- Phone (Safari iOS) joining a room hosted from Mac Chrome.
- Verify shared cam + collisions over WSS.

### 5.3 Bot AI sync test
After Phase 3.1: validate that bot car positions on the client match the host's bot positions within ~1m drift @ 200ms latency.

### 5.4 Elimination edge cases
- Player loses last life mid-jump on the ramp → don't respawn during airborne.
- Both humans go off-screen simultaneously (rare but possible) → don't double-respawn at same spot.
- Network drops mid-race → keep the local sim alive for 5s before declaring AFK.

---

## 6. Rollback plan

Each phase is independently shippable. If Phase 3.4 (collisions) destabilizes physics:
- Tag `v0.18.0-pre-collisions` before starting.
- Revert ghost_car.gd to Node3D, keep everything else.

If Phase 3.3 (elimination) feels too brutal in playtests:
- Make `ELIMINATION_LIVES` an exported constant on RaceManager, raise to 5 lives or disable temporarily.

---

## 7. Open questions for Seb

1. **Lives count:** 3 lives (MMV3 canonical) or 5 lives (more forgiving)? → **default 3, tunable**
2. **Elimination = lose race?** Or keep racing as a "ghost spectator"? → **lose race (frozen + greyed, MMV3 truth)**
3. **Bot count in MP rooms:** auto-fill to 6 cars? Or expose a slider in the lobby? → **default auto-fill 6, slider Phase 4**
4. **Should the host see a "host advantage" warning** in the lobby? → **no (transparency loses casuals)**
5. **Mobile UX:** with shared leader cam, mobile players who aren't leading still see the game. Good for spectators. Confirm this is desired? → **TBD with Seb**

---

## 8. Out of scope (Phase 4+)

- Track variants (other than figure-8)
- Tournament mode (best-of-3)
- Replay system
- Voice/text chat
- Cosmetic car skins
- Leaderboards (DB-backed)
- Server-authoritative pivot (Fork A2)

---

## 9. Approval gate

Before any code is written:
1. Seb reads this plan.
2. Seb validates Forks A, B, C (or proposes alternatives).
3. Seb answers the 5 open questions in §7.
4. Then `superpowers:executing-plans` opens Phase 3.1.
