# PRD v0.4.2: Playground Multi-NPC and Preview Controls

Status: add-on PRD for UAT gap closure after v0.4.1

Source of truth:

- `docs/PRD_v0.4_ACTION_AUTHORING_TOOL.md`
- `docs/PRD_v0.4.1_ACTION_AUTHORING_TOOL_ADDON.md`
- `docs/IMPLEMENTATION_SPEC_V0_4_ACTION_AUTHORING_TOOL.md`
- `docs/IMPLEMENTATION_SPEC_V0_4_1_ACTION_AUTHORING_TOOL_ADDON.md`
- Current UAT gap audit on branch `feature/creator-lab-action-authoring-v1`

## 1. Purpose

v0.4 and v0.4.1 made Creator Lab usable for selected-instance action authoring, coverage, live apply, and basic preview. v0.4.2 closes the next UAT gaps that appear once foot collision and live Playground authoring are active:

```text
depth-correct multi-character rendering
+ screen controls for NPC count and NPC template spawning
+ complete frame inspection for the selected action preview
```

This add-on does not replace v0.4 or v0.4.1. It extends the existing v0.3 schema-backed authoring workflow. Saved character, move, and sprite-set JSON remain schema version `0.3`.

## 2. Current Validated Gaps

### 2.1 Character Depth Ordering

Current Playground behavior has fixed child draw order. After character foot collision is introduced, overlapping sprites can visually cover each other incorrectly because draw order does not follow screen depth.

Required v0.4.2 behavior:

- Characters render back-to-front based on their current ground/contact position.
- A character whose foot contact point is lower on screen must render in front of a character whose foot contact point is higher on screen.
- Depth order must update after movement, arena clamp, and foot separation.
- Jump visual offset must not make an airborne character sort as if its feet moved vertically through the arena.
- Debug overlays for hurtboxes, hitboxes, and foot collision must remain aligned with the character that owns them.

Implementation may use Godot y-sort, explicit `z_index`, child ordering, or a dedicated character layer, but the result must be deterministic and testable.

### 2.2 NPC Count and Template Spawning

Current Playground has one fixed player and one fixed dummy. UAT needs a Playground surface that can add and remove NPCs while preserving at least one NPC.

Required v0.4.2 behavior:

- Playground starts with one player and at least one NPC.
- User can add NPCs from the screen while the game is running.
- User can remove NPCs from the screen while the game is running.
- NPC count is bounded:
  - minimum NPC count: `1`
  - maximum NPC count: `10`
- Removing an NPC at the minimum count is blocked with visible status feedback.
- Adding an NPC at the maximum count is blocked with visible status feedback.
- User can choose a sprite/template before spawning an NPC.
- Every spawned NPC has a stable unique `instance_id`.
- Spawned NPCs are selectable/bindable in Creator Lab.
- Spawned NPCs participate in movement clamp, foot spacing, hit detection, damage, debug boxes, reset, and selected-instance summary.

The first implementation only needs to expose templates from `data/v0_3/templates`. If only one template exists, the selector still appears and defaults to that template.

### 2.3 Complete Preview Frame Inspection

Current preview has play, pause, `+1`, reset, and status text. UAT still needs a clear way to see and choose the full frame sequence for the selected action/move.

Required v0.4.2 behavior:

- Preview exposes the full frame range for the selected action.
- User can select previous and next frames.
- User can select first and last frames.
- User can scrub or choose a specific frame without repeatedly pressing `+1`.
- User can play the selected action frames.
- User can pause playback.
- User can see the current frame index and total frame count.
- User can tell which frame is active in the frame strip/timeline.
- Playback must advance beyond frame `0` for multi-frame actions.
- When the selected action changes, the preview clamps to a valid frame and refreshes the frame strip.
- Placeholder, missing, and real texture frames must all appear as inspectable frame states.

Backward frame stepping and frame-strip/timeline UI are no longer out of scope for v0.4.2.

## 3. Product Rules

- Keep saved schema version `0.3`.
- Do not add per-instance saved override schema.
- Do not add final art generation, PixelLab calls, weapons, projectiles, combo systems, stamina, mana, or paper-doll clothing.
- Do not replace the compact three-panel Creator Lab model.
- Do not make physics bodies a requirement unless a later implementation proves they are needed.
- Do not claim multi-NPC support if only the fixed dummy path works.
- Do not claim complete preview frame inspection if preview can only step forward one frame at a time.

## 4. Acceptance Criteria

v0.4.2 is complete when all are true:

- Playground renders overlapping characters in correct back-to-front screen-depth order.
- Depth order updates after movement, clamp, and foot-spacing resolution.
- Depth order uses ground/foot contact position, not sprite jump offset.
- Playground starts with exactly one player and at least one NPC.
- UI exposes add NPC and remove NPC controls.
- UI exposes a template selector for NPC spawn.
- Adding NPCs works until there are 10 NPCs.
- Removing NPCs works until there is 1 NPC.
- Add/remove limit failures show visible status feedback and do not mutate the character list.
- Spawned NPCs have unique stable instance IDs.
- Creator Lab can bind/select each spawned NPC.
- Pairwise foot spacing works across player plus all NPCs.
- Pairwise hit detection works across player plus all NPCs.
- Reset restores all live characters to valid arena positions.
- Debug HUD shows NPC count and selected instance.
- Preview shows full frame count for selected action.
- Preview supports previous frame.
- Preview supports next frame.
- Preview supports first frame.
- Preview supports last frame.
- Preview supports frame scrub or direct frame selection.
- Preview play advances beyond the first frame for a multi-frame action.
- Preview pause stops frame advancement.
- Preview frame strip/timeline highlights the selected frame.
- Existing v0.4.1 validation and smoke tests remain green.

## 5. Required Verification

Required existing checks:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
```

New v0.4.2 verification must also prove:

```text
depth_order_follows_foot_y
npc_count_min_1_max_10
npc_template_spawn_and_bind
pairwise_spacing_all_characters
pairwise_hits_all_characters
preview_previous_next_first_last
preview_scrub_selects_frame
preview_play_advances_multi_frame_action
preview_pause_stops_advancement
```

Manual UAT:

- Launch Playground.
- Move player in front of and behind an NPC; confirm visual order changes correctly.
- Add NPCs until the maximum is reached; confirm the 11th add is blocked.
- Remove NPCs until one remains; confirm deleting the final NPC is blocked.
- Spawn at least one NPC through the template selector.
- Bind/select player and each NPC in Creator Lab.
- Open Preview for a multi-frame action such as `basic_punch`.
- Use previous, next, first, last, and scrub controls.
- Press Play and confirm the preview advances beyond frame 1.
- Press Pause and confirm the current frame stops changing.
