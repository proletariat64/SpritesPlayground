# PRD: Creator Lab Action Authoring Tool v1

Status: polished draft for issue #13 / next wave after PR12

Source of truth:

- GitHub issue #13: Next Wave: Creator Lab Action Authoring Tool v1
- `docs/PRD_v0.3.md`
- `docs/CREATOR_LAB_V0_3_STRUCTURE.md`
- `docs/IMPLEMENTATION_SPEC_V0_3_CREATOR_LAB.md`
- `data/schemas/v0_3/*.schema.json`
- `data/v0_3/**`

## 1. Product Definition

Creator Lab Action Authoring Tool v1 turns the current v0.3 schema-backed JSON editor into a practical Godot authoring workflow for 2D pixel action-game characters.

It is not:

- a form-only JSON editor
- a final game editor
- a sprite generation pipeline
- a full combat-system rewrite

It is:

```text
a selected-character action authoring lab
+ live sprite preview
+ schema-backed editing
+ runtime behavior validation
+ action coverage diagnostics
```

## 2. Product Goal

Build one complete developer workflow:

```text
select active sprite instance in Playground
-> bind Creator Lab to selected player/NPC/template
-> select action coverage entry or move
-> preview animation live
-> edit timing / boxes / sprite mapping
-> see result update immediately
-> save JSON
-> reload JSON
-> run edited data in Playground
-> validate action completeness and runtime behavior
```

The developer must be able to answer without inspecting raw JSON:

- Which character instance am I editing?
- Which template and sprite set is it using?
- Which action coverage entry or move is selected?
- Does the animation look correct?
- Are hurtboxes, hitboxes, and foot collision aligned with the visible sprite?
- Does edited foot collision change actual runtime behavior?
- Are important action states missing, placeholders, duplicated, or fake?
- Does death, knockdown, and hurt look different from idle?

## 3. Design Rules

The v0.3 frozen model remains the base:

```text
State = control mode
Move = gameplay
Frame = time
Event = trigger
```

The state model is frozen to the v0.3 enum:

```text
idle
walk
dash
jump
hurt
dead
```

This wave does not add states. The required action catalog is an authoring/coverage catalog over v0.3 `MoveTemplate` and `SpriteSet` data. Catalog entries are not new states and do not create gameplay by themselves.

This wave stays on schema version `0.3`. Visual-role metadata, required-action coverage, and placeholder detection are derived diagnostics, not new schema fields.

This wave must not undo the v0.3 rules:

- Do not reintroduce legacy `action`, `attack`, `base_action_set`, `base_actions`, or `base_attack_moves` fields.
- Do not create seconds-based timing.
- Do not make animation names define gameplay.
- Do not add a combo tree or weapon/projectile system.
- Do not hide schema ownership.

Creator Lab UI rules:

- Keep the fixed three-panel editor model.
- Organize controls by real ownership: character-owned, move-owned, sprite-set-owned, runtime-only.
- Keep controls compact enough for future preview space.
- Prefer two compact inputs or dropdowns per row when labels remain readable.
- Use visual proof: editing a value must update the relevant preview before the user has to infer the result from JSON.
- Use color to make key information readable: hurtbox, hitbox, foot collision, selected instance, placeholder, missing, invalid, and pass/fail states must be visually distinct.

## 4. Selected Instance Model

The Playground must support selecting the active sprite/character instance.

Selection must support:

- player-controlled character instance
- NPC, dummy, or AI-controlled character instance

Initial selection may be either:

- direct Playground click selection, or
- an explicit Creator Lab bind control such as `Bind Player` / `Bind Dummy`

The implementation must choose the shortest reliable path. Direct click selection is not required if an explicit bind control provides the same selected-instance result.

Required selected-instance debug fields:

```text
selected instance id
template id
sprite set id
current state
current move/action
current frame
HP
AI/manual mode
```

Required behavior:

