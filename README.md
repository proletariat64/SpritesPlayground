# SpritesPlayground

SpritesPlayground is the standalone Godot sprite asset playground for Miduo Holiday. It exists to organize, preview, debug, and validate pixel-art character animation resources before clean assets are moved into the game project.

## Current Actors

- `dad_chibi_64`
- `mama_chibi_64`
- `miduo_chibi_64`

Each actor is imported from its own `sprites/chibi_64/<actor_id>/manifest.json`. The aggregate `export_manifest.json` is not used because it is incomplete.

## Sprite Contract

```text
base viewport: 640x360 px
default window: 1280x720 px
fullscreen target: 1920x1080 px
aspect ratio: 16:9
stretch mode: viewport / keep
startup window mode: fullscreen
Esc behavior: return to 1280x720 windowed mode
visual sprite intent: 64x64 px
Godot animation frame: 80x80 px
debug UI cell: 80x80 px
physical PNG source: unchanged 120/132/136 px canvases
default direction: east
default action: idle_breath
rendering: nearest neighbor
```

The importer does not rewrite source PNGs. It builds centered `AtlasTexture` frames with an `80x80` region inside each source PNG:

```text
region.x = (source_width - 80) / 2
region.y = (source_height - 80) / 2
region.size = 80x80
```

## Godot Resources

Generated resources are committed under:

```text
resources/sprite_frames/dad_chibi_64.tres
resources/sprite_frames/mama_chibi_64.tres
resources/sprite_frames/miduo_chibi_64.tres
```

Each `SpriteFrames` resource contains 119 manifest action-direction animations named as:

```text
<action>__<direction>
```

Examples:

```text
idle_breath__east
walk_loop__southwest
jab__west
```

Resource metadata includes:

- `actor_id`
- `visual_sprite_intent`
- `godot_frame_size`
- `debug_cell_size`
- `source_png_size`
- `animation_separator`
- `action_names`

## Animation State

The viewer models animation state as three small fields:

```text
current_actor_id
current_action
current_direction
```

It does not create gameplay state names like `walk_southwest` or `run_north`.

Resolution order:

1. Use exact `<action>__<direction>` when present.
2. For west-like directions, use `<action>__west` when present.
3. For west-like directions, use `<action>__east` with horizontal flip when no west animation exists.
4. Otherwise use the first animation available for that action and warn through Godot.

Looping is enabled for actions ending in `_loop`, plus `idle_breath` and `fight_idle`. Other actions play once.

## Viewer

Open the project and press `Open SpritesPlayground` from the main menu.

The viewer provides:

- actor buttons for dad, mama, and miduo
- an action list for the 34 manifest actions
- eight direction controls
- looping preview cells for every action
- debug text showing actor, action, direction, frame, source PNG size, and `80x80` Godot frame size

## Regenerate And Verify

Run the importer:

```bash
godot --headless --path . --script tools/import_sprite_frames.gd
```

Run the smoke test:

```bash
godot --headless --path . --script tools/smoke_sprites_playground.gd
```

The smoke test verifies that all three `SpriteFrames` resources are present, each resource has 119 animations, manifest frame counts match, every frame is an `AtlasTexture` with an `80x80` region, scenes instantiate headlessly, and default state resolution works.
