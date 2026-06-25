# Implementation Spec v0.4.1: Action Authoring Tool Gap Add-on

Status: implementation plan for `docs/PRD_v0.4.1_ACTION_AUTHORING_TOOL_ADDON.md`

Source of truth:

- `docs/PRD_v0.4.1_ACTION_AUTHORING_TOOL_ADDON.md`
- `docs/PRD_v0.4_ACTION_AUTHORING_TOOL.md`
- `docs/IMPLEMENTATION_SPEC_V0_4_ACTION_AUTHORING_TOOL.md`
- GitHub issue #13

## 1. Goal

Close the v0.4.1 gap set without destabilizing the v0.4 baseline:

```text
22 required actions
+ no deferred catalog entries
+ broader foot collision contact behavior
+ obvious preview surface
+ edit-and-preview in one workflow
+ live Playground uses edited v0.3 action data
```

## 2. Scope Summary

v0.4.1 has six implementation tracks:

1. Expand the required catalog from 15 to 22 actions.
2. Promote `run`, `turn`, `heavy_punch`, `round_kick`, `guard`, `stun`, and `win_pose` from deferred to required.
3. Extend foot collision beyond arena clamp into real contact behavior.
4. Make the preview surface obvious and discoverable.
5. Keep preview visible while editing hitbox, hurtbox, and foot collision values.
6. Bridge edited v0.3 action data into live Playground runtime behavior.

## 3. Catalog Expansion

Update:

```text
godot/scripts/creator_lab_action_catalog.gd
data/v0_3/moves/*.json
data/v0_3/sprite_sets/combat_gray_s64.json
data/v0_3/templates/combat_gray_s64.json
tools/creator_lab_v0_3_smoke.gd
```

Required catalog count becomes 22.

Add catalog entries:

| action_id | category | state_context | backing |
| --- | --- | --- | --- |
| run | locomotion | walk | move-or-placeholder:run |
| turn | locomotion | walk | move-or-placeholder:turn |
| heavy_punch | combat | idle | move-or-placeholder:heavy_punch |
| round_kick | combat | idle | move-or-placeholder:round_kick |
| guard | utility | idle | move-or-placeholder:guard |
| stun | reaction | hurt | coverage-or-move:stun |
| win_pose | utility | idle | move-or-placeholder:win_pose |

Visual roles:

```text
run = fast locomotion loop
turn = direction change pose
heavy_punch = heavy attack pose
round_kick = round kick attack pose
guard = defensive pose
stun = stunned pose
win_pose = victory pose
```

Fixture rule:

- Prefer concrete v0.3 move fixtures for every restored action if cheap.
- Placeholder-backed fixtures are allowed for first pass.
- Every restored action must have a `required_moves_mapping` entry.
- Every restored action must resolve to an animation clip and frame sequence unless intentionally testing missing/invalid states.
- Placeholder frames must use `placeholder://`.

Smoke requirements:

- `Catalog.required_actions().size() == 22`.
- No issue #13 action is absent from `Catalog.action_ids()`.
- No restored action has `required_this_wave: false`.
- Coverage returns 22 rows.
- Wardrobe coverage renders 22 rows through the same coverage engine.

## 4. Foot Collision Contact Runtime

Update:

```text
godot/scripts/combat_character.gd
godot/scripts/playground.gd
tools/runtime_smoke.gd
```

Keep existing arena clamp behavior:

```text
foot ellipse radius reduces effective arena radius
```

Add at least one additional real runtime behavior in v0.4.1:

```text
player/NPC spacing by foot ellipse separation
```

Recommended implementation:

1. Add a helper that returns the live foot ellipse:

```gdscript
func foot_contact_ellipse() -> Dictionary
```

Return:

```text
center_world: Vector2
radius: Vector2
```

2. Add overlap/separation helper:

```gdscript
static func foot_ellipses_overlap(a: Dictionary, b: Dictionary) -> bool
static func foot_separation_delta(a: Dictionary, b: Dictionary) -> Vector2
```

3. In `Playground._tick_combat()`, after character ticks and arena clamp, resolve player/dummy foot overlap by moving one or both characters apart.

Rules:

- Use the same `foot_collision_profile.center` and `foot_collision_profile.radius` as debug draw.
- Do not add a separate hidden collision size.
- Do not introduce physics bodies unless needed.
- Keep the behavior deterministic and smoke-testable.

Smoke requirements:

- Two characters with small foot radii can stand closer than two characters with large foot radii.
- Increasing one character foot radius increases separation distance.
- Offsetting one character foot center changes the final resolved positions.
- Debug foot ellipse data and contact ellipse data come from the same profile.

Optional later behavior:

- room/lab trigger contact
- click/contact hit testing

If these are not implemented in the first v0.4.1 PR, the spec must state they remain open within v0.4.1, not closed.

## 5. Discoverable Preview Surface