- Selecting an instance binds Creator Lab to that instance.
- Creator Lab preview reflects selected instance data.
- Edits apply to the selected instance's resolved template data path where practical.
- Saved template edits remain template-level edits in this wave.
- If player and NPC share the same template, a saved template edit affects both after reload/rebind.
- Per-instance saved overrides are out of scope for this wave.
- The debug HUD clearly shows selected instance id, template id, sprite set id, current state, current move/action, current frame, HP, and AI/manual mode.
- The system does not assume there is only one editable player.
- Player and NPC instances can both be inspected and previewed.

## 5. Realtime Preview

Creator Lab must include a realtime preview window for the selected action coverage entry or move.

Required preview controls:

- play / pause
- frame step forward
- reset to first frame / idle
- playback speed: `0.5x` and `1x`
- current frame index and total frame count
- overlay toggles for hurtbox, hitbox, and foot collision

Required preview rendering:

- selected sprite animation when a real frame sequence exists
- labeled placeholder preview when the resolved frame sequence uses `placeholder://` frames
- missing/invalid preview state when no frame sequence can be resolved
- origin / foot-center ground point
- ground line
- hurtbox overlay
- hitbox overlay
- foot collision ellipse overlay
- active-frame highlight
- placeholder/missing/invalid animation status

Placeholder preview does not need final art. It may render a labeled colored rectangle or simple calibration silhouette that preserves frame count, origin, ground line, and overlay geometry.

Preview must update immediately when these values change:

- frame count
- active frame window
- hitbox rect
- hurtbox rect
- foot collision center/radius
- sprite sequence mapping
- animation clip path / placeholder mapping

## 6. Required Action Catalog

The action list must move beyond `basic_punch` and `basic_kick`, but it must not create new states.

The catalog lives in one static required-action definition, preferably a code/data constant loaded by Creator Lab diagnostics. It is not stored inside `CharacterTemplate`, `MoveTemplate`, or `SpriteSet`.

Each catalog entry must define:

```text
action_id
category
visual_role
state_context
backing
required_this_wave
```

`state_context` must be one of the six frozen v0.3 states. `backing` describes whether the catalog entry is backed by a concrete move id or is a visual coverage entry over an existing move.

Required v1 catalog:

| action_id | category | state_context | backing |
| --- | --- | --- | --- |
| idle | utility | idle | move:idle |
| walk | locomotion | walk | move:walk |
| dash | locomotion | dash | move:dash |
| jump_start | locomotion | jump | coverage:jump |
| jump_air | locomotion | jump | coverage:jump |
| jump_land | locomotion | jump | coverage:jump |
| basic_punch | combat | idle | move:basic_punch |
| basic_kick | combat | idle | move:basic_kick |
| dash_attack | combat | dash | move-or-placeholder:dash_attack |
| jump_attack | combat | jump | move-or-placeholder:jump_attack |
| hurt_light | reaction | hurt | coverage-or-move:hurt_light |
| hurt_heavy | reaction | hurt | coverage-or-move:hurt_heavy |
| knockdown | reaction | hurt | coverage-or-move:knockdown |
| get_up | reaction | hurt | coverage-or-move:get_up |
| dead | reaction | dead | coverage-or-move:dead |

Deferred catalog entries:

```text
run
turn
heavy_punch
round_kick
guard
stun
win_pose
```

These are intentionally deferred from v1 because they do not prove the core authoring loop. They may be added after live preview, duplicate-idle diagnostics, and foot-collision runtime proof are working.

Allowed animation states:

```text
valid animation
missing animation
placeholder animation
invalid mapping
duplicated/fake mapping
```

Placeholder convention:

- No new schema field is added for placeholders.
- A frame sequence is a placeholder if any frame path begins with `placeholder://`.
- A shared placeholder sequence is enough for v1.
- Any clip resolving to a placeholder frame sequence must show `PLACEHOLDER_ANIMATION`.

## 7. Action Completeness Panel

Creator Lab must show one action completeness panel or table. Wardrobe may expose this same information from the sprite-set side, but it must use the same coverage engine and must not become a second source of truth.

For every required catalog entry, show:

