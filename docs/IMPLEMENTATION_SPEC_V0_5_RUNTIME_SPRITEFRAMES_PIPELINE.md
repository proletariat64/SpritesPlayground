# Implementation Spec v0.5: Runtime SpriteFrames Pipeline

Status: implementation plan for `docs/PRD_v0.5_RUNTIME_SPRITEFRAMES_PIPELINE.md`

Source of truth:

- `docs/PRD_v0.5_RUNTIME_SPRITEFRAMES_PIPELINE.md`
- GitHub issue #15 and comments
- Godot stable documentation:
  - `SpriteFrames`: https://docs.godotengine.org/en/stable/classes/class_spriteframes.html
  - `AnimatedSprite2D`: https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html
  - `ResourceSaver`: https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html
- Current implementation in:
  - `godot/scripts/prd_v0_3_data_store.gd`
  - `godot/scripts/creator_lab_v0_3_panel.gd`
  - `godot/scripts/creator_lab_action_preview.gd`
  - `godot/scripts/combat_character.gd`
  - `godot/scripts/playground.gd`

## 1. Goal

Implement the v0.5 animation resource pipeline without turning Creator Lab into an image-processing application:

```text
normalized frame PNG references
+ existing sprite_set.animation_clips/frame_sequences
+ generated SpriteFrames .tres
+ AnimatedSprite2D playback on CombatCharacter
```

The generated resource must make the final Godot scene friendly to real node/resource playback while keeping v0.3 JSON as the authoring source of truth.

## 2. Design Constraints

- Use Godot `SpriteFrames` for generated animation data.
- Use `AnimatedSprite2D` as the runtime sprite playback node.
- Use `ResourceSaver.save(resource, path)` to write `.tres` resources.
- Keep existing v0.3 JSON valid unless a separate schema migration is approved.
- Keep frame sequences as ordered string slots for the first implementation.
- Keep current Creator Lab preview overlays for authoring diagnostics.
- Frame is timing: `move.frame_count` and frame indices are the action timeline.
- Real visual art may be sparse inside that timeline.
- v0.5 requires frame order/index parity between preview and runtime, not playback speed parity.
- Commit normalized Skeleton PNG frames with a license note.
- Commit generated `.tres` resources for approved templates.
- Deliver issue #15 in one PR, using the workstreams below as implementation order.

## 3. Path Conventions

Recommended normalized frame path:

```text
res://godot/assets/frames/<sprite_set_id>/<sequence_id>/frame_000.png
res://godot/assets/frames/<sprite_set_id>/<sequence_id>/frame_001.png
```

Recommended generated resource path:

```text
res://godot/resources/sprite_frames/<sprite_set_id>.tres
```

Recommended placeholder texture path:

```text
res://godot/assets/frame_placeholders/<slot_state>_s64.png
```

Rules:

- `res://godot/assets/frames/**` contains normalized single-frame PNGs after external processing.
- `res://godot/resources/sprite_frames/**` contains generated `SpriteFrames` resources.
- `tmp/asset_research/**` remains ignored prototype material.
- Commit normalized Skeleton frames under the approved `res://godot/assets/frames/**` path.
- Commit a license note next to, or clearly associated with, approved third-party normalized frames.
- Commit generated `.tres` resources for approved templates.
- Real committed `.tres` resources should reference imported textures from `res://` paths.
- If a headless generator embeds `ImageTexture` for ignored/local tmp files, that path is prototype-only and must not define committed behavior.

## 4. Frame Slot Model

Keep `frame_sequences` as arrays of strings for the first v0.5 implementation:

```json
{
  "frame_sequences": {
    "basic_punch": [
      "res://godot/assets/frames/skeleton_default_unarmed_s64/basic_punch/frame_000.png",
      "empty://skeleton_default_unarmed_s64/basic_punch/frame_001.png",
      "missing://skeleton_default_unarmed_s64/basic_punch/frame_002.png",
      "placeholder://skeleton_default_unarmed_s64/basic_punch/frame_003.png"
    ]
  }
}
```

