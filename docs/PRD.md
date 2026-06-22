# PRD: Miduo Character Combat Lab

Status: v0.2 — Full Product Scope

## 1. Product Definition

**Miduo Character Combat Lab** is an internal Godot tool for building, editing, generating, validating, and stress-testing limited, template-based pixel characters before they enter the real Miduo game project.

It is not a normal playable level. It is the character production and validation lab.

The product must support this complete workflow:

```text
base gray template
→ create/edit character template
→ configure hurtboxes, hitboxes, foot ellipse
→ equip and tune moves
→ switch or generate sprite sets
→ import and validate generated frames
→ run manually in playground
→ run AI/state-machine stress
→ save template configuration
→ mark character ready for game integration
```

## 2. Product Goals

1. Provide a visual Godot playground where pixel characters can be controlled and tested.
2. Provide a fixed-size character template system for `s48`, `s64`, `s80`, and `s96`.
3. Provide editable hurtbox, hitbox, and foot-collision tools.
4. Provide a Move Lab for equipping, tuning, and saving actions.
5. Provide a Wardrobe for switching full sprite sets and detecting missing animations.
6. Provide a PixelLab/Python generation pipeline for missing characters, outfits, and moves.
7. Provide import and validation rules for generated sprite frames.
8. Provide runtime validation through manual play, debug GUI, and AI stress testing.
9. Produce stable, validated character templates that can later be moved into the real game.

## 3. Product Non-goals

The product does not aim to be a full game engine or final game project.

MVP and near-term versions do not include:

- formal story levels
- weapon system
- projectile/flying-object system
- stamina system
- mana/magic system
- full combo tree
- economy/shop inventory
- single-piece wardrobe/dress-up paper doll system
- skeleton, bone, hand-anchor, or leg-anchor model
- deep inheritance template tree
- multiplayer

## 4. Core Design Rules

### 4.1 Fixed Sprite Size Classes

Supported sprite classes:

```text
s48
s64
s80
s96
```

Frame storage rule:

```text
frame_size = sprite_size + 16
```

Therefore:

```text
s48 → 64x64 frame
s64 → 80x80 frame
s80 → 96x96 frame
s96 → 112x112 frame
```

The extra 16 px is action-safe space for fists, feet, hair, small effects, and pose extension.

### 4.2 Composition, Not Deep Inheritance

Character templates are assembled from explicit data/profile parts. The system does not use deep inheritance chains.

A character may be created by copying an existing template, but the resulting template should save its own resolved local data.

### 4.3 Locked Gray Base Templates

Gray base templates are calibration templates. They are not directly edited and do not equip extension moves.

Editable work should happen on copied templates such as `combat_gray_s64`, `miduo_s64`, `dad_s80`, etc.

### 4.4 Character-local Coordinates

All boxes use character-local coordinates.

The character origin is the foot-center ground point.

Saved box values are resolved local rects, not inherited offset patches.

Pixel nudge operations may be used in the editor, but saved data remains final local coordinates:

```text
x, y, w, h
```

### 4.5 Hurtboxes Belong To Character

Each character body profile owns:

```text
hurt_head
hurt_upper_body
hurt_lower_body
```

These describe where the character can be hit.

### 4.6 Hitboxes Belong To Moves

Hitboxes are move-owned and frame/timing driven.

Supported hitbox names:

```text
hit_head
hit_fist_1
hit_fist_2
hit_leg_1
hit_leg_2
hit_projectile   # reserved, disabled until projectile system exists
```

A move may use one hitbox or multiple hitboxes, but hitboxes are never stored as permanent character body data.

### 4.7 One Foot Collision Ellipse

Each character has exactly one foot collision ellipse.

It is used for:

- ground occupancy
- arena boundary tests
- room trigger contact
- character spacing

It is not an attack or hurt detection shape.

### 4.8 HP-only First Combat Model

The first combat model uses HP only.

No stamina, mana, armor, crit, defense, or elemental systems are part of the current product baseline.

## 5. Runtime Baseline Already Completed

The first runtime MVP has been completed and merged.

Completed baseline:

```text
combat_gray_s64
idle / walk / dash / jump / attack / hurt / dead
basic_punch / basic_kick
move-owned hitbox windows
character-owned hurtboxes
foot ellipse
HP damage
hit flash
debug GUI
runtime_smoke.gd
```

This baseline is not the complete product. It is the runtime foundation for the full lab.

## 6. Full Product Modules

### 6.1 Playground Arena

A 640x360 Godot scene displayed at 1280x720.

Core features:

- large ellipse activity area
- manual character control
- AI/manual toggle
- debug rendering of hurtboxes, hitboxes, and foot ellipse
- room trigger zones
- current state/move/frame/HP display

### 6.2 Template Lab

