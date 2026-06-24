# PRD v0.4.1: Action Authoring Tool Gap Add-on

Status: add-on PRD for issue #13 gap closure

Source of truth:

- GitHub issue #13: Next Wave: Creator Lab Action Authoring Tool v1
- `docs/PRD_v0.4_ACTION_AUTHORING_TOOL.md`
- `docs/IMPLEMENTATION_SPEC_V0_4_ACTION_AUTHORING_TOOL.md`
- Current v0.4 build and UAT gap audit

## 1. Purpose

v0.4 built the first practical Creator Lab action authoring loop, but it deliberately scoped down several issue #13 requirements. v0.4.1 reopens the highest-value cuts and closes the real build gaps found during UAT.

This add-on does not replace v0.4. It extends it.

v0.4.1 must make Creator Lab feel less like a hidden form workflow and more like the first usable action-game sprite authoring tool:

```text
full issue #13 action coverage
+ always-obvious preview surface
+ edit-and-preview in the same workflow
+ broader foot collision runtime behavior
+ edited action data runnable from Playground
```

## 2. Reopened Scope From Issue #13

### 2.1 Full Required Action Catalog

v0.4 required 15 actions. v0.4.1 restores the full issue #13 catalog to required status.

Required actions:

```text
idle
walk
run
dash
turn
jump_start
jump_air
jump_land
basic_punch
basic_kick
heavy_punch
round_kick
dash_attack
jump_attack
hurt_light
hurt_heavy
knockdown
get_up
dead
guard
stun
win_pose
```

The catalog remains derived diagnostic data. It is not stored inside template, move, or sprite-set JSON.

### 2.2 No More Deferred Catalog Entries

The following v0.4 deferred entries are required in v0.4.1:

```text
run
turn
heavy_punch
round_kick
guard
stun
win_pose
```

These entries may start as placeholder-backed actions, but they must be visible in the catalog, coverage panel, preview, Wardrobe coverage, and validation warning system.

Required behavior:

- Each restored action has a catalog row.
- Each restored action has a visual role.
- Each restored action has `required_this_wave: true`.
- Missing, placeholder, invalid, duplicate-idle, missing-sequence, and wrong-frame-count states remain visible where applicable.
- The action count shown in UI and tests is 22.

### 2.3 Broader Foot Collision Runtime Behavior

v0.4 made foot collision affect arena boundary clamp only. v0.4.1 restores the broader issue #13 intent: the foot collision ellipse is the real movement/contact footprint, not just a wall-clamp helper.

Required runtime uses:

- arena boundary clamp
- player/NPC spacing or separation
- generic foot contact testing
- selection/contact hit testing where practical
- room/lab trigger contact where practical

The debug ellipse, preview ellipse, and runtime contact ellipse must use the same resolved foot collision data.

## 3. Real Build Gaps To Close

### 3.1 Preview Must Be Discoverable

Current UAT issue: the preview exists as a nav row named `Action Preview`, but it does not read as a preview window. Users can miss it.

v0.4.1 requirement:

- Creator Lab must expose a clearly labeled `Preview` surface without requiring users to discover a hidden nav destination.
- The selected sprite realtime preview must be available in a separate left-side floating preview window toggled on/off with `V`.
- The preview surface must show the selected action id, render status, frame index, and overlay legend.
- The floating preview must render a visibly inspectable sprite/placeholder, not only labels or controls.
- Opening Creator Lab should make it obvious how to preview the selected sprite.

### 3.2 Edit And Preview Must Share One Workflow

Current UAT issue: `Foot Collision`, `Hurtboxes`, `Move / ...`, and `Action Preview` are separate nav pages. The preview model updates internally, but users cannot naturally edit collision or boxes while seeing the preview beside the inputs.

v0.4.1 requirement:

- Editing hitbox, hurtbox, and foot collision values must keep the floating preview available without navigating away.
- Foot collision editing must visibly update the foot ellipse without navigating away.
- Hitbox editing must visibly update active-frame hitbox overlays without navigating away.
- Hurtbox editing must visibly update hurtbox overlays without navigating away.
- Preview controls may remain compact, but the preview itself must stay available while editing.

### 3.3 Edited Action Data Must Run In Playground

Current spec caveat: v0.4 Creator Lab edits `data/v0_3/**`, while live combat still reads the older runtime data path. v0.4 proves v0.3 runtime preview and live foot clamp, but not full edited action data running in live Playground combat.

v0.4.1 requirement:

- Selected live player/dummy instances must be able to run edited action data from the v0.3 authoring path.
- Editing move timing, damage, hitbox rect, hitbox active window, or sprite mapping must affect either the selected live instance immediately after apply or after a documented reload/rebind path.
- The implementation must not claim "edited data runs in Playground" if only the Creator Lab internal preview/runtime can see it.

## 4. Product Rules

- Keep saved schema version `0.3` unless a separate schema PR explicitly changes it.
- Do not reintroduce legacy `action`, `attack`, `base_action_set`, `base_actions`, or `base_attack_moves` fields.
- Do not add final art generation, PixelLab API calls, weapons, projectiles, stamina, mana, combo trees, or paper-doll clothing in v0.4.1.
- Placeholder-backed actions are acceptable, but placeholder status must be explicit.
- The build must keep the v0.4 tests green while adding v0.4.1 coverage.

## 5. Acceptance Criteria

v0.4.1 is complete when all are true:

- Required catalog contains all 22 issue #13 actions.
- The seven formerly deferred actions are required, visible, previewable, and covered by diagnostics.
- Action Coverage reports 22 rows.
- Wardrobe coverage reports all 22 action mappings/statuses through the shared coverage engine.
- Restored actions have non-empty visual roles and frozen v0.3-compatible state contexts.
- Missing or placeholder restored actions are visibly marked.
- Preview is clearly discoverable as a `Preview` surface.
- `V` toggles a separate left-side floating selected-sprite preview window on and off.
- The floating preview renders the selected sprite/placeholder large enough for UAT inspection.
- Preview remains visible while editing foot collision.
- Preview remains visible while editing hurtboxes.
- Preview remains visible while editing selected move hitboxes.
- Foot collision drives arena clamp and at least one additional real runtime contact behavior, preferably player/NPC spacing.
- Foot collision contact uses the same ellipse as debug draw and preview draw.
- Selected player and selected dummy both use resolved foot collision data.
- Edited move timing or hitbox data can be applied to a live Playground instance and observed in runtime behavior.
- Existing v0.4 validation and smoke tests still pass.

## 6. Required Verification

Required commands:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
```

New v0.4.1 verification must also prove:

```text
22-action catalog coverage
formerly deferred actions visible in UI coverage
preview visible while editing foot collision/hurtbox/hitbox
foot collision contact behavior beyond arena clamp
edited v0.3 action data running in live Playground
```

Manual UAT:

- Open Creator Lab and identify the preview surface without using source knowledge.
- Bind player and dummy.
- Select each restored action category: locomotion, combat, utility/debug.
- Edit foot collision radius and see preview update while the inputs remain visible.
- Increase foot radius and verify runtime spacing/contact behavior changes.
- Edit a move hitbox and verify live Playground behavior changes after apply/reload.
