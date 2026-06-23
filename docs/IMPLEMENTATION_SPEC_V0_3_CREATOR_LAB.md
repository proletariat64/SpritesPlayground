# Implementation Spec: Creator Lab v0.3 Integration

Status: ready for coding

Source of truth:

- `docs/PRD_v0.3.md`
- `docs/CREATOR_LAB_V0_3_STRUCTURE.md`
- `data/schemas/v0_3/*.schema.json`
- `data/v0_3/**`

## 1. Goal

Build the next coding milestone: a v0.3 Creator Lab integration path that edits and validates the frozen PRD v0.3 data model.

The work should move from the current v0.3 foundation into a usable Godot editor workflow:

```text
v0.3 JSON data
-> Creator Lab v0.3 UI
-> save/reload exact check
-> v0.3 runtime slice
-> validation and smoke tests
```

## 2. Current Baseline

Already completed:

- Clean PRD v0.3 document.
- Creator Lab v0.3 UI structure document.
- JSON Schema contract for CharacterTemplate, MoveTemplate, SpriteSet, and FrameEvent.
- Minimal v0.3 fixtures for `combat_gray_s64`.
- Independent v0.3 runtime simulator.
- Python schema/reference validation.
- Godot headless v0.3 runtime smoke.
- Existing v0.2 runtime smoke still passes.

Important boundary:

- Existing `CreatorLabPanel` and existing playground runtime still use v0.2-era fields.
- v0.3 data must be integrated without pretending the old panel is already v0.3.

## 3. In Scope

### 3.1 Creator Lab v0.3 Panel

Add a new v0.3-specific panel rather than rewriting the old one in place.

Preferred file:

```text
godot/scripts/creator_lab_v0_3_panel.gd
```

Responsibilities:

- Load `data/v0_3/templates/*.json`.
- Load equipped `data/v0_3/moves/*.json`.
- Load referenced `data/v0_3/sprite_sets/*.json`.
- Edit schema-backed fields only.
- Save modified JSON back to the v0.3 data folders.
- Reload saved JSON and compare exact serialized contents.

### 3.2 Template Lab

Editable fields:

```text
CharacterTemplate.template_id
CharacterTemplate.sprite_set_ref
CharacterTemplate.hp
CharacterTemplate.equipped_moves
```

Required behavior:

- Select existing template.
- Copy template to an editable ID.
- Add/remove equipped moves from existing MoveTemplate IDs.
- Validate `sprite_set_ref` and equipped move references.

### 3.3 Box Editor

Editable fields:

```text
CharacterTemplate.hurtboxes
CharacterTemplate.foot_collision
MoveTemplate.hitboxes
MoveTemplate.hitboxes[].active_window
```

Required behavior:

- Edit hurtbox rect values.
- Edit foot collision center/radius.
- Edit selected move hitbox rect.
- Edit selected move hitbox active frame window.

### 3.4 Move Lab

Editable fields:

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

Required behavior:

- Select a move from equipped moves.
- Edit frame count and active window in frames.
- Edit damage and hitstop in frames.
- Toggle `multi_hit`.
- Add/edit/remove frame events for the supported event types.

`multi_hit` implementation boundary:

- Treat `multi_hit` as the Move-level flag for a multi-stage combat move.
- It is the only permission for one Move execution to hit the same target more than once.
- Do not add `hit_windows` in this milestone.
- Do not infer multiple damage events from multiple simultaneous hitboxes.
- Do not add combo logic.

Supported event types for this milestone:

```text
enable_hitbox
disable_hitbox
set_velocity
change_state_context
apply_hitstop
```

### 3.5 Wardrobe

Editable fields:

```text
SpriteSet.sprite_set_id
SpriteSet.animation_clips
SpriteSet.frame_sequences
SpriteSet.required_moves_mapping
```

Required behavior:

- Show whether every equipped move has a mapping.
- Show whether every mapped clip exists.
- Show whether every clip has a frame sequence.
- Do not let Wardrobe define gameplay.

### 3.6 Playground Runtime Integration

Use the v0.3 runtime slice as the integration target.

Existing files:

