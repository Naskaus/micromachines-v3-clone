# Kenney All-in-1 Bundle — Inventory & Reference

> **License:** CC0 1.0 Universal — unlimited commercial use, no attribution required, no AI-generated content.
> **Bundle:** v3.4.0, ~250 packs, 87,000+ files, 492 MB unzipped.
> **Source archive:** `~/Downloads/Kenney Game Assets All-in-1 3.4.0.zip` (purchased 2026-05-03 by Seb on itch.io for $19.95).
> **Updates:** lifetime free, ~1 new pack/month.
>
> **Extraction policy:** do NOT decompress the whole bundle into the project (1+ GB bloat). Extract only what's needed per task into `src/assets/<kit_name>/` and run `godot --headless --import` to register.

---

## Already extracted (in `src/assets/`)

| Folder | Source pack | Items |
|---|---|---|
| `cars/` | Car Kit | 49 GLB cars + colormap |
| `track_pieces/` | Racing Kit | 90+ GLB (banners, fences, grandstands, lightposts, pylons, ramps, road segments, supports, billboards, flagCheckers, bridge pieces, ...) |
| `toy_kit/` | Toy Car Kit | item-banana, item-box, item-coin-gold, item-coin-silver, item-cone, track-narrow-looping, track-narrow-corner-large-ramp, supports-wide, gate-finish |
| `food_kit/` | Food Kit | apple, cake-birthday, cookie-chocolate, donut-sprinkles, pizza, sandwich + colormap |
| `audio/` | Synth Voice 1 + Retro Sounds 2 + Music Loops + Impact Sounds + Foley + Interface | count_1/2/3, begin, congratulations, defeat, engine3, upgrade1, hit1, explosion1, secret1, gameover1, coin1, phaseJump1, powerUp4, impactGeneric_light_000, impactPlate_heavy_001, bong_001, select_005, time_driving, mishief_stroll, skid (= platesslide1) |

To extract more from the bundle:

```bash
cd ~/Downloads
unzip -j -o "Kenney Game Assets All-in-1 3.4.0.zip" \
  "<path/to/file.glb>" \
  -d /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/src/assets/<kit>/
/Applications/Godot.app/Contents/MacOS/Godot --headless --path src/ --import
```

---

## 🎲 3D Kits (51 packs)

### ⭐ Already used / high-priority for MV3
- **Toy Car Kit** — Hot Wheels-style track building (loops, banked corners, ramps, supports, items: banana/box/coin/cone/smoke, gates start+finish)
- **Car Kit** — 49 toy cars (race, sedan-sports, hatchback-sports, kart-oobi, tractor, race-future, etc.)
- **Racing Kit** — 90+ track-side decor (barriers, fences, grandstands, banners, light posts, pylons, ramps, road, billboards, flagCheckers, bridge segments)
- **Food Kit** — 80+ food items (donut, sandwich, cake, pizza, cookie, apple, banana, hamburger, etc.) for picnic-track vibe
- **Furniture Kit** — desks, chairs, tables, beds, sofas → "wood desk on apartment" track
- **Nature Kit** + **Nature Kit (Classic)** — grass, flowers, hedges, trees → garden tracks
- **Marble Kit** — toy-scale tubes, ramps, marbles (alternate Hot Wheels)
- **Coaster Kit** — full roller coaster loops/banks/supports
- **Holiday Kit** — Christmas tree, presents, candy canes → seasonal track variant
- **Mini Skate** — skateboards, ramps, cones (toy-shelf scale)
- **Mini Arcade / Mini Arena / Mini Market / Mini Dungeon** — toy-shelf scale buildings

### Other 3D kits available
- **Animated Characters 1/2/3 + Bundle** — animated humans (spectators, losers)
- **Blocky Characters / Mini Characters 1** — simplified NPCs
- **City Kit Commercial / Industrial / Roads / Suburban** — real city tracks
- **Building Kit + Modular Buildings** — modular buildings
- **Brick Kit** — Lego-style assembly
- **Castle Kit + Pirate Kit + Fantasy Town Kit** — medieval / fantasy
- **Retro Medieval Kit + Retro Urban Kit** — PS1 aesthetic
- **Graveyard Kit** — Halloween track
- **Hexagon Kit** — modular hex tiles
- **Modular Dungeon Kit** — underground tracks
- **Modular Space Kit + Space Kit + Space Station Kit** — futuristic / zero-gravity tracks
- **Minigolf Kit** — mini-golf course
- **Platformer Kit + Prototype Kit** — greybox quick-test
- **Survival Kit + Weapon Pack + Blaster Kit** — apocalypse vibe
- **Tower Defense Kit + Tower Defense Classic** — TD layouts
- **Train Kit + Watercraft Pack** — alternate vehicles
- **Road Pack** — extra road segments
- **Conveyor Kit** — industrial conveyor belts

