---
title: "Archived: Architecture Decisions Anthology"
doc_type: "archive"
status: "archived"
owner: "coding-agent"
source: "manual"
created: "2026-06-22"
updated: "2026-08-01"
related_issue: ""
related_pr: ""
supersedes: ""
original_path: "docs/ARCHITECTURE_DECISIONS.md"
superseded_by: "docs/02_prd/prd-20260626-sprites-playground-current-clean.md and docs/04_adr/"
---

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

## ADR-004: Body Profiles Own Default Hurtboxes; Moves May Override Active Poses

Every character body profile owns the default receiving zones:

```text
hurt_head
hurt_upper_body
hurt_lower_body
```

A MoveTemplate may provide resolved, frame-windowed hurtbox overrides when an action pose materially changes the receiving silhouette. The override is move data, not a second body profile: outside its enabled frames, runtime falls back to the character body profile. This keeps body identity compositional while allowing authored crouches, jumps, and attacks to interact honestly.

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