```text
godot/scripts/prd_v0_3_data_store.gd
godot/scripts/prd_v0_3_runtime.gd
```

Required behavior:

- Preview selected template through v0.3 runtime state.
- Expose current state, current move, current frame, hitstop frames, hurtboxes, active hitboxes, and foot collision.
- Keep old v0.2 runtime smoke passing while the v0.3 panel is introduced.

## 4. Out of Scope

Do not do these in this milestone:

- Do not expand PRD v0.3.
- Do not add a combo system.
- Do not add new states.
- Do not reintroduce `action`, `attack`, `base_action_set`, `base_actions`, or `base_attack_moves`.
- Do not add seconds-based gameplay timing.
- Do not delete the old v0.2 runtime until v0.3 UI integration is verified.
- Do not generate or import new art assets.
- Do not build a full final game loop.

## 5. Implementation Strategy

### Phase 1: Data Access

Extend or add v0.3 data-store helpers for:

```text
list_template_ids
list_move_ids
list_sprite_set_ids
save_template
save_move
save_sprite_set
duplicate_template
```

Keep these helpers separate from the old `CreatorDataStore` unless a migration decision is made.

### Phase 2: Panel Shell

Create `CreatorLabV03Panel`.

Minimum UI:

```text
top row: template select / copy / save / reload / validate
tabs: Template / Box / Move / Wardrobe / Runtime
status row: validation result
```

The panel should be compact and tool-like, matching the current playground style.

### Phase 3: Field Editors

Implement editors in this order:

1. Template fields.
2. Hurtboxes and foot collision.
3. Move scalar fields.
4. Hitbox rect and active window.
5. Frame events.
6. SpriteSet mapping coverage.

### Phase 4: Runtime Preview

Wire selected data into `PrdV03Runtime`.

Minimum preview behavior:

- Start selected move.
- Advance one frame.
- Advance N frames.
- Reset to idle.
- Show active hitboxes and hitstop.

### Phase 5: Save/Reload Exactness

After save:

1. Reload the JSON files.
2. Serialize panel state and reloaded state.
3. Compare exact normalized JSON strings.
4. Show PASS/FAIL in panel status.

### Phase 6: Tests

Extend headless smoke coverage rather than relying on manual UI testing.

Preferred test file:

```text
tools/creator_lab_v0_3_smoke.gd
```

Required checks:

- Panel can load `combat_gray_s64`.
- Panel can edit a copied template without mutating the original.
- Panel can edit one hurtbox.
- Panel can edit foot collision.
- Panel can edit `basic_punch` frame window, damage, hitstop, hitbox rect, and events.
- Save/reload exact check passes.
- `python3 tools/validate_prd_v0_3.py` passes after edits.
- `tools/prd_v0_3_runtime_smoke.gd` passes after edits.
- Old `tools/runtime_smoke.gd` still passes.

## 6. Acceptance Criteria

The milestone is complete when all are true:

- A v0.3 Creator Lab panel exists and loads v0.3 data.
- Editing is schema-backed and does not create legacy fields.
- Save/reload exact check passes.
- Wardrobe coverage check reports equipped move mapping state.
- Runtime preview uses `PrdV03Runtime`.
- All verification commands pass.

Required verification commands:

```bash
python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
gitnexus detect_changes --repo SpritesPlayground
```

## 7. GitNexus Workflow

Before editing any existing function, class, or method:

```bash
gitnexus impact <symbol> --repo SpritesPlayground
```

Before commit or handoff:

```bash
gitnexus detect_changes --repo SpritesPlayground
```

If a command complains about multiple repositories, always pass:

```text
--repo SpritesPlayground
```

If the target file is newly added and not yet tracked, remember that GitNexus change detection may not fully account for it until the file is staged or committed.

## 8. Migration Decision Point

After the v0.3 panel passes smoke tests, decide one of these routes:

```text
Route A: keep v0.2 and v0.3 panels side by side temporarily
Route B: replace old CreatorLabPanel with CreatorLabV03Panel
Route C: keep old runtime only as regression smoke, but make v0.3 the default UI path
```

The default recommendation is Route A until the v0.3 UI proves stable.