Supported schemes:

| Scheme | Meaning | Generator behavior |
| --- | --- | --- |
| `res://` loadable | Committed/imported real frame | Load as `Texture2D`. |
| `res://` missing/unloadable | Missing real frame | Use visible missing placeholder texture and warn. |
| `user://` | Local UAT real frame | Load as `Texture2D`; always warn that it is local-only. |
| `empty://` | Intentional blank frame | Use transparent placeholder texture. |
| `missing://` | Expected art gap | Use visible missing placeholder texture and warn. |
| `placeholder://` | Current placeholder slot | Use visible placeholder texture and warn unless accepted by test fixture. |

Slot operations:

```gdscript
func insert_empty_frame_slot(sequence_id: String, frame_index: int) -> void
func remove_frame_slot(sequence_id: String, frame_index: int) -> void
func replace_frame_slot(sequence_id: String, frame_index: int, frame_path: String) -> void
func mark_frame_slot(sequence_id: String, frame_index: int, slot_state: String) -> void
```

Timing rule:

- Insert is blocked until the user chooses whether to shift affected `move.frame_count`, `active_window`, hitbox windows, and events.
- Delete is blocked when the target frame is referenced by `active_window`, hitbox windows, or events.
- Reorder is out of scope for v0.5.
- Preview and validation must never silently hide trailing move-only frames.

Sparse real-frame rule:

- A move may have 8 action timing frames while only 3 slots contain real visual art.
- Example: frame `0` is start, frame `3` is hit, frame `7` is end.
- Frames `1`, `2`, `4`, `5`, and `6` may be `empty://`, `missing://`, or `placeholder://`.
- This is valid authoring data and must not fail generation.
- The generated runtime resource and preview must preserve the action timeline positions so boxes and events still align to frame indices.

## 5. SpriteFrames Generator

Add a generation module:

```text
godot/scripts/spriteframes_generator.gd
```

Recommended class:

```gdscript
extends RefCounted
class_name SpriteFramesGenerator

const DEFAULT_ANIMATION_FPS := 12.0
const GENERATED_RESOURCE_ROOT := "res://godot/resources/sprite_frames"

static func sprite_frames_path(sprite_set_id: String) -> String
static func generate(sprite_set: Dictionary, options: Dictionary = {}) -> Dictionary
static func load_generated(sprite_set_id: String) -> SpriteFrames
static func validate_generated(sprite_set: Dictionary) -> Array
```

`generate()` returns:

```gdscript
{
    "ok": true,
    "path": "res://godot/resources/sprite_frames/skeleton_default_unarmed_s64.tres",
    "warnings": [],
    "errors": [],
    "animation_names": ["idle", "walk", "run", "basic_punch", "hurt"],
}
```

Generation algorithm:

1. Validate `sprite_set_id`.
2. Create `SpriteFrames.new()`.
3. Clear default animation if present and not needed.
4. For each `animation_clips` key in deterministic sorted order:
   - read `clip_id`
   - read `frame_sequence_ref`
   - read `loop`
   - read `fps` or use `DEFAULT_ANIMATION_FPS`
   - add animation using `add_animation(clip_id)`
   - set loop and speed metadata
   - resolve the frame sequence
   - add one texture per frame slot using `add_frame()`
5. Save to `sprite_frames_path(sprite_set_id)` with `ResourceSaver.save()`.
6. Reload the saved resource with `ResourceLoader.load()`.
7. Validate animation names, timeline frame counts, loop flags, warnings, and loadability.

Texture resolution:

```gdscript
static func _texture_for_slot(slot: String, context: Dictionary) -> Texture2D
```

Rules:

