# MicroNaskarV3 — Visual Design Pack

> Design pack v1 for the arcade racing game served at `mv3.naskaus.com`.
> Created: 2026-05-03 by `/naskaus-start` design session.
> Stack: Z-Image Turbo BF16 (local ComfyUI on MPS, 8 steps, cfg 1.0, Qwen text encoder).

## Decisions

**Brand direction:** PS1 chunky × Naskaus hybrid (option C from brainstorm).
**Generator:** ComfyUI local — Gemini free tier was exhausted at session start (`limit: 0` on `gemini-3-pro-image` and `gemini-3.1-flash-image`). Adobe Firefly path also unavailable (Photoshop not running). Z-Image Turbo BF16 chosen as the only live path; trade-off is slightly weaker typography precision vs. Gemini Nano Banana 2.

## Palette

| Role | Hex | Usage |
|---|---|---|
| Base background | `#0A0A0A` | Black canvas, menu fill, scanline base |
| Brand red | `#E2231A` | Naskaus signature, primary accent, NASKAR text |
| Cyan neon | `#00E5FF` | V3 badge, leaderboard CYAN helmet, highlights |
| Off-white | `#F5F5F0` | Text on dark, MICRO wordmark |
| Helmet GREEN | `#3DDC84` | Racer 1 |
| Helmet YELLOW | `#FFD600` | Racer 2 |
| Helmet ORANGE | `#FF6D00` | Racer 3 |
| Helmet CYAN | `#00E5FF` | Racer 4 (matches brand cyan) |
| Helmet RED | `#E2231A` | Racer 5 (matches brand red) |
| Helmet PURPLE | `#9C27B0` | Racer 6 |

## Style direction

- PS1 chunky 3D wordmark, slight 5° downward perspective tilt
- Chrome/red gradient on `NASKAR`, cyan neon `V3` badge
- Faint horizontal CRT scanlines as recurring texture cue
- Toy-car arcade aesthetic — coherent with the Kenney CC0 cars in-engine
- Figure-8 track silhouette as recurring visual motif in backgrounds

## Deliverables (8 assets, 12 files)

| # | Asset | File | Format |
|---|---|---|---|
| 1 | Logo horizontal | `logos/micronaskar_v3_logo_horizontal.png` | 1280×720 PNG, black BG |
| 2 | Logo carré (app icon) | `logos/micronaskar_v3_logo_square.png` | 1024×1024 PNG, black BG |
| 3 | BG menu principal | `backgrounds/bg_menu_main_16x9.png` | 1280×720 PNG |
| 4 | BG menu mobile | `backgrounds/bg_menu_portrait_9x16.png` | 720×1280 PNG |
| 5 | BG podium / results | `backgrounds/bg_podium_results.png` | 1280×720 PNG |
| 6 | Hero splash / loading | `backgrounds/hero_splash_keyart.png` | 1280×720 PNG |
| 7 | Helmet GREEN | `helmets/helmet_01_green.png` | 1024×1024 PNG |
| 8 | Helmet YELLOW | `helmets/helmet_02_yellow.png` | 1024×1024 PNG |
| 9 | Helmet ORANGE | `helmets/helmet_03_orange.png` | 1024×1024 PNG |
| 10 | Helmet CYAN | `helmets/helmet_04_cyan.png` | 1024×1024 PNG |
| 11 | Helmet RED | `helmets/helmet_05_red.png` | 1024×1024 PNG |
| 12 | Helmet PURPLE | `helmets/helmet_06_purple.png` | 1024×1024 PNG |

## Generation parameters (locked)

```
checkpoint:  z_image_turbo_bf16.safetensors  (diffusion_models/)
clip:        qwen_3_4b.safetensors  (type: qwen_image)
vae:         ae.safetensors  (FLUX-style autoencoder)
sampler:     euler / simple
steps:       8
cfg:         1.0  (Turbo distilled — no negative weight)
shift:       1.73  (ModelSamplingAuraFlow)
```

Each asset uses a unique fixed seed for reproducibility (see `/tmp/zimage_batch.py`).

## Known limitations

- Z-Image Turbo's typography is weaker than Gemini Nano Banana 2. The `MICRONASKAR V3` wordmark may need a manual touch-up pass in Photoshop for production-grade pixel-precision logo files (export SVG too).
- Logo dimensions (1280×720, 1024×1024) match generation pixel grid; if Apple/Google App Store icons are needed, a clean square crop + Photoshop bevel polish pass is recommended.
- Black background on logo PNGs — for transparent versions, use Photoshop "Color Range" → Blacks → Mask, or regenerate via Adobe Firefly when available.
- Helmet portraits use radial color-matched backgrounds (not transparent) — consistent with the leaderboard totem PS1 style. If transparent helmet cutouts are needed for HUD overlays, run `mcp__adobe-photoshop__remove_background` per file.

## Next steps (not in this delivery)

- Optional v2 pass with Gemini Nano Banana 2 once free-tier quota resets (~14h ICT 2026-05-04) for sharper logo typography.
- Integration into the Godot scenes: load logos as `Sprite2D` textures in `Main.tscn` menu, backgrounds as `TextureRect` fullscreen layers, helmets in the leaderboard totem.
- Telegram preview push to Seb after batch completion.

## References

- Project: `/Users/bpia/Documents/Seb/Coding/naskaus/games/micromachines-v3-clone/`
- Live deploy: `https://mv3.naskaus.com`
- ComfyUI workflow JSON: `/tmp/zimage_logo_h.json` (logo H reference) + `/tmp/zimage_batch.py` (full batch script)
- Brainstorm trace: this conversation, 2026-05-03 ~19:00 ICT
