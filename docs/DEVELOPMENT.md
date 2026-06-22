# Development Guide

## Development Mode

This repository is currently a skeleton. Do not add generated sprite assets directly to main until the MVP data contracts are stable.

## Branching

Recommended:

```text
main                      clean, documented skeleton or stable MVP
feature/<short-name>      feature work
archive/<date-name>       historical verification snapshots
```

## Commit Style

Use concise conventional-style commits:

```text
docs: define product scope
feat: add playground scene skeleton
feat: add combat gray template data
fix: correct hitbox collision filtering
chore: update project skeleton
```

## Implementation Order

1. Data contracts for templates, profiles, moves.
2. Minimal Godot scene loads a combat gray s64 template.
3. State machine with Idle/Walk/Dash/Jump/Attack/Hurt/Dead.
4. Hurtbox debug drawing.
5. Move-owned hitbox timeline.
6. HP and hit flash.
7. Debug GUI.
8. AI stress mode.
9. Python PixelLab generator skeleton.

## Verification

Every functional change should state how it was checked.

Examples:

```text
Manual: ran playground, basic_punch hit dummy once.
Manual: AI stress ran 3 minutes without state lock.
Headless: ran smoke script once it exists.
```

## Safety Rules

- Do not commit API keys or `.env`.
- Do not commit large generated sprite dumps to main.
- Do not commit ripped commercial sprites.
- Do not mix formal game code into this lab before MVP is stable.