- `res://` and `user://` must load as `Texture2D`.
- Missing or unloadable `res://` slots use the missing placeholder texture and record a warning.
- `user://` slots always record a local-only warning.
- `empty://` maps to transparent placeholder.
- `missing://` maps to visible missing placeholder.
- `placeholder://` maps to visible placeholder.
- Unknown schemes return an error.
- Generation succeeds when sparse real art is mixed with empty/missing/placeholder timing slots.

Godot API reference points:

- `SpriteFrames.add_animation(anim)`
- `SpriteFrames.add_frame(anim, texture, duration, at_position)`
- `SpriteFrames.get_animation_names()`
- `SpriteFrames.get_frame_count(anim)`
- `SpriteFrames.get_frame_texture(anim, idx)`
- `SpriteFrames.set_animation_loop(anim, loop)`
- `SpriteFrames.set_animation_speed(anim, fps)`
- `ResourceSaver.save(resource, path)`

## 6. Data Store and Validation

Update:

```text
godot/scripts/prd_v0_3_data_store.gd
godot/scripts/creator_lab_action_coverage.gd
tools/validate_prd_v0_3.py
```

Add non-breaking helpers:

```gdscript
static func generated_sprite_frames_path(sprite_set_id: String) -> String
static func validate_frame_slot(slot: String) -> Array
static func frame_slot_state(slot: String) -> String
static func validate_spriteframes_resource(sprite_set: Dictionary) -> Array
```

Validation additions:

- `INVALID_FRAME_SLOT_URI`
- `UNLOADABLE_FRAME_TEXTURE_WARNING`
- `LOCAL_ONLY_FRAME_TEXTURE`
- `EMPTY_FRAME_SLOT`
- `MISSING_FRAME_SLOT`
- `PLACEHOLDER_FRAME_SLOT`
- `MISSING_SPRITEFRAMES_RESOURCE`
- `STALE_SPRITEFRAMES_RESOURCE`
- `INVALID_SPRITEFRAMES_RESOURCE`
- `SPRITEFRAMES_MISSING_ANIMATION`
- `SPRITEFRAMES_WRONG_FRAME_COUNT`
- `SPRITEFRAMES_WRONG_LOOP_FLAG`

Do not make empty/missing/placeholder slots fatal by default. They should be warnings unless a specific export or release gate requires full art coverage.

Do not make missing/unloadable real frame paths fatal in v0.5 generation. They warn and use the missing placeholder texture so the action timeline remains inspectable and repairable.

## 7. Creator Lab UI and Save/Apply

Update:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/creator_lab_action_preview.gd
```

Add Creator Lab actions:

- Generate SpriteFrames
- Regenerate on Save/Apply
- Insert empty frame before
- Insert empty frame after
- Remove frame slot, blocked when referenced by timing metadata
- Replace frame path
- Mark empty
- Mark missing
- Mark placeholder
- Shift timing metadata for an insert operation

Recommended placement:

- Put generation status in the existing selected action/coverage details area.
- Put frame slot operations near preview frame controls, because they operate on the selected action and selected frame.
- Show the current slot URI/state next to the frame index.

Save/apply flow:

```text
validate authoring JSON
save template/move/sprite_set JSON
generate SpriteFrames .tres
reload generated resource
refresh preview
emit live apply bundle to Playground
```

Rules:

- If JSON validation fails fatally, do not generate.
- If generation fails, JSON save succeeds, generation error is visible, and live apply is blocked.
- If generation succeeds, refresh runtime characters bound to that sprite set.
- Do not mutate `AGENTS.md`, `CLAUDE.md`, or ignored local instruction files.

## 8. Runtime Integration

Update:

```text
godot/scripts/combat_character.gd
godot/scripts/combat_state_machine.gd
godot/scripts/move_executor.gd
godot/scripts/playground.gd
```

`CombatCharacter` node structure:

```text
CombatCharacter (Node2D)
  AnimatedSprite2D
  move_executor
  state_machine
