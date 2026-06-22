# Architecture Decisions

## ADR-001: Use Composition, Not Deep Inheritance

Character templates are built from profiles:

```text
CharacterTemplate
├── SpriteProfile
├── HurtboxProfile
├── FootCollisionProfile
├── HPProfile
├── BaseActionSet
└── EquippedMoveSet
```

The system does not use deep template inheritance chains.

Reason: inheritance would make later changes hard to trace. Composition makes every template explicit and easier to debug.

## ADR-002: Locked Gray Base Templates

Gray base templates are calibration templates. They cannot be directly edited or equipped with extension actions.

To create a new editable character, duplicate a base/combat template and edit the copy.

## ADR-003: Hitboxes Belong To Moves

Hitboxes are not stored on the character template. They are stored in `MoveTemplate` timelines.

Examples:

```text
miduo_basic_punch → hit_fist_1 frames 3-4
dad_basic_kick → hit_leg_1 frames 5-6
```

Reason: Dad kick, Mama kick, and Miduo kick may share an action category but need different animation timing and hitbox geometry.

## ADR-004: Hurtboxes Belong To Character Body Profiles

Every character body profile owns:

```text
hurt_head
hurt_upper_body
hurt_lower_body
```

These are body receiving zones and should not be defined per attack move.

## ADR-005: No Body Anchors Or Bones In MVP

The system does not model hand length, leg length, fist anchors, leg anchors, bones, or body part pivots.

All hitboxes and hurtboxes use character-local coordinates.

## ADR-006: Save Local Rects, Not Offset Patches

Because the system uses composition rather than inheritance, box data is saved as resolved local rectangles:

```text
x, y, w, h
```

Coordinates are local to the character origin, recommended as the foot center.

Editor controls may move boxes by pixel offsets, but saved data is the final local rect.

## ADR-007: State Machine Drives Moves

Runtime flow:

```text
Input / AI
→ request_move(move_id)
→ StateMachine validates current state
→ State executes MoveTemplate
→ MoveTimeline controls animation + hitboxes
→ Hitbox hits Hurtbox
→ HP damage + hit flash
→ HurtState if needed
```

States are behavior categories. Moves are data.

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
