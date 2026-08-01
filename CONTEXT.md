# Sprites Playground

A combat-sprite playground for previewing character movement, animation, and authored actions.

## Language

**Eight-direction locomotion**:
The character's idle, walk, and run presentation uses one of eight compass orientations. Dash, jump, hurt, and attack presentation remains two-facing.
_Avoid_: Eight-direction combat, eight-way combat

**Locomotion direction**:
The compass orientation derived from movement intent for idle, walk, and run presentation; its last non-zero value remains stable while stationary.
_Avoid_: Combat facing, measured displacement

**Combat facing**:
The persistent east-or-west orientation used by dash, jump, hurt, and attack presentation, independent of locomotion direction.
_Avoid_: Locomotion direction, eight-direction combat facing

**Run**:
Faster manual locomotion requested by holding Ctrl while moving; it uses the same eight locomotion directions as walk.
_Avoid_: Sprint, dash
