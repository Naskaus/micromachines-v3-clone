# BRIEF — Micromachines V3 Clone

**What:** Top-down arcade racing clone of Micro Machines V3 (PS1, 1997). Auto-accelerate, 2-button steering, 4 players on 2 controllers (split-pad like the PS1 original), toy-scale household environments, drift physics, classic "knock them off the table" elimination.

**Stack:** Godot 4.6 (3D under near-top-down camera) + GDScript. PS1 chunky aesthetic optional shader.

**Status:** WIP — V0 prototype phase (1 car, flat plane, control feel).

**Repo:** local-only — `/Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/`.

**MVP scope:** ONE car drives on ONE flat track with auto-acceleration + left/right steering that feels right. Pause + check before scaling up.

**4 players, 2 pads:** P1 = left half of pad 1 (D-pad), P2 = right half (face buttons), P3 = left half of pad 2, P4 = right half. Keyboard fallback for solo testing: A/D, J/L, ←/→, Numpad 4/6.

**Win condition:** classic Micro Machines — be the only car still on screen when others fall off / are knocked off / lap behind. Score-based across rounds.
