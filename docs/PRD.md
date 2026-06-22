# PRD: Miduo Character Combat Lab

Status: Draft v0.1

## 1. Background

`SpritesPlayground` previously contained verification work for sprite viewing and generated Godot resources. The project is now reset into a clean product skeleton for a more focused internal tool: **Miduo Character Combat Lab**.

The lab exists to test limited, template-based pixel characters and combat boxes before assets move into the real game.

## 2. Product Goal

Build a playground where a character template can be loaded, manually controlled, AI-stressed, edited, and validated against sprite size, actions, hurtboxes, hitboxes, HP, and state-machine behavior.

## 3. MVP Goal

The MVP proves one loop:

```text
CombatGrayTemplate s64
→ idle / walk / dash / jump
→ basic_punch / basic_kick
→ hitbox timeline activates
→ target hurtbox receives hit
→ HP decreases
→ hit flash appears
→ debug GUI reports state/move/frame/boxes/HP
```

## 4. Core Concepts

### Sprite Size Classes

Fixed MVP classes:

```text
s48, s64, s80, s96
```

Frame storage rule remains:

```text
frame_size = sprite_size + 16
```

### Character Template

A character type assembled from composition profiles.

```text
CharacterTemplate
├── id
├── sprite_size_class
├── sprite_profile
├── hurtbox_profile
├── foot_collision_profile
├── hp_profile
├── base_action_set
└── equipped_move_set
```

### Character Instance

A runtime instance of a character template in the playground. MVP may limit one instance per template type.

### Hurtbox Profile

Body receiving zones:

```text
hurt_head
hurt_upper_body
hurt_lower_body
```

### Move Template

A move/action with animation, timing, hitbox timeline, damage, knockback, and recovery data.

Hitboxes belong here, not to the character body.

### State Machine

MVP states:

```text
Idle
Walk
Dash
Jump
Attack
Hurt
Dead
```

States execute move data rather than creating a unique state per move.

## 5. MVP Features

### F1. Template Loading

Load a locked gray base template and a combat gray test template.

Acceptance:

- Base gray template is readable but locked.
- Combat gray template is editable for MVP testing.
- Template data is assembled from explicit profiles.

### F2. Movement Playground

A 640x360 scene displayed at 1280x720.

Acceptance:

- Character can move inside a large ellipse arena.
- Character has exactly one foot collision ellipse.
- Foot ellipse can be shown in debug view.

### F3. Base Actions

Support:

```text
idle
walk
dash
jump
hurt
dead
```

Acceptance:

- Each action can play a sprite animation or placeholder.
- Dash changes horizontal movement for a short duration.
- Jump is MVP visual jump / action jump, not full platform physics.

### F4. Base Attack Moves

Support:

```text
basic_punch
basic_kick
```

Acceptance:

- `basic_punch` uses `hit_fist_1`.
- `basic_kick` uses `hit_leg_1`.
- AttackState can execute both moves from data.

### F5. Hitbox / Hurtbox Collision

Acceptance:

- Hitbox can overlap hurtbox.
- Own hitbox does not hit own hurtbox.
- One active attack window can only damage one target once.
- Successful hit triggers HP damage and flash.

### F6. HP System

MVP has HP only.

Acceptance:

- Character has max/current HP.
- Hit decreases HP.
- HP 0 enters DeadState.
- No stamina, mana, armor, crit, recovery, or resistances.

### F7. Debug GUI

Acceptance:

- Shows template id, instance id, current state, current move, current frame, HP.
- Shows hurtbox/hitbox visibility toggles.
- Shows active hitbox state.
- Shows AI/manual mode.

### F8. AI Stress Mode

Acceptance:

- AI can randomly idle, walk, dash, jump, punch, kick.
- AI can run for a fixed test duration without state-machine deadlock.
- Debug GUI reports current AI action.

## 6. Explicit Non-goals

- No projectile system in MVP.
- No weapon system.
- No stamina system.
- No mana/magic system.
- No full combo system.
- No full shop system.
- No formal game level.
- No body-anchor/bone system.
- No deep inheritance template tree.
- No Godot-embedded PixelLab API integration in MVP.

## 7. PixelLab Integration Direction

PixelLab MCP/API integration should start as a separate Python tool under:

```text
tools/pixellab_generator/
```

Godot should first import generated results, not directly own the generation backend.

Later, Godot may call the Python generator from a GUI button.

## 8. MVP Data Contracts

MVP runtime data is represented as explicit GDScript dictionaries returned by
dedicated data scripts:

```text
godot/scripts/character_template.gd
godot/scripts/move_library.gd
```

This is the selected MVP format. JSON and `.tres` Resources remain possible later
serialization targets, but they are not open questions for G1.

### CharacterTemplate

`CharacterTemplate.combat_gray_s64()` returns:

```text
template_id: String
sprite_size_class: String
frame_size: int
max_hp: int
hurtbox_profile: Dictionary[String, Rect2]
foot_collision_profile: Dictionary
move_templates: Dictionary[String, MoveTemplate]
```

Required MVP profile keys:

```text
hurtbox_profile:
  hurt_head: Rect2
  hurt_upper_body: Rect2
  hurt_lower_body: Rect2

foot_collision_profile:
  center: Vector2
  radius: Vector2
```

All box rects are character-local, with the character origin at the foot-center
ground point.

### MoveTemplate

`MoveLibrary.combat_gray_s64_moves()` returns move templates keyed by move id:

```text
move_id: String
fps: int
total_frames: int
hitbox_windows: Array[Dictionary]
```

Each hitbox window uses integer combat frames:

```text
from_frame: int
to_frame: int
hitbox_id: String
damage: int
rect: Rect2
```

MVP moves:

```text
basic_punch -> hit_fist_1
basic_kick -> hit_leg_1
```

Hitboxes are only defined by move templates. Hurtboxes are only defined by
character templates.

## 9. Resolved MVP Decisions

- Data format for G1: GDScript dictionary contracts in `character_template.gd`
  and `move_library.gd`.
- Character-local origin: foot-center ground point.
- Dash duration: `0.18` seconds at the fixed physics tick.
- Jump duration: `0.42` seconds, visual/action-only, no platform physics.
- `combat_gray_s64` uses placeholder drawn geometry for MVP.

## 10. Open Questions

- Whether later persistence should use JSON, `.tres` Resources, or both.
- Whether later combat templates should be generated from PixelLab or edited from placeholders.