- action id
- category
- backing move or coverage target
- state context
- move definition exists when backing is move-based
- animation clip mapping
- frame sequence exists
- frame count
- placeholder/missing/valid status
- visual role
- validation warning if broken

Example shape:

```text
Action          Clip          Frames   Status
idle            idle          6        OK
walk            walk          8        OK
basic_punch     punch         8        OK
knockdown       missing       0        MISSING_ANIMATION
dead            idle          6        DUPLICATE_IDLE_FOR_DEAD_STATE
jump_attack     placeholder   8        PLACEHOLDER_ANIMATION
```

Coverage rules:

- Resolve `required_moves_mapping[action_id]` to a clip id.
- Resolve that clip id in `animation_clips`.
- Resolve `animation_clips[clip_id].frame_sequence_ref` in `frame_sequences`.
- Compare the resolved sequence length to the backing move's `frame_count` when a backing move exists.
- Compare important reaction/death mappings against idle to detect fake idle reuse.

Coverage status is not gameplay. It is an authoring diagnostic over catalog, template, move, and sprite-set data.

## 8. Visual Role Validation

Important states must not silently look identical.

Every required catalog entry must have a visual role. Visual-role descriptions are human reference text for authors. In this wave, validation is deterministic data validation, not computer vision.

Required visual roles:

```text
idle = upright neutral loop
walk = locomotion loop
dash = forward burst pose
jump_start = takeoff pose
jump_air = airborne pose
jump_land = landing pose
basic_punch/basic_kick = attack pose
dash_attack/jump_attack = context attack pose
hurt_light = short recoil
hurt_heavy = strong recoil
knockdown = falling/down pose
get_up = rising transition
dead = final defeated pose
```

Required warning codes and deterministic triggers:

| Code | Trigger |
| --- | --- |
| `MISSING_ANIMATION` | Required catalog entry cannot resolve any clip through `required_moves_mapping` and `animation_clips`. |
| `PLACEHOLDER_ANIMATION` | Resolved frame sequence contains at least one frame path beginning with `placeholder://`. |
| `DUPLICATE_IDLE_FOR_DAMAGE_STATE` | `hurt_light` or `hurt_heavy` resolves to the same `(clip_id, frame_sequence_ref)` as `idle`. |
| `DUPLICATE_IDLE_FOR_DEAD_STATE` | `dead` resolves to the same `(clip_id, frame_sequence_ref)` as `idle`. |
| `DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE` | `knockdown` resolves to the same `(clip_id, frame_sequence_ref)` as `idle`. |
| `WRONG_FRAME_COUNT` | Backing move `frame_count` differs from the resolved frame sequence length. |
| `MISSING_FRAME_SEQUENCE` | Resolved clip points to a `frame_sequence_ref` that does not exist in `frame_sequences`. |
| `MISSING_VISUAL_ROLE` | Required catalog entry has no non-empty `visual_role`. |
| `INVALID_SPRITE_MAPPING` | `required_moves_mapping[action_id]` is missing, empty, or points to an unknown clip id. |

Multiple warnings may be emitted for one action when multiple rules fail.

## 9. Move Lab Editing

Move Lab must support real editing for selected moves, not display-only inspection.

Editable fields where schema supports them:

```text
MoveTemplate.move_type
MoveTemplate.state_context_override
MoveTemplate.frame_count
MoveTemplate.active_window
MoveTemplate.damage
MoveTemplate.hitstop_frames
MoveTemplate.multi_hit
MoveTemplate.hitboxes
MoveTemplate.hitboxes[].active_window
MoveTemplate.events
FrameEvent.frame
FrameEvent.event_type
FrameEvent.payload
```

Required behavior:

- Select a move from equipped moves or from a catalog entry backed by a move.
- Edit `move_type` from the v0.3 enum: `locomotion`, `combat`, `reaction`, `utility`.
- Edit `state_context_override` from the frozen state enum where the schema allows it.
- Edit frame count and active window in frames.
- Edit damage and hitstop in frames.
- Toggle `multi_hit`.
- Edit move-owned hitbox rect and active window.
- Edit frame events supported by the v0.3 schema.
- Live preview reflects Move Lab edits immediately.
- Multi-hit remains a move-level permission, not an implicit result of multiple overlapping hitboxes.

