---
title: "Generated background integration evidence"
doc_type: test_evidence
status: active
owner: SpritesPlayground maintainers
source: user request
created: 2026-11-13
updated: 2026-11-13
---

# Generated background integration evidence

Five image outputs were preserved unchanged; see [provenance](../../../../godot/assets/homeward/art_provenance.json). `contact_sheet.png` is the image operator's design review sheet, not a game screenshot or animation sheet.

## Actual headed captures

Godot 4.7, `gl_compatibility`, WSLG, Mesa llvmpipe; viewport 640×360 displayed at 1280×720. Captured the harness's own viewport using `get_texture().get_image().save_png()` in a headed process, PID 203955. The process exited normally. No input or signals were sent to existing Godot windows.

- `title-generated-background.png`: actual title menu with generated school background.
- `school-gameplay-generated-background.png`: actual fresh encounter after Start; character feet lie on the asphalt below the curb, with original combat positions unchanged.
- `home-alignment-preview.png`: **staged art alignment preview**, not proof of beating the route. The harness freezes physics, moves the player to (2015,274), and sets the camera to (1920,180) to inspect the home. HUD still says first encounter because gameplay progression was deliberately not modified. The warm doorway lies just right of the existing x=2010 home threshold; HOME points toward it. Feet remain on the street.

The three 768×432 PNG backgrounds are rendered at native logical size with nearest filtering, x=0/768/1536 and y=-72. No old procedural scenery is painted over them. Source art edges/seams and pixel density are not certified to be perfectly seamless or identical to Miduo's sprite grid.

## Focused checks

- Headless editor import: completed; existing language-server shutdown thread warning remains.
- `homeward_stage_smoke.gd`: PASS, including live-scene Sprite2D consumption, imported Texture2D dimensions/paths, nearest filtering, and placement checks.
- `homeward_input_smoke.gd`: PASS, including repaired Enter menu navigation.
- `input_event_controls_smoke.gd`: PASS.
- Direct byte comparisons confirmed all five copied source PNGs equal their `/tmp/miduo-gpt-assets/raw/` originals; no new hash mechanism was added.

Enemy PNGs are design drafts only. Existing animated blue Miduo enemies remain provisional. Two designs lack animation sets and three requested designs are missing. Integration performed no provider calls or paid generation.