Update:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/creator_lab_action_preview.gd
godot/scripts/playground.gd
tools/creator_lab_v0_3_smoke.gd
tools/runtime_smoke.gd
```

Current problem:

```text
Preview exists, but it is hidden behind a nav row named Action Preview.
```

Required UI:

- Add a clearly labeled `Preview` region that is visible whenever Creator Lab is open, or visible in every editing detail page for action-related edits.
- Add a separate left-side floating `Selected Sprite Preview` window toggled on/off by `V`.
- The region must show:
  - selected action id
  - status: OK / WARNING / FAIL / PLACEHOLDER / MISSING
  - frame index and total frame count
  - overlay legend for hurtbox, hitbox, and foot collision
- Keep the existing `Action Preview` nav if useful, but do not make it the only way to find preview.
- The floating window must render the selected sprite or explicit placeholder body at an inspectable size.
- The floating window must use the same `ActionPreview` data refresh path as the embedded preview.

Minimum acceptable layout:

```text
left nav
middle values
right edit panel
bottom or right persistent Preview strip
V-toggled left-side floating Selected Sprite Preview window
```

Smoke requirements:

- Opening Creator Lab creates a preview control without selecting `Action Preview`.
- Preview control has a visible title or label containing `Preview`.
- Preview control reports selected action id and frame count.
- `InputMap` binds `toggle_preview_window` to `KEY_V`.
- Pressing/toggling `V` shows and hides left-side `selected_sprite_preview_window`.
- `floating_preview_control.current_render_state()` matches the embedded preview for the selected action.

## 6. Same-Surface Edit And Preview

Update:

```text
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
```

Current problem:

```text
Foot Collision, Hurtboxes, Move hitbox editing, and Action Preview are separate nav pages.
```

Required behavior:

- When editing foot collision, the floating preview remains available and redraws after input submit.
- When editing hurtboxes, the floating preview remains available and redraws after input submit.
- When editing selected move hitbox fields, the floating preview remains available and redraws after input submit.
- The preview must be large enough to inspect the selected sprite/placeholder while the relevant inputs are visible.

Implementation options:

1. Persistent preview component:
   - Build one `ActionPreview` instance outside the nav detail switch.
   - Keep it updated from `current_action_id`, `template_json`, `sprite_set_json`, and `moves_json`.

2. Embedded preview per editor page:
   - Add the same preview component to `Foot Collision`, `Hurtboxes`, and move hitbox detail pages.
   - Reuse the same refresh method so behavior stays consistent.

Preferred: persistent preview component plus a floating preview window that shares the same refresh method. This avoids duplicating preview data flow while giving UAT an obvious preview target.

Smoke requirements:

- On `character_foot`, `action_preview_control != null`.
- `floating_preview_window` and `floating_preview_control` exist, start hidden, and toggle visible/hidden.
- Editing foot radius updates the preview model while `current_nav == "character_foot"`.
- On `character_hurtboxes`, editing a hurtbox updates the preview model while still on that nav page.
- On `move:<id>` hitbox section, editing hitbox rect updates the preview model while still on that nav page.

## 7. Live Playground v0.3 Action Data Bridge

Update options:

```text
godot/scripts/combat_character.gd
godot/scripts/character_template.gd
godot/scripts/move_library.gd
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/prd_v0_3_data_store.gd
godot/scripts/prd_v0_3_runtime.gd
tools/runtime_smoke.gd
```

Current problem:

```text
Creator Lab edits data/v0_3/**.
Live combat runtime still reads older data/** through CharacterTemplate / CreatorDataStore.
```

Required v0.4.1 behavior:

- A selected live `CombatCharacter` can run edited v0.3 move timing/hitbox data after apply or reload.
- The path must be explicit. Do not imply full live integration if only Creator Lab's internal `PrdV03Runtime` sees the edits.

Preferred implementation:

1. Add a v0.3-to-live adapter:

```gdscript
func apply_v0_3_runtime_bundle(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void
```

2. Adapter maps the live-runtime fields that `CombatCharacter` / `MoveExecutor` consume today:

```text
template_id
sprite_set_id
hp
hurtboxes
foot_collision
move frame_count
move active_window
damage
hitboxes
```

The adapter must explicitly document that `hitstop_frames`, `multi_hit`, v0.3 frame
`events`, and sprite-set frame data stay authoring/preview-only until the live combat
runtime consumes those fields.

3. `CreatorLabV03Panel.apply_to_bound_instance()` calls the adapter when the instance supports it.

4. Existing older data path remains available until a later migration, but v0.4.1 must prove the selected bound instance can use v0.3 edited move data.

Smoke requirements:

- Bind player.
- Copy or edit a v0.3 move hitbox rect.
- Apply to bound player.
- Trigger that move in live Playground.
- Assert active live hitbox uses the edited rect.
- Edit damage.
- Trigger hit against dummy.
- Assert live damage reflects edited v0.3 data.

Manual UAT:

- Open Creator Lab.
- Bind player.
- Edit `basic_punch` hitbox width or damage.
- Apply/reload through documented UI.
- Punch dummy in Playground.
- Confirm the live behavior changed.

## 8. Verification Matrix

Required existing checks:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
```

New checks to add or extend:

```text
catalog_22_required_actions
restored_actions_required_this_wave
wardrobe_22_action_coverage
preview_visible_on_lab_open
preview_visible_while_editing_foot
preview_visible_while_editing_hurtbox
preview_visible_while_editing_hitbox
foot_spacing_changes_with_radius
foot_spacing_changes_with_center_offset
foot_spacing_wall_reclamp
live_playground_uses_edited_v0_3_hitbox
live_playground_uses_edited_v0_3_damage
```

GitNexus gates before code changes:

```bash
node .gitnexus/run.cjs impact <symbol> --direction upstream --repo SpritesPlayground
node .gitnexus/run.cjs detect_changes --repo SpritesPlayground --scope compare --base-ref main
```

## 9. Non-Goals

Still out of scope:

- new saved schema version
- real PixelLab or AI generation
- weapon/projectile/combo systems
- final art quality
- full game levels
- stamina/mana
- paper-doll clothing editor

No longer out of scope for v0.4.1:

- full 22-action issue #13 catalog
- formerly deferred action entries
- foot collision behavior beyond arena clamp
- a discoverable preview surface
- same-surface edit and preview
- selected live Playground runtime using edited v0.3 action data