## 10. Foot Collision Runtime Behavior

The foot collision ellipse must be the real runtime shape used for arena boundary clamp. This is the only required runtime behavior for v1.

Required behavior:

- The debug foot ellipse and the arena-clamp ellipse use the same resolved data.
- Moving the foot collision ellipse changes where the character is clamped against the arena boundary.
- Making the ellipse larger changes observable wall/boundary proximity.
- Making the ellipse smaller changes observable wall/boundary proximity.
- Offsetting the ellipse changes the observable ground/contact point used by the clamp.
- Player and NPC instances each use the foot collision data resolved from their bound template.
- If player and NPC share the same template, they share the saved foot collision after reload/rebind.

Out of scope for v1:

- per-instance saved foot-collision overrides
- player/NPC spacing
- room trigger or lab trigger contact
- selection/contact hit testing
- a separate hidden collision shape for the same purpose

## 11. Wardrobe Coverage

Wardrobe becomes a sprite-set view of the same action coverage data described in Section 7.

Wardrobe must show:

- current sprite set id
- required catalog entries
- action-to-clip mapping
- missing animations
- placeholder animations
- invalid mappings
- frame sequence presence
- frame count consistency

Wardrobe rules:

- Wardrobe validates sprite-set coverage through the shared coverage engine.
- Wardrobe does not define gameplay.
- Wardrobe generation entry remains a stub.
- No real PixelLab API call is part of this wave.

## 12. Save/Reload Exactness

All edited template, move, and sprite-set mapping data must save and reload exactly.

Required behavior:

- Save writes schema-backed JSON only.
- Reload rehydrates the saved JSON.
- Roundtrip compares normalized saved and reloaded data.
- Roundtrip still reports PASS/FAIL.
- Edited values must not disappear after reload.
- Validation failures must be visible.
- Unsafe saves must be blocked when validation fails.

## 13. Playground Integration

Edited template/action data must be runnable or previewable from Playground.

Required behavior:

- Selected active sprite instance reflects edited data when practical.
- Runtime debug HUD shows selected instance data.
- Existing runtime smoke remains green.
- Creator Lab open/close must not leave gameplay keyboard input captured by stale UI controls.
- F5/editor launch is a required UAT path.

Input focus is a product requirement:

- Gameplay input works after F5 launch from the Godot editor.
- Gameplay input works after opening and closing Creator Lab.
- Creator Lab text/dropdown controls may take focus while editing.
- Closing Creator Lab releases GUI focus back to gameplay.
- Smoke coverage must include the Creator Lab close-focus path.

Standalone launch is a useful manual check, but it is not a required acceptance gate for this wave.

## 14. Out of Scope

Do not include these in this wave:

- real PixelLab API call
- real AI image generation
- weapon system
- projectile system
- stamina/mana
- full combo tree
- paper-doll clothing editor
- final game levels
- runtime architecture rewrite
- long document maze
- new saved per-instance override schema
- new gameplay states beyond the frozen v0.3 state enum

## 15. Acceptance Criteria

The wave is complete when all are true:

