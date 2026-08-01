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

## Repository Layout

```text
SpritesPlayground/
├── dependencies/       pinned external dependency metadata
├── docs/
│   ├── 02_prd/         active requirement documents
│   ├── 03_bdd/         acceptance behavior
│   ├── 04_adr/         active architecture decisions
│   ├── 05_design/      design references and naming rules
│   ├── 06_testing/     test plans and generated validation reports
│   ├── 07_runbooks/    operator and development procedures
│   └── 90_archive/     superseded historical documents by year/month
├── godot/              scenes, scripts, and resources
├── scripts/            repository and environment operations
├── tests/              Python CLI behavior tests
└── tools/              project-domain import, generation, and smoke tools
```

## Required Setup

A development/debug/UAT checkout requires `uv`, Pi, and Godot `4.7.stable.official.5b4e0cb0f`. Ensure or verify the complete pinned environment with:

```bash
python3 scripts/bootstrap_dev.py
python3 scripts/bootstrap_dev.py --check
godot --editor --path .
```

The bootstrap checks before installing: healthy components are skipped without network access, missing or damaged add-ons are restored from pinned artifacts, and only missing external Pi resources are passed to `pi install`. LimboAI 1.8.0 is required by development, tests, and exported runtime. Godot AI 3.0.7 is required for development, debugging, and UAT only; its verified export plugin strips `_mcp_game_helper` from exported runtime settings.

Third-party add-ons and Pi package trees are not committed to Git. Project-owned `AGENTS.md`, `.pi/settings.json`, and `.pi/skills/` are tracked; credentials, sessions, and caches remain local. See `dependencies/`, the [bootstrap runbook](docs/07_runbooks/runbook-development-environment-bootstrap.md), and the [bootstrap test plan](docs/06_testing/test-20260801-development-environment-bootstrap.md).

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

See the active PRD pair — [Product PRD v0.6](docs/02_prd/prd-20260626-sprites-playground-product-v0-6.md) and [World Rules/No.0/Adam Supplement v0.6.3](docs/02_prd/prd-20260626-world-rules-no0-adam-v0-6-3-supplement.md) — plus GitHub issues for current scope and development acceptance criteria. Historical PRDs and implementation specifications are preserved under `docs/90_archive/`.
