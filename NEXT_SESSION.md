# NEXT SESSION — MV3 Phase 4 : Circuits + Power-Ups

> **Copier-coller le prompt en bas en début de session, ou invoque
> `/swarm MV3` (le card lit le launch_prompt automatiquement).**
> Last updated: 2026-05-06 (after Phase 3 multiplayer + solo peloton fix)

---

## État au moment où tu pars (2026-05-06)

- **Tag actuel : `v0.19.2-rc1`** — pushed, 0 ahead origin/main.
- **Live :** https://mv3.naskaus.com (web build) +
  wss://mv3-server.naskaus.com (multiplayer relay autoritaire).
- **Solo verdict Seb :** boost OK, plus d'élim 3ème, peloton préservé
  jusqu'à la fin. Phase 3 multi pas encore vraiment playtesté avec
  phone (à faire à ton rythme).
- **Spec Phase 4 :** `docs/superpowers/specs/2026-05-06-3-new-circuits-and-powerups.md`
  — 3 circuits complètement différents (Workshop / Petit-déj / Salle
  de bain) + power-up framework single-slot + 6 power-ups uniques par
  circuit + 4 phases d'implémentation ~1 800 LOC.

---

## Prompt à coller en début de prochaine session

```
Tu reprends MicroNaskar V3 (clone arcade racing PS1, Godot 4.6, deployé
sur mv3.naskaus.com). Solo + Phase 3 multi shippés.

ÉTAPE 1 — Lis ces 3 docs DANS L'ORDRE (NE PAS toucher au code avant) :
1. /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/CLAUDE.md
2. /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/docs/superpowers/specs/2026-05-06-3-new-circuits-and-powerups.md (LE PLAN Phase 4)
3. /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/NEXT_SESSION.md (ce fichier)

ÉTAPE 2 — Propose un résumé 5 lignes de la spec Phase 4 :
- 3 circuits : Workshop (atelier, drill-press drop, oil slicks, wrench
  bumper + welder trail) / Petit-déj (food kit géant, butter slicks,
  syrup mines, sugar rush) / Bathroom (tiled, water puddles, soap
  slides, water mines)
- Power-up framework single-slot, pickups Area3D, palette par circuit
  + boost_can baseline, MP sync via server-stamped sequences
- 5 phases (~1 800 LOC, ~4-5 sessions)

ÉTAPE 3 — Pose les questions d'approbation (§9 du plan) :
- Confirme les 3 circuits (Workshop / Petit-déj / Bathroom) ou propose
  des alternatives MMV3 (sand pit, garden v2, school desk, kitchen…)
- Confirme power-up framework (single-slot, RNG sur palette, server-
  stamped sequence en MP)
- Réponds aux 5 open questions §6 :
  Q1 pickups guaranteed vs RNG (reco RNG)
  Q2 mobile use button position (reco bottom-right thumb zone)
  Q3 bots ont power-ups (reco oui)
  Q4 MP rollback si server reject (reco visual fire then snap back)
  Q5 tight_indoor_circuit polyline arbitraire ou templates (reco
     arbitraire — c'est du JSON)

ÉTAPE 4 — Une fois Seb a validé : invoque superpowers:executing-plans
sur le plan path et démarre Phase 4.1 (wire CircuitLoader to engine).

ÉTAPE 5 — Avant code, vérifie que :
- mv3.naskaus.com répond HTTP 200 (curl -sf)
- mv3-server.service est active sur Pi5
- git working tree clean (pas de bordel laissé par 0.19.2)
- godot-mcp boot Main.tscn sans erreur
- `git pull origin main` au cas où

PITFALLS GODOT À NE PAS RÉPÉTER :
1. Node3D n'a PAS modulate (CanvasItem-only) — utiliser materials
2. RigidBody3D collision_layer=1 par défaut, ne pas changer (BoostPad
   Area3D mask=1 — tu casses tout sinon)
3. Signal bind() args APPEND not prepend
4. _state_runs_locally split host/client : pour leader-cam partagée,
   utilise toujours network leader_id en MP, indépendamment du host
5. Web export = GLES Compatibility renderer mandatory
6. Manual .tscn editing risqué — préférer godot-mcp + script-side
   programmatic UI (cf. multiplayer_menu.gd btn_elim_mode)

ROLLBACK PLAN si Phase 4 destabilise :
git checkout v0.19.2-rc1 -- src/
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 "cd /var/www && sudo \
  rm -rf mv3 && sudo cp -r mv3.bak.<timestamp> mv3"
```

---

## Quick context (skip le launch_prompt si tu te rappelles)

**Architecture Phase 3 (acquise) :**
- Server Pi5 = autoritaire bookkeeper, race_state @ 5Hz, anti-cheat laps++
- Lobby toggle "Mode 3 VIES / ÉLIMINATION" (host only)
- Cars CharacterBody3D ghosts en MP (collisions au crossing)
- Shared leader-cam pour TOUT le monde (v0.19.1-rc1)
- Distance-elim 120m solo retiré (v0.19.2-rc1, peloton préservé)

**Architecture Phase 4 (cible) :**
- CircuitLoader DÉJÀ là (foundation, JSON loaded mais engine hardcodé)
- Phase 4.1 = wire CircuitLoader → engine (Track01.tscn driven from JSON)
- Phase 4.2 = 3 nouvelles geometries dans path_utils.gd
- Phase 4.3 = surface_zones (butter / syrup / oil) + powerup_manager.gd
- Phase 4.4 = 6 power-ups uniques (wrench_bumper, welder_trail,
  sticky_syrup, sugar_rush, soap_slide, water_mine) + bot AI heuristic
- Phase 4.5 = lobby dropdown + assets polish + music per circuit

**Files clés à connaître :**
- `src/scripts/circuit_loader.gd` (autoload, déjà loaded 2 circuits)
- `src/circuits/default.circuit.json` + `picnic.circuit.json` (schéma actuel)
- `src/scripts/path_utils.gd` (figure-8 math — à étendre pour 3 nouveaux types)
- `src/scripts/decor.gd` (procedural decor — à brancher sur circuit.decor)
- `server/mv3_server.py` (à étendre pour `powerup_use` message)

**Pi5 commands :**
```bash
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 "sudo systemctl status mv3-server.service"
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 "sudo journalctl -u mv3-server.service -f"
```

**Build + deploy (gold-standard pipeline depuis 2026-05-04) :**
```bash
cd /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone
rm -rf web_export/* && /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path src --export-release "Web" ../web_export/index.html
ssh -i ~/.ssh/id_claude_mcp seb@100.119.245.18 \
  "sudo cp -r /var/www/mv3 /var/www/mv3.bak.$(date +%s)"
touch /tmp/.naskaus-last-pi5-snapshot
rsync -avz --delete web_export/ -e "ssh -i ~/.ssh/id_claude_mcp" \
  seb@100.119.245.18:/var/www/mv3/
curl -sf -o /dev/null -w "HTTP %{http_code}\n" https://mv3.naskaus.com/
```

---

## Carry-overs (rappel pour /naskaus-start futur)

- naskaus-v2 push debt 12 ahead origin/main (carry from 2026-05-04)
- AI Radar STALE >50 jours (carry depuis 2026-03-14)
- Pi5 15 apt security updates pending
- MEMORY.md global > 200 lignes — rotation à faire au prochain
  /naskaus-end qui touche memory/
- Design pack v1 (12 PNG) toujours pas intégré in-engine — peut être
  fait pendant Phase 4.5 (logos sur menu, helmets sur ghost cars)
- Phase 3 MP playtest réel (Mac+phone) toujours pas fait — Seb a
  testé solo seulement après v0.19.2-rc1