---

## 🎵 Audio (16 packs)

### ⭐ Used in MV3
- **Synth Voice 1** — count_1.ogg, count_2.ogg, count_3.ogg, begin.ogg (countdown F1-style)
- **Retro Sounds 2** — engine3.ogg (looping engine), upgrade1.ogg (boost), coin1.ogg (arch chime), secret1.ogg (lap complete), gameover1.ogg, hit1.ogg, explosion1.ogg
- **Music Loops** — Time Driving.ogg (race), Mishief Stroll.ogg (menu)
- **Impact Sounds** — 134 collision SFX (extracted: impactGeneric_light_000, impactPlate_heavy_001)
- **Interface Sounds** — bong_001.ogg (countdown beep), select_005.ogg (GO bright)
- **Foley Sounds** — platesslide1.ogg (used as skid SFX, but retired — too robotic for racing)

### Available, not yet used
- **Retro Sounds 1** — laser, jump, lose, win, creature (more variety)
- **Synth Voice 2** — additional voiceover lines
- **Voiceover Pack + Voiceover Pack Fighter** — pro voice acting
- **Casino Audio** — cards, dice, slots (menu sounds)
- **Digital Audio** — bleeps, lasers, futuristic
- **Sci-Fi Sounds** — doors, computers, radar
- **UI Audio** — clicks, beeps for menus
- **RPG Audio** — spells, magic, swords
- **Music Jingles** — short stings (race start, win, lose)

---

## 🎨 2D Assets (151 packs!)

### ⭐ Top picks for MV3
- **Racing Pack** — top-down racing tile set (cars, road, decor, water, sand)
- **Playing Cards Pack** — playing cards (use as ramps on pool table track, MMV3 reference)
- **Letter Tiles + Redux** — wooden letter tiles "START", "FINISH" (for ground-painted text)
- **Pattern Pack 1 + 2 + Pixel** — felt, plaid, wood-grain, dots, stripes (track surfaces)
- **Retro Textures 1** — PS1-aesthetic textures
- **Road Textures + Road Textures Classic** — asphalt textures
- **Boardgame Pack** — dice, cards, pieces (for boardgame-themed track)
- **Background Elements + Redux** — parallax backgrounds
- **Smoke Particles + Splat Pack** — boost trails, oil splats
- **Crosshair Pack** — HUD targeting reticles
- **Particle Pack** — sparks, fire effects
- **Foliage Pack + Foliage Sprites** — grass, flowers (decor)

### Massive 2D categories (browse by name)

**Roguelike (7 packs):** Base, Characters, City, Dungeon, Interior, Cave, Micro Roguelike

**Platformer (14+ packs):** Assets Base/Buildings/Candy/Extra/Holiday/Ice/Mushroom/Pixel/Requests/Tile Extensions, Bricks, Characters 1, Pack Industrial/Medieval/Nautical/Redux, Pico-8 Platformer, Pixel Line/Pixel/Blocks/Farm/Food/Industrial expansions, Simplified, Jumper Pack

**Isometric (18 packs):** Blocks, Medieval Town, Miniature Bases/Dungeon/Farm/Library/Overworld/Prototype, Minigolf, Modular Buildings/Roads, Nature, Space Interior, Tiles Base/Buildings/City/Vehicles, Tower Defense, Vector Buildings, Vector Roads Base/Water, Watercraft

**Pixel-art (10+ packs):** Pixel Platformer family, Pixel Vehicle Pack, Pixel Line Platformer, Pixel Shmup, Pico-8 City/Platformer, Topdown Shooter (Pixel), RTS Medieval (Pixel), Block Pack (Pixel), Pattern Pack Pixel

**RTS / RPG (7 packs):** RTS Medieval, RTS Medieval (Pixel), RTS Sci-fi, RPG Tiles Vector, RPG Urban Pack, Tiny Battle, Roguelike RPG

**Sketch (6 packs):** Sketch Desert, Sketch Town, Sketch Town Expansion, Scribble Dungeons, Scribble Platformer, Yellow Paint Pack

**Hexagon (4 packs):** Hexagon Base Pack, Hexagon Buildings Pack, Hexagon Pack, Axonometric Blocks

**Tank / Topdown (5 packs):** Tank Pack, Topdown Shooter, Topdown Shooter (Pixel), Topdown Tanks, Topdown Tanks Redux

**Pirate / Pico-8 / 1-Bit / Voxel:** Pirate Pack, Monochrome Pirates, 1-Bit Pack, 1-Bit Platformer Pack, Voxel Pack, Voxel Expansion Pack