```

New state:

```gdscript
var animated_sprite: AnimatedSprite2D
var sprite_frames_path: String = ""
var sprite_frames_valid: bool = false
var visual_fallback_enabled: bool = true
```

Required methods:

```gdscript
func _ensure_animated_sprite() -> void
func _load_sprite_frames_for_sprite_set() -> void
func _sync_visual_animation() -> void
func _animation_for_runtime_state() -> String
func _sync_visual_frame() -> void
func has_spriteframes_playback() -> bool
```

Animation selection mapping:

| Runtime state | Preferred clip |
| --- | --- |
| idle | `idle` |
| walk | `walk` |
| dash | `dash`, fallback `run` |
| jump | `jump`, fallback `idle` |
| attack | `state_machine.current_move` |
| hurt | `hurt`, fallback `hurt_light`, fallback `idle` |
| dead | `dead`, fallback final `hurt`, fallback `idle` |

Frame sync rules:

- For attack moves, use `move_executor.current_frame()`.
- For locomotion loops, allow `AnimatedSprite2D.play()` to advance when the animation exists.
- For frame-accurate preview/debug mode, expose a method to force `AnimatedSprite2D.frame`.
- Match preview/runtime frame order and frame index semantics.
- Do not require preview/runtime playback speed parity in v0.5.
- Do not use jump visual offset for depth sorting; keep v0.4.2 foot-y behavior.
- Existing `_draw()` rectangle body becomes fallback only when no valid sprite frames resource is active.
- Debug box drawing remains in `_draw()` and overlays the animated sprite.

First implementation note:

- Current `MoveExecutor.tick()` advances one frame per physics tick for attack moves.
- v0.5 should align visual attack frame to the same index so boxes and sprite frames match.
- A later timing PR may move combat move timing to seconds/FPS. That is not required for the first resource integration if frame indices stay aligned.

## 9. Preview Integration

Update:

```text
godot/scripts/creator_lab_action_preview.gd
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
```

Keep existing v0.4.2 controls and tests:

- First
- Prev
- Next
- Last
- frame slider
- Play
- Pause
- Reset
- `0.5x`
- `1x`

Add preview data:

```gdscript
current_slot_uri
current_slot_state
generated_sprite_frames_path
generated_resource_valid
```

Preview rendering rules:

- `TEXTURE`: draw the real frame texture.
- `EMPTY`: draw transparent/blank slot marker.
- `MISSING`: draw visible missing marker.
- `PLACEHOLDER`: draw visible placeholder marker.
- `INVALID`: draw validation marker.
- If generated `SpriteFrames` exists, preview can read frame textures from the resource to prove parity.
- Overlay boxes still come from authoring JSON and selected frame index.

Parity check:

```gdscript
func preview_frame_texture_matches_generated(action_id: String, frame_index: int) -> bool
```

This does not need pixel comparison in the first PR. It can compare resolved slot state/path or resource frame count/name contract.

## 10. Skeleton Initial Template

Add approved normalized Skeleton art:

```text
data/v0_3/templates/skeleton_default_unarmed_s64.json
data/v0_3/sprite_sets/skeleton_default_unarmed_s64.json
godot/assets/frames/skeleton_default_unarmed_s64/**
godot/resources/sprite_frames/skeleton_default_unarmed_s64.tres
godot/assets/frames/skeleton_default_unarmed_s64/LICENSE.md
```

Template:

```json
{
  "schema_version": "0.3",
  "template_id": "skeleton_default_unarmed_s64",
  "sprite_set_ref": "skeleton_default_unarmed_s64",
  "equipped_moves": ["idle", "walk", "run", "basic_punch", "hurt"]
}
```

Sprite set clip contract:

| Clip | Frames | Loop |
| --- | ---: | --- |
| `idle` | 6 | true |
| `walk` | 6 | true |
| `run` | 6 | true |
| `basic_punch` | 6 | false |
| `hurt` | 2 | false |

Actions outside that set must remain explicit missing/empty/placeholder until art exists.

## 11. Smoke Tests

Add:

```text
tools/spriteframes_generation_smoke.gd
tools/spriteframes_runtime_smoke.gd
```

`spriteframes_generation_smoke.gd` must prove:

- Generator can create a `SpriteFrames` resource from a fixture sprite set.
- Resource saves to `res://godot/resources/sprite_frames/<sprite_set_id>.tres`.
- Resource reloads with `ResourceLoader.load()`.
- Animation names match clip IDs.
- Timeline frame counts match sequence slot counts.
- Loop flags match clip metadata.
- Placeholder/empty/missing slots are represented with textures.
- Missing real `res://` frame paths generate with missing placeholder textures and warnings.
- `user://` frame paths warn as local-only.

`spriteframes_runtime_smoke.gd` must prove:

- `CombatCharacter` creates or owns an `AnimatedSprite2D`.
- `AnimatedSprite2D.sprite_frames` loads the generated resource.
- `idle` can play.
- `walk` or `run` can play.
- `basic_punch` can play when the move starts.
- Attack frame index aligns with `MoveExecutor.current_frame()`.
- Runtime frame order/index semantics match Creator Lab preview.
- Fallback rectangle path is used when generated resource is missing.

Extend existing smokes:

```text
tools/creator_lab_v0_3_smoke.gd
tools/runtime_smoke.gd
tools/prd_v0_3_runtime_smoke.gd
```

New checks to add or extend:

```text
frame_slot_insert_empty_before
frame_slot_insert_empty_after
frame_slot_insert_requires_shift_choice
frame_slot_replace_real_path
frame_slot_mark_missing
frame_slot_delete_blocks_referenced_frame
frame_slot_reorder_not_available
preview_reports_slot_state
preview_frame_count_includes_move_only_trailing_frames
save_apply_generates_spriteframes
save_generation_failure_blocks_live_apply
playground_reload_spriteframes_after_live_apply
skeleton_default_unarmed_resource_contract
skeleton_default_unarmed_npc_spawn_contract
```

Required command set:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
godot --headless --path . --script tools/spriteframes_generation_smoke.gd
godot --headless --path . --script tools/spriteframes_runtime_smoke.gd
```

## 12. Single-PR Workstreams

Issue #15 is delivered as one PR. Use these workstreams as implementation order inside that PR.

### Workstream 1: Resource Generator and Validation

Files:

```text
godot/scripts/spriteframes_generator.gd
godot/scripts/prd_v0_3_data_store.gd
tools/spriteframes_generation_smoke.gd
```

Work:

- Add `SpriteFramesGenerator`.
- Define path convention.
- Implement slot URI state parsing.
- Generate `.tres` from `sprite_set`.
- Validate generated resource contract.

Exit criteria:

- Generation smoke passes.
- Existing v0.3 validation remains green.

### Workstream 2: Creator Lab Slot Editing and Generate on Save/Apply

Files:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/creator_lab_action_preview.gd
tools/creator_lab_v0_3_smoke.gd
```

Work:

- Add frame slot operation methods.
- Add UI controls for slot edit operations.
- Show current slot URI/state.
- Block insert until a shift timing choice is made.
- Block delete for referenced frames.
- Do not expose reorder controls in v0.5.
- Trigger generation on Save/Apply.
- Refresh preview after generation.

Exit criteria:

- Slot editing smoke passes.
- Preview still satisfies v0.4.2 controls.
- Generated resource is refreshed after Save/Apply.

### Workstream 3: Runtime AnimatedSprite2D Playback

Files:

```text
godot/scripts/combat_character.gd
godot/scripts/playground.gd
tools/spriteframes_runtime_smoke.gd
tools/runtime_smoke.gd
```

Work:

- Add `AnimatedSprite2D` child management.
- Load generated `SpriteFrames`.
- Map runtime state/action to animation names.
- Align attack frame with `MoveExecutor.current_frame()`.
- Prove preview/runtime frame order and frame index parity.
- Do not rewrite runtime timing for playback speed parity.
- Keep rectangle fallback.

Exit criteria:

- Runtime smoke proves `AnimatedSprite2D` playback.
- Existing multi-NPC/depth behavior remains green.

### Workstream 4: Approved Skeleton Intake

Files:

```text
data/v0_3/templates/skeleton_default_unarmed_s64.json
data/v0_3/sprite_sets/skeleton_default_unarmed_s64.json
godot/assets/frames/skeleton_default_unarmed_s64/**
godot/resources/sprite_frames/skeleton_default_unarmed_s64.tres
godot/assets/frames/skeleton_default_unarmed_s64/LICENSE.md
tools/spriteframes_generation_smoke.gd
tools/spriteframes_runtime_smoke.gd
```

Work:

- Add approved normalized Skeleton frames.
- Add Skeleton license note.
- Add template and sprite set JSON.
- Generate and commit Skeleton `SpriteFrames` resource.
- Add spawn contract test.

Exit criteria:

- Skeleton resource contract smoke passes.
- NPC can spawn with Skeleton template.
- `basic_punch` plays through `AnimatedSprite2D`.

## 13. GitNexus Gates

Before editing existing symbols, run impact analysis for the target symbol or the nearest resolvable file/symbol:

```bash
npx gitnexus impact SpriteFramesGenerator.generate --direction upstream --repo SpritesPlayground
npx gitnexus impact PrdV03DataStore.validate_runtime_bundle --direction upstream --repo SpritesPlayground
npx gitnexus impact CreatorLabV03Panel._refresh_action_preview --direction upstream --repo SpritesPlayground
npx gitnexus impact CreatorLabActionPreview.frame_count --direction upstream --repo SpritesPlayground
npx gitnexus impact CombatCharacter.tick_character --direction upstream --repo SpritesPlayground
npx gitnexus impact Playground.add_npc --direction upstream --repo SpritesPlayground
```

If GitNexus cannot resolve GDScript method symbols, record the failed lookup and perform manual blast-radius review over direct callers.

Before committing:

```bash
npx gitnexus detect_changes --repo SpritesPlayground --scope staged
```

## 14. Acceptance Mapping

| PRD acceptance | Spec implementation |
| --- | --- |
| Normalized PNG sequence registration | Workstream 1 slot URI model + Workstream 2 UI entry |
| Bind frame sequence to animation clip | Existing `animation_clips` + Workstream 2 controls |
| Frame-by-frame preview | Workstream 2 preview slot state refresh |
| Insert/replace frame slot | Workstream 2 slot operations |
| Delete referenced frame is blocked | Workstream 2 slot delete guard |
| Reorder is out of scope | Workstream 2 does not expose reorder controls |
| Generate `.tres` `SpriteFrames` | Workstream 1 generator |
| Animation names/counts/loops match | Workstream 1 validation and smoke |
| Runtime `AnimatedSprite2D` playback | Workstream 3 runtime integration |
| Preview/runtime same frame order | Workstream 2 + Workstream 3 parity checks |
| Playback speed parity not required | Workstream 3 timing scope |
| Missing frame warnings | Workstream 1 validation + Workstream 2 preview state |
| `user://` local-only warning | Workstream 1 validation |
| Skeleton first NPC template | Workstream 4 approved asset intake |
| Generated Skeleton `.tres` committed | Workstream 4 generated resource |
| Existing checks remain green | Single PR exit criteria |

## 15. Out of Scope

Do not implement these in v0.5:

- GIF decoding or conversion.
- Sprite-sheet/frame-strip slicing in Creator Lab.
- Aseprite parsing.
- AI or PixelLab asset generation.
- Full schema migration to object-shaped slots.
- Frame slot reorder UI or reorder semantics.
- AnimationTree, AnimationPlayer, or blend-tree behavior.
- Rewriting combat timing to seconds/FPS.
- Asset marketplace/license workflow.
- Weapon, projectile, combo, stamina, mana, or paper-doll systems.