The template system manages character types.

A character template contains:

```text
id
sprite_size_class
frame_size
sprite_set_id
hurtbox_profile
foot_collision_profile
hp_profile
base_action_set
base_attack_moves
equipped_moves
lock_state
validation_status
```

Template operations:

- create from locked gray base
- duplicate existing editable template
- rename template
- change sprite size class only through explicit new-template creation
- edit hurtboxes
- edit foot ellipse
- assign sprite set
- equip or remove extension moves
- save template to persistent data
- validate template completeness

Base gray templates remain locked.

### 6.3 Box Editor

The Box Editor provides visual editing for:

```text
hurt_head
hurt_upper_body
hurt_lower_body
hitboxes inside selected move
foot_collision_ellipse
```

Editor requirements:

- show current sprite frame
- show all hurtboxes in separate colors
- show active move hitboxes in separate colors
- show foot ellipse
- allow pixel nudge movement
- allow width/height adjustment
- save resolved local rects
- support frame-by-frame hitbox editing for moves
- flash hit/hurt boxes on successful attack contact

The Box Editor is part of the same integrated lab milestone as Template Lab, Move Lab, and Wardrobe. It is not a later unrelated tool.

### 6.4 Move Lab

Move Lab is the action-equipping and parameter-tuning room.

It is entered from the playground through a room trigger.

Move Lab supports:

- listing base actions
- listing base attack moves
- listing equipped extension moves
- equipping available moves
- removing equipped moves
- selecting a move
- editing move parameters
- editing active frames
- editing move-owned hitboxes
- saving move data
- validating whether required sprite animation exists

Core movement actions:

```text
idle
walk
dash
jump
hurt
dead
```

Base attack moves:

```text
basic_punch
basic_kick
```

Extension move examples:

```text
cross_punch
heavy_punch
round_kick
dash_attack
jump_attack
```

Move parameter fields:

```text
move_id
move_type
animation_name
frame_count
startup_frames
active_start_frame
active_end_frame
recovery_frames
damage
hitstop
knockback
cooldown
hitboxes
```

MVP movement rules remain simple:

- Dash is a short burst, no stamina, no invincibility by default.
- Jump is an action/visual jump, not full platform physics.

### 6.5 Wardrobe

Wardrobe is the sprite-set room.

It is entered from the playground through a room trigger.

Wardrobe supports:

- switching full sprite sets for a character template
- viewing current template and sprite size class
- listing required animations
- listing missing animations
- previewing selected animation
- triggering generation request for missing animation
- importing generated animation result
- validating frame size and frame count

Wardrobe does not support single clothing item paper-doll editing in current scope. It switches complete sprite sets/outfits.

### 6.6 PixelLab Generator

PixelLab integration starts outside Godot as a Python/MCP tool under:

```text
tools/pixellab_generator/
```

Responsibilities:

- generate gray standard characters
- generate full sprite sets
- generate missing move animations
- generate multiple size classes
- save source output
- slice frames when needed
- validate frame count and frame size
- write manifest data

Godot should first import generated output. Later the Wardrobe may call the Python generator from a GUI button.

### 6.7 Import Pipeline

Generated assets must pass import validation before being assigned to a character template.

Validation checks:

- file exists
- image can load
- frame size matches selected sprite class frame contract
- frame count matches move definition
- transparent or expected background rule is satisfied
- naming follows snake_case
- manifest references are valid
- required animations for base actions exist or are marked placeholder

### 6.8 Debug and Timeline Inspector

The debug layer must show:

```text
template id
instance id
sprite size class
state
current move
current frame
active hitbox
hurtbox visibility
foot ellipse visibility
HP
AI/manual mode
validation warnings
```

Timeline view should show current move frames and active hitbox window:

```text
[1][2][3][4][5][6][7][8]
       ^ active hitbox frames
```

### 6.9 AI and Validation

AI mode validates that a character can run under automated operation.

AI should exercise:

```text
idle
walk
dash
jump
basic_punch
basic_kick
equipped moves when available
```

Validation output:

- no invalid state
- no null move
- no self-hit
- no repeated hit in one active window
- no deadlock
- HP changes only from valid hits
- warnings for missing animations

## 7. Integrated Next Milestone

The next milestone after the completed runtime baseline is **Creator Lab v1**.

Creator Lab v1 must deliver Template Lab, Box Editor, Move Lab, and Wardrobe together as one usable vertical slice.

It should not be split into separate product fragments because these features depend on each other:

```text
template selection
→ box editing
→ move editing
→ sprite-set selection
→ save and reload
→ run in playground
```

Creator Lab v1 required capabilities:

