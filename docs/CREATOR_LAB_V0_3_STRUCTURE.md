# Creator Lab v0.3 UI Structure

Status: v0.3 structure contract

Source of truth:

- `docs/PRD_v0.3.md`
- `data/schemas/v0_3/*.schema.json`

Creator Lab v1 is one integrated editor pipeline. It edits data, then validates the same data in the Playground Runtime.

## Frozen Model

```text
State = control mode
Move = gameplay
Frame = time
Event = trigger
```

The UI must not introduce legacy fields:

```text
action
attack
base_action_set
base_actions
base_attack_moves
```

## Layout

```text
Creator Lab
├── Template Lab
├── Box Editor
├── Move Lab
├── Wardrobe
└── Playground Runtime
```

## Template Lab

Purpose:

- Select or copy a character template.
- Edit character-level configuration.
- Choose equipped moves.

Owned schema fields:

```text
CharacterTemplate.template_id
CharacterTemplate.sprite_set_ref
CharacterTemplate.hp
CharacterTemplate.equipped_moves
```

Read-only cross-checks:

```text
SpriteSet.sprite_set_id
MoveTemplate.move_id
MoveTemplate.move_type
```

Validation:

- `sprite_set_ref` must resolve to one SpriteSet fixture.
- Every `equipped_moves[]` entry must resolve to one MoveTemplate fixture.
- No state or move is created implicitly by sprite animation names.

## Box Editor

Purpose:

- Edit character hurtboxes.
- Edit move-owned hitboxes.
- Edit foot collision.

Owned schema fields:

```text
CharacterTemplate.hurtboxes
CharacterTemplate.foot_collision
MoveTemplate.hitboxes
MoveTemplate.hitboxes[].active_window
```

Rules:

- Hurtboxes remain character-owned.
- Hitboxes remain move-owned.
- Foot collision is not an attack or hurt shape.
- Hitbox active windows are frame ranges only.

## Move Lab

Purpose:

- Edit move data.
- Edit the frame timeline.
- Configure frame-attached events.

Owned schema fields:

```text
MoveTemplate.move_id
MoveTemplate.move_type
MoveTemplate.state_context_override
MoveTemplate.frame_count
MoveTemplate.active_window
MoveTemplate.damage
MoveTemplate.hitstop_frames
MoveTemplate.multi_hit
MoveTemplate.events
FrameEvent.frame
FrameEvent.event_type
FrameEvent.payload
```

Rules:

- Move is the only editable gameplay unit.
- Frame is the only time unit.
- Seconds-based gameplay timing is not shown in UI.
- `multi_hit` must be explicitly visible as a boolean control.
- Combat behavior is represented by `move_type = combat`, not by a state.

Multi-hit UI boundary:

- The UI shows `multi_hit` as a Move-level flag.
- `multi_hit = true` means the Move is allowed to resolve multiple frame-attached Hit Events against the same target during one Move execution.
- The UI must not imply that multiple simultaneous hitboxes automatically mean multiple damage events.
- v0.3 does not expose a `hit_windows` editor.
- v0.3 does not create combo or attack-state controls.

## Wardrobe

Purpose:

- Switch full sprite sets.
- Validate animation completeness for equipped moves.

Owned schema fields:

```text
SpriteSet.sprite_set_id
SpriteSet.animation_clips
SpriteSet.frame_sequences
SpriteSet.required_moves_mapping
```

Validation:

- Every equipped move must have a `required_moves_mapping` entry.
- Every mapped clip must exist in `animation_clips`.
- Every animation clip must resolve to a frame sequence.
- Wardrobe does not define gameplay.

## Playground Runtime

Purpose:

- Load selected v0.3 data.
- Execute frame-based move timelines.
- Trigger frame events.
- Visualize runtime state for manual testing and AI stress testing.

Runtime read model:

```text
current_state
current_move
current_frame
hitstop_frames
hurtboxes
active_hitboxes
foot_collision
sprite_set_ref
```

Required event behavior:

```text
enable_hitbox
disable_hitbox
set_velocity
change_state_context
apply_hitstop
```

Runtime rules:

- Hitstop freezes movement, frame advance, and hitbox evaluation.
- State display comes from control context.
- Move timeline remains frame-based and deterministic.
