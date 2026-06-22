# SpritesPlayground

SpritesPlayground is a Godot-side development lab for **Miduo Character Combat Lab**.

This repository is no longer a verification dump for generated sprite resources. It has been reset into a clean project skeleton for designing and implementing a limited, template-based pixel character playground.

## Product Purpose

SpritesPlayground exists to validate pixel character templates before they enter the real game project.

It should help answer:

- Does the sprite template match the supported size class?
- Do base actions play correctly?
- Do attack moves activate the correct hitboxes at the correct frames?
- Do hurtboxes, hitboxes, and the foot collision ellipse match the sprite?
- Can AI/manual control run the character without state-machine failures?
- Can future PixelLab-generated assets be imported and validated safely?

## Current Product Direction

The product is a **limited customizable character template system**, not a free-form game engine.

Core rules:

- Fixed sprite size classes: `s48`, `s64`, `s80`, `s96`.
- Character templates are built by **composition profiles**, not deep inheritance.
- Base gray templates are locked and cannot be directly edited.
- Hurtboxes belong to character body profiles.
- Hitboxes belong to move templates.
- Hitboxes use character-local coordinates, not body anchors or bones.
- First MVP supports HP only; no stamina, mana, weapons, or projectile system.

## Repository Status

Previous verification work has been archived on branch:

```text
archive/verification-work-2026-06-22
```

Downloadable archive URL:

```text
https://github.com/proletariat64/SpritesPlayground/archive/refs/heads/archive/verification-work-2026-06-22.zip
```

## Skeleton Layout

```text
SpritesPlayground/
├── README.md
├── project.godot
├── docs/
│   ├── PRD.md
│   ├── PRODUCT_SCOPE.md
│   ├── DEVELOPMENT.md
│   ├── NAMING.md
│   └── ARCHITECTURE_DECISIONS.md
├── godot/
│   ├── scenes/
│   ├── scripts/
│   └── resources/
├── tools/
│   └── pixellab_generator/
├── generated_assets/
└── archive/
    └── README.md
```

## MVP Focus

The first working MVP should prove this loop:

```text
combat gray s64 template
→ manual movement / AI stress mode
→ dash / jump / basic punch / basic kick
→ hitbox-hurtbox collision
→ HP damage and hit flash
→ debug GUI shows state, move, frame, hitbox, hurtbox, and HP
```

## What This Repo Does Not Do Yet

- No formal game stages.
- No weapon system.
- No projectile system.
- No stamina or mana system.
- No full combo system.
- No full wardrobe/dress-up system.
- No full PixelLab integration inside Godot yet.

See `docs/PRD.md` and GitHub issues for current scope and development acceptance criteria.