1. Select `combat_gray_s64` or create a copied editable template.
2. Edit hurtboxes and foot ellipse visually.
3. Select `basic_punch` or `basic_kick` and edit its hitbox frames.
4. Enter Move Lab and edit move parameters.
5. Enter Wardrobe and switch a complete sprite set placeholder.
6. Save the template configuration.
7. Reload the template and preserve edits.
8. Return to playground and validate the edited template at runtime.

Creator Lab v1 does not need PixelLab generation fully wired yet, but it must show missing-animation status and reserve the generation entry point.

## 8. Persistence Strategy

The source-of-truth data format should be JSON once Creator Lab editing begins.

MVP runtime may use GDScript dictionaries, but editable templates must move toward JSON-backed persistence.

Recommended layout:

```text
data/
  templates/
    combat_gray_s64.json
    miduo_s64.json
  moves/
    basic_punch.json
    basic_kick.json
  sprite_sets/
    gray_dummy_s64.json
  manifests/
    generated_asset_manifest.json
```

Rules:

- JSON is the editable source of truth.
- Godot runtime may convert JSON into in-memory dictionaries/resources.
- `.tres` or `.res` may be used later as cache, not source of truth.
- Every saved template includes schema version.

## 9. Data Contract Direction

### 9.1 CharacterTemplate JSON

```json
{
  "schema_version": 1,
  "template_id": "combat_gray_s64",
  "sprite_size_class": "s64",
  "frame_size": 80,
  "sprite_set_id": "gray_dummy_s64",
  "max_hp": 10,
  "hurtboxes": {
    "hurt_head": { "x": -10, "y": -60, "w": 20, "h": 18 },
    "hurt_upper_body": { "x": -13, "y": -42, "w": 26, "h": 24 },
    "hurt_lower_body": { "x": -12, "y": -20, "w": 24, "h": 20 }
  },
  "foot_collision": {
    "center": { "x": 0, "y": 0 },
    "radius": { "x": 16, "y": 6 }
  },
  "base_actions": ["idle", "walk", "dash", "jump", "hurt", "dead"],
  "base_attack_moves": ["basic_punch", "basic_kick"],
  "equipped_moves": []
}
```

### 9.2 MoveTemplate JSON

```json
{
  "schema_version": 1,
  "move_id": "basic_punch",
  "move_type": "attack",
  "animation_name": "basic_punch",
  "frame_count": 8,
  "startup_frames": 2,
  "active_start_frame": 3,
  "active_end_frame": 4,
  "recovery_frames": 4,
  "damage": 1,
  "hitstop": 0.05,
  "knockback": { "x": 40, "y": 0 },
  "hitboxes": [
    {
      "name": "hit_fist_1",
      "frame_start": 3,
      "frame_end": 4,
      "rect": { "x": 18, "y": -38, "w": 18, "h": 10 }
    }
  ]
}
```

### 9.3 SpriteSet JSON

```json
{
  "schema_version": 1,
  "sprite_set_id": "gray_dummy_s64",
  "template_size_class": "s64",
  "frame_size": 80,
  "animations": {
    "idle": { "path": "res://generated_assets/gray_dummy_s64/idle.png", "frames": 6 },
    "basic_punch": { "path": "res://generated_assets/gray_dummy_s64/basic_punch.png", "frames": 8 }
  },
  "missing_animations": ["basic_kick"]
}
```

## 10. Rooms and Scene Flow

The playground contains:

```text
main arena
Move Lab room
Wardrobe room
```

Flow:

```text
playground control
→ enter Move Lab trigger
→ edit moves/boxes
→ save
→ return to arena
→ enter Wardrobe trigger
→ switch sprite set / inspect missing animations
→ save
→ return to arena
→ run manual or AI validation
```

## 11. UAT Definition

A character template is ready for game integration when:

- it has a valid sprite size class
- all required base actions exist or approved placeholders exist
- hurtboxes are valid
- foot ellipse is valid
- base attack moves have hitbox windows
- HP damage can be triggered by valid hits
- debug GUI shows no blocking validation warnings
- template can save and reload without changing values
- AI validation can run without invalid state/deadlock

## 12. Roadmap

### Completed

Runtime Core Baseline:

- playground runtime
- combat gray s64
- state machine
- move executor
- hitbox/hurtbox collision
- HP
- smoke test

### Next

Creator Lab v1:

- Template Lab
- Box Editor
- Move Lab
- Wardrobe
- JSON persistence
- save/reload validation

### Later

PixelLab Pipeline:

- Python/MCP generator
- generated manifest
- missing animation generation
- import validation

Validation Layer:

- stronger AI stress
- deterministic replay
- regression reports

## 13. Product Summary

Miduo Character Combat Lab is the production pipeline for pixel characters.

The runtime MVP proves characters can move and fight.

The full product must let the developer create, edit, equip, dress, generate, validate, save, reload, and approve character templates before they move into the final game.
