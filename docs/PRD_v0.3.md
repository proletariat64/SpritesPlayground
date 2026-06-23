# PRD: SpritesPlayground

Status: v0.3 - Clean Version / Frozen

## 1. Product Definition

SpritesPlayground is a Move-driven 2D combat character lab built in Godot.

It is not:

- a full game engine
- a level-based game
- a combo system simulator

It is:

```text
a data-driven character combat editor + runtime validation sandbox
```

## 2. Core Design Philosophy

```text
1. State is minimal and stable
2. Move is the only editable gameplay unit
3. Frame is the only time system
4. Event is frame-attached data
5. No inheritance, only composition
6. No system expansion without explicit freeze rule
```

## 3. Core Architecture

This section is frozen for v0.3.

### 3.1 State

State defines control mode only. State does not define gameplay behavior or move logic.

Allowed states:

```text
idle
walk
dash
jump
hurt
dead
```

Rules:

- No `walk_start` or `walk_stop`.
- No `run_state`.
- No combat state variants.
- State never encodes move logic.

### 3.2 Move

Move is the only gameplay definition unit.

Move types:

```text
locomotion:
- walk
- run
- dash
- jump

combat:
- basic_punch
- basic_kick
- throw_grab

reaction:
- hurt
- knockdown
- getup

utility:
- idle
```

Move rules:

- Move is frame-driven.
- Move owns hitboxes.
- Move owns timing.
- Move owns damage.
- Move may override state context.

### 3.3 Frame

Frame is the fixed timestep unit.

Example:

```text
12 FPS
```

Rules:

- No seconds-based gameplay logic.
- No dual timeline system.

### 3.4 Event System

Events are frame-attached instructions.

Example:

```text
Frame 3 -> enable hitbox
Frame 5 -> play sound
Frame 7 -> disable hitbox
```

## 4. Hit System

This section is frozen for v0.3.

### 4.1 Core Rule

```text
One Move -> One Hit Event per target per active window
```

### 4.2 Multi-hit Extension

Multi-hit behavior is only allowed when explicitly flagged:

```text
move.multi_hit = true
```

Frozen meaning for v0.3:

```text
multi_hit = multi-stage combat move
```

It is the only allowed exception to the normal one-hit rule.

Rules:

- `multi_hit = false` means one Move may resolve only one Hit Event against the same target in the same active window.
- `multi_hit = true` means the same Move may resolve multiple Hit Events against the same target during one Move execution.
- Each additional hit must come from a distinct frame-attached hit opportunity.
- Multi-hit does not create a new state.
- Multi-hit does not create a separate subsystem.
- Multi-hit does not mean multiple simultaneous hitboxes automatically deal multiple hits.

Allowed example:

```text
Frame 3 -> enable hitbox -> hit 1
Frame 5 -> disable hitbox
Frame 7 -> enable hitbox -> hit 2
Frame 9 -> disable hitbox
```

Forbidden interpretation:

```text
Frame 3 -> hit_fist_1 and hit_fist_2 overlap same target
= two damage events
```

That is not multi-hit by itself. It is still one active window unless the Move explicitly marks separate frame-attached hit opportunities.

v0.3 boundary:

- The schema only freezes the `multi_hit` flag and its meaning.
- v0.3 does not introduce `hit_windows`.
- v0.3 does not add combo rules.
- A later version may refine multi-hit data shape, but that is outside this frozen PRD.

### 4.3 Hurtbox System

- Multiple hurtboxes are allowed.
- One hit resolves through priority selection.
- Other overlapping hits only trigger visual feedback.

## 5. Hitstop System

Hitstop is a global time freeze applied on a hit event.

Rules:

- Hitstop applies to movement.
- Hitstop applies to animation.
- Hitstop applies to hitbox evaluation.
- Hitstop has a global default.
- Hitstop may be overridden per move.

Default behavior:

```text
freeze duration = 2-5 frames
```

## 6. Jump, Dash, Run, and Walk

This section is frozen for v0.3.

### 6.1 Walk

```text
continuous locomotion move
```

### 6.2 Run

```text
walk variant using a speed modifier
```

### 6.3 Dash

```text
discrete time-limited locomotion move
```

### 6.4 Jump

```text
state transition + air context move
```

## 7. Combat Extensions

### 7.1 Combat Move

- A combat move is a Move with `type = combat`.
- A combat move uses the hitbox window system.

### 7.2 Throw

Throw is a Move that bypasses normal hitbox priority rules.

Rules:

- Throw is not a state.
- Throw is not a subsystem.
- Throw is a Move type.

### 7.3 Hurt, Knockdown, and Getup

Hurt, knockdown, and getup are reaction moves.

They are not states.

## 8. Hard Frozen Rules

### 8.1 No State Explosion

- No new states without control or physics necessity.
- No animation-driven states.

### 8.2 No Move Explosion

Forbidden moves:

```text
walk_start
walk_stop
run_start
run_stop
```

### 8.3 No Inheritance System

- No deep class hierarchy.
- Only composition of data.

### 8.4 No Secondary Time System

Only Frame exists.

## 9. Creator Lab v1 Scope

Creator Lab is a single integrated editor pipeline.

Modules:

### 9.1 Template Lab

- Select or copy character template.
- Edit configuration.

### 9.2 Box Editor

- Edit hurtboxes.
- Edit move-owned hitboxes.
- Edit foot collision.

### 9.3 Move Lab

- Edit move data.
- Edit frame timeline.
- Configure hitbox windows.

### 9.4 Wardrobe

- Switch full sprite sets.
- Validate animation completeness.

### 9.5 Playground Runtime

- Manual testing.
- AI stress test.
- Debug visualization.

## 10. Data Model

This section is the frozen data contract for v0.3.

### 10.1 CharacterTemplate

```text
sprite_set_ref
hurtboxes
foot_collision
hp
equipped_moves
```

### 10.2 MoveTemplate

```text
frame_count
active_window
damage
hitstop_frames
hitboxes
multi_hit
```

### 10.3 SpriteSet

```text
animation_clips
frame_sequences
required_moves_mapping
```

## 11. Final System Definition

```text
SpritesPlayground =
Move-driven combat lab
+ frame-based deterministic system
+ event-based execution
+ minimal state machine
+ strict data-driven editing
```

## 12. Final Frozen Conclusion

```text
State is not gameplay
Move is gameplay
Frame is time
Event is trigger
```

## 13. Next Step

The next important step is not more product design.

The next step is:

```text
Convert this PRD into JSON Schema + Creator Lab UI structure diagram.
```

That starts the usable tool-system stage.