**Other notables:** Animal Pack + Redux, Alien UFO Pack, Brick Pack, Cartography Pack, Character Pack + Facial Hair, Donuts, Emote Pack, Explosion Pack, Fish Pack, Generic Items, Googly Eyes, Holiday Pack 2016, Map Pack, Medals, Minimap Pack, Monochrome RPG Tileset, Monster Builder Pack, New Platformer Pack, Physics Assets, Planets, Prototype Textures, Puzzle Assets 1 + 2, Ranks Pack, Robot Pack, Rolling Ball Assets, Rune Pack, Shape Characters, Shooting Gallery, Simple Space, Smilies, Sokoban Pack, Space Shooter Extension/Redux, Sports Pack, Tappy Plane, Tiny Dungeon, Tiny Ski, Tiny Town, Toon Characters Pack 1, Tower Defense

---

## 🎮 UI Assets (10 packs)

- **UI Pack** — generic menus
- **UI Pack - Adventure** — RPG-style menus
- **UI Pack - Pixel Adventure** — pixel-art menus
- **UI Pack - Sci-fi** — futuristic menus
- **UI Adventure Pack** — buttons + dialogues
- **UI Pixel Pack** — pixel-art buttons
- **Cursor Pack + Cursor Pixel Pack** — cursors
- **Mobile Controls** ⭐ — virtual joysticks (could replace MV3's split-screen tap)
- **Fantasy UI Borders** — medieval frames

---

## 🏆 Icons (8 packs)

- **Game Icons + Expansion + Fighter Expansion** — ~1500 arcade icons (powerup symbols, fighter moves)
- **Input Prompts** ⭐ — keyboard, Xbox, PlayStation, Switch button icons (perfect for tutorial overlays + mobile button hints)
- **Input Prompts Pixel 16x** — pixel-art version
- **1-Bit Input Prompts Pixel 16x** — monochrome version
- **Board Game Icons + Board Game Info** — pieces, dice, cards

---

## 🎁 Other

- **Fonts** — Kenney Pixel, Kenney Future, Kenney Mini, Kenney Blocks (free arcade fonts)
- **Construct samples 1 + 2** — example Construct 3 projects (reference only)
- **Miniguides** — Kenney's small tutorials

---

## 🎯 Suggested V0.18+ track variants (using inventory)

Each = ~3-4h work using existing engine + new asset pack.

| Track | Source packs | Vibe |
|---|---|---|
| **Pool Table v2** (current Track01) + cards | 2D Playing Cards + Pattern Pack | Original MMV3 |
| **Garden Track** | Nature Kit + Foliage Pack | Picnic park |
| **Wood Desk + STOP/START** | Furniture Kit + 2D Letter Tiles | Bureau d'enfant |
| **City Track** | City Kit Roads + Suburban + Commercial | Manhattan/SF |
| **Hot Wheels Track** | Toy Car Kit (loops + banks + supports + ramps) | Aerial Mario Kart |
| **Fantasy Castle** | Castle Kit + Fantasy Town Kit + Pirate Kit | Médiéval |
| **Space Station** | Modular Space Kit + Space Kit + Space Station Kit | Zero-G future |
| **Picnic Plaid** (Seb's MMV3 ref) | Food Kit + 2D Pattern Pack 2 (plaid) | Picnic chaotic |
| **Halloween** | Graveyard Kit + Holiday Pack 2016 | Spooky theme |
| **Christmas** | Holiday Kit + Holiday Pack 2016 + 2D Snow textures | Festive |

---

## 🔧 Workflow for adding a new pack

```bash
# 1. Pick the pack you want
cd ~/Downloads
unzip -Z1 "Kenney Game Assets All-in-1 3.4.0.zip" | grep "^3D assets/<PACK>/Models/GLB format/" | sed 's|.*/||'

# 2. Extract specific files
mkdir -p /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/src/assets/<KIT>/Textures
unzip -j -o "Kenney Game Assets All-in-1 3.4.0.zip" \
  "3D assets/<PACK>/Models/GLB format/<file1>.glb" \
  "3D assets/<PACK>/Models/GLB format/<file2>.glb" \
  -d /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/src/assets/<KIT>/

# 3. Extract texture (always needed for Kenney 3D kits)
unzip -j -o "Kenney Game Assets All-in-1 3.4.0.zip" \
  "3D assets/<PACK>/Models/GLB format/Textures/colormap.png" \
  -d /Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/src/assets/<KIT>/Textures/

# 4. Trigger Godot import (creates .glb.import files)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path src/ --import

# 5. Reference in decor.gd or scene .tscn
const NEW_GLB := "res://assets/<KIT>/<file>.glb"
```

---

**License reminder:** All Kenney assets are **CC0 1.0 Universal** — you can use them for commercial projects, sell games using them, distribute them, modify them, and you don't need to credit Kenney (though it's nice to). No royalties, no per-title fees, no exposure to license drift.

**Attribution to consider:** A "Made with Kenney CC0 assets" credit in the game's about screen costs nothing and supports Kenney's free-asset philosophy. Recommended.