- Playground can select or explicitly bind the active player sprite instance.
- Playground can select or explicitly bind an active NPC/dummy/AI sprite instance.
- Creator Lab clearly shows selected instance id, template id, sprite set id, current state, current move/action, current frame, HP, and AI/manual mode.
- Creator Lab binds preview/editing to the selected active instance/template.
- Realtime preview window renders selected action animation or an explicit placeholder/missing preview state.
- Preview supports play/pause.
- Preview supports frame step forward.
- Preview supports reset to first frame / idle.
- Preview supports `0.5x` and `1x` playback speed.
- Preview shows current frame index and total frame count.
- Preview shows origin/foot-center and ground line.
- Preview can toggle hurtbox overlay.
- Preview can toggle hitbox overlay.
- Preview can toggle foot collision ellipse overlay.
- Editing hitbox/hurtbox/foot collision values updates preview immediately.
- Required v1 action catalog exists as derived diagnostic data, not as new v0.3 schema fields.
- Action completeness panel lists required locomotion, combat, damage/recovery, and utility entries from the catalog.
- Missing animations are visible with `MISSING_ANIMATION`.
- Placeholder animations are visible with `PLACEHOLDER_ANIMATION`.
- Invalid sprite mappings are visible with `INVALID_SPRITE_MAPPING`.
- Missing frame sequences are visible with `MISSING_FRAME_SEQUENCE`.
- Wrong frame counts are visible with `WRONG_FRAME_COUNT`.
- Missing visual roles are visible with `MISSING_VISUAL_ROLE`.
- `dead` cannot silently look like `idle` without `DUPLICATE_IDLE_FOR_DEAD_STATE`.
- `knockdown` cannot silently look like `idle` without `DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE`.
- `hurt_light` and `hurt_heavy` cannot silently look like `idle` without `DUPLICATE_IDLE_FOR_DAMAGE_STATE`.
- Move Lab can edit selected move timing/combat values supported by schema.
- Move Lab can edit `move_type` and `state_context_override` where schema supports them.
- Move Lab can edit selected move-owned hitbox data.
- Live preview reflects Move Lab edits.
- Foot collision ellipse affects actual arena boundary clamp behavior.
- Player and NPC both use the foot collision data resolved from their bound template.
- Debug foot ellipse matches the real runtime clamp ellipse.
- Wardrobe shows full sprite-set action coverage through the shared coverage engine.
- Wardrobe generation entry remains stub only.
- Save/reload exact roundtrip passes for edited data.
- Validation failures visibly block unsafe save.
- Edited data can run or preview from Playground.
- Gameplay keyboard input works after F5/editor launch and after Creator Lab close.
- Existing runtime smoke still passes.

## 16. Required Verification

Required commands:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
npx gitnexus analyze
gitnexus detect_changes --repo SpritesPlayground --scope compare --base-ref main
```

Manual UAT must include:

- F5 launch from Godot editor.
- Bind/select player instance.
- Bind/select NPC/dummy instance.
- Open Creator Lab, edit a numeric box, close Creator Lab, confirm gameplay input works.
- Edit foot collision radius and verify arena boundary clamp changes.
- Mark a required action as missing or placeholder and verify coverage table status changes.
- Map `dead`, `knockdown`, or `hurt_*` to idle and verify duplicate-idle warnings appear.

## 17. Suggested Implementation Slices

The implementation should be split into small PRs:

1. Selected instance bind control and debug HUD.
2. Realtime preview shell with overlays, play/pause, forward step, reset, and `0.5x`/`1x` speed.
3. Required action catalog constants and placeholder fixture convention.
4. Shared completeness engine, panel, and deterministic warning tests.
5. Move Lab live editing improvements, including `move_type` and `state_context_override`.
6. Foot collision arena-clamp proof using the same ellipse as debug draw.
7. Wardrobe coverage view backed by the shared completeness engine.
8. Save/reload, validation-blocked save, input-focus smoke, and UAT hardening.

Each PR must preserve existing verification commands and should add targeted smoke coverage for the behavior it changes.

## 18. Resolved Product Decisions

These decisions are fixed for the implementation spec:

- Schema stays at `0.3`; this wave adds derived diagnostics and UI behavior, not new JSON schema fields.
- Visual-role metadata lives in one required-action catalog constant or data file, not in templates, moves, or sprite sets.
- The first real foot-collision runtime behavior is arena boundary clamp only.
- `jump_start`, `jump_air`, and `jump_land` are coverage catalog entries over jump-state data, not new states.
- Placeholders are detected by `placeholder://` frame paths in frame sequences.
- Explicit bind controls are acceptable for player/NPC selection if click selection is slower or riskier.
- Standalone launch UAT is deferred; F5/editor launch is the required focus path for this wave.
