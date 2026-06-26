# PRD v0.5: Runtime SpriteFrames Pipeline

Status: product requirements for the next Creator Lab/runtime animation wave

Source of truth:

- GitHub issue #15: `PRD v0.5: Runtime SpriteFrames resource pipeline for Creator Lab animations`
- Issue #15 comment: candidate public sprite packs for v0.5 animation pipeline UAT
- Issue #15 comment: Skeleton Pack as the first v0.5 NPC template resource
- Godot stable documentation:
  - `SpriteFrames`: https://docs.godotengine.org/en/stable/classes/class_spriteframes.html
  - `AnimatedSprite2D`: https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html
  - `ResourceSaver`: https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html
- `docs/PRD_v0.4_ACTION_AUTHORING_TOOL.md`
- `docs/PRD_v0.4.1_ACTION_AUTHORING_TOOL_ADDON.md`
- `docs/PRD_v0.4.2_PLAYGROUND_MULTI_NPC_PREVIEW.md`
- Local v0.5 asset prototype under ignored `tmp/asset_research/issue15-*`

## 1. Purpose

v0.4 made Creator Lab useful for authoring actions, boxes, live apply, and action preview. v0.4.2 made runtime UAT more realistic with multi-NPC management, depth ordering, and complete preview frame controls.

v0.5 turns the animation path into a Godot-friendly resource pipeline:

```text
externally normalized frame PNGs
+ v0.3 Creator Lab authoring JSON
+ generated Godot SpriteFrames .tres resource
+ CombatCharacter AnimatedSprite2D runtime playback
```

Creator Lab remains an authoring surface. It consumes normalized frame references, binds those frames to actions, edits frame slots, edits gameplay boxes against frame indices, and generates runtime resources. It does not generate art, decode GIFs, cut sprite sheets, or own a permanent animation playback runtime separate from Godot nodes/resources.

## 2. Product Principles

- Final scene execution is node-driven: runtime characters must use real Godot nodes and resources where Godot already provides the correct abstraction.
- `AnimatedSprite2D` is the v0.5 runtime playback node.
- `SpriteFrames` is the v0.5 generated animation resource.
- Existing v0.3 JSON remains the authoring source of truth unless a separate schema migration is approved.
- Generated `.tres` resources are rebuildable artifacts, not the source of truth for gameplay timing or boxes.
- Frame indices are stable gameplay contract points. Hurtboxes, hitboxes, footboxes, active windows, events, and preview state stay bound to frame index, not image file identity.
- Missing art must be explicit and inspectable. A missing frame is not the same thing as silently shortening an action.

## 3. Terms

| Term | Meaning |
| --- | --- |
| Raw source asset | Original downloaded or supplied art, such as GIF, sprite sheet, Aseprite source, or unprocessed ZIP content. |
| Normalized frame | A single frame PNG in an approved Godot import path, ready to load as `Texture2D`. |
| Frame slot | One ordered position in `sprite_set.frame_sequences[sequence_id]`. |
| Real slot | A frame slot pointing to a loadable `res://...png` or approved `user://...png` frame. |
| Empty slot | An intentional blank frame position used to preserve timing or reserve an art gap. |
| Missing slot | A slot where expected art is not available or no longer loadable. |
| Placeholder slot | A slot backed by the current placeholder URI convention. |
| Animation clip | A `sprite_set.animation_clips` entry that maps a clip id to a frame sequence and loop metadata. |
| Generated resource | A `SpriteFrames` `.tres` file generated from authoring JSON and normalized frame slots. |
| Playback node | The `AnimatedSprite2D` child on `CombatCharacter` that consumes the generated resource. |

## 4. Current Validated Gaps

### 4.1 Creator Lab Preview Is Not the Runtime Animation Model

The current preview draws its own placeholder/texture state and overlays. That is acceptable as an authoring visualization, but it should not become the runtime animation engine.

Required v0.5 behavior:

- Creator Lab preview and runtime playback use the same frame order for the same action.
- Creator Lab may keep custom overlay drawing for boxes and frame-state diagnostics.
- Runtime visual playback must move to `AnimatedSprite2D` consuming generated `SpriteFrames`.
- Placeholder rectangle drawing in `CombatCharacter._draw()` remains fallback only when no valid generated resource is available.

### 4.2 External Art Formats Need a Clear Boundary

Available art may arrive as single PNG frames, sprite sheets, frame strips, GIFs, or source project files. Creator Lab should not become an image-processing tool.

Required v0.5 behavior:

- Creator Lab consumes normalized frame references, primarily `res://...png`.
- Single PNG frames are supported as direct frame references.
- Sprite sheets and frame strips must be cut outside Creator Lab or registered from an already-normalized manifest.
- GIFs must be converted outside Creator Lab to frame PNGs before registration.
- Creator Lab may store source provenance for traceability, but runtime playback must not depend on GIFs or uncut sheets.

### 4.3 Missing or Short Art Must Not Collapse Frame Timing

Action timing and box editing depend on frame indices. If an art sequence has fewer PNGs than `move.frame_count`, the extra frames still exist for authoring and must be inspectable as missing/empty/placeholder.

Required v0.5 behavior:

- Preview frame count is the max of move frame count and frame sequence slot count.
- Generated resources preserve authoring slot order.
- Empty/missing/placeholder slots are represented consistently so the frame index does not shift silently.
- Validation reports move/sequence count mismatch, but the tool still allows inspection and repair.

### 4.4 Temporary `.tres` Prototypes Are Not a Commit-Ready Resource Path

The local ignored prototype proved Godot can generate and load `SpriteFrames` and play them through `AnimatedSprite2D`. In headless temporary paths, textures may be embedded as generated subresources because the PNGs are outside normal Godot import paths.

Required v0.5 behavior:

- Formal generated `.tres` files should reference imported texture resources from an approved `res://` asset path.
- Commit-ready generated resources must not hide large embedded `ImageTexture` payloads when the source PNGs can be imported and referenced.
- Smoke tests must detect missing resources and unexpected inline-only texture generation where feasible.

## 5. Requirements

### R1. Asset Intake Boundary

- Creator Lab accepts normalized frame references, not raw animation source files.
- Supported initial frame URI forms:
  - `res://...png`
  - `user://...png` for local-only experiments, if the runtime can load it in UAT
  - `placeholder://<sprite_set_id>/<sequence_id>/frame_000.png`
  - `missing://<sprite_set_id>/<sequence_id>/frame_000.png`
  - `empty://<sprite_set_id>/<sequence_id>/frame_000.png`
- Raw GIFs, uncut sheets, ZIPs, and Aseprite files are never runtime dependencies.
- Asset source metadata may be documented in sidecar notes, comments, or future schema, but it must not be required for playback.

### R2. Authoring Source of Truth

- `data/v0_3/**` remains valid and schema version `0.3` unless a separate migration is approved.
- `sprite_set.animation_clips` defines `clip_id`, `frame_sequence_ref`, and `loop`.
- `sprite_set.frame_sequences` defines ordered frame slots.
- Slot state is initially represented through URI scheme while the schema still uses string arrays.
- If object-shaped frame slots become necessary, that is a separate schema migration with a migration script and compatibility plan.
- `move.frame_count`, active windows, hitboxes, hurtboxes, events, and foot collision remain bound to frame indices.

### R3. Frame Slot Editing

Creator Lab must support frame-structure fixes without editing image pixels:

- Insert empty slot before the current frame.
- Insert empty slot after the current frame.
- Remove the current slot.
- Replace the current slot with a real frame reference.
- Mark the current slot as empty.
- Mark the current slot as missing.
- Mark the current slot as placeholder.
- Reorder slots is not required in v0.5.
- Insert must be blocked until the user chooses whether to shift timing metadata.
- Delete must be blocked when the target frame is referenced by active windows, hitboxes, or events.
- Timing shifts must be explicit. Creator Lab must not silently move gameplay windows or events.

Frame is timing. An action may have 8 timing frames while only 3 real visual frames exist, such as start at frame 0, hit at frame 3, and end at frame 7. The remaining action frames are still real authoring positions and may be empty, missing, placeholder, or later replaced by real art. This is normal and must not be treated as an error.

### R4. Generated Godot Runtime Resource

- Save/apply generates or refreshes:

```text
res://godot/resources/sprite_frames/<sprite_set_id>.tres
```

- The resource type is `SpriteFrames`.
- Each `animation_clip` becomes one `SpriteFrames` animation.
- Animation name matches `clip_id`.
- Animation frames come from `frame_sequences[frame_sequence_ref]`.
- Loop setting comes from clip metadata.
- FPS comes from clip metadata when available, otherwise the documented v0.5 default is `12.0`.
- Empty/missing/placeholder slots are converted into a stable visual placeholder texture so the generated animation frame count matches the authoring slot count.
- Missing or unloadable real frame paths generate with a missing placeholder texture and a visible warning.
- Generation succeeds when only a sparse subset of timing frames has real art.

### R5. Runtime Node Integration

- `CombatCharacter` owns an `AnimatedSprite2D` child for visual playback.
- `AnimatedSprite2D.sprite_frames` loads the generated `.tres` for the active sprite set.
- Runtime action/move state selects animation by clip/action mapping.
- `AnimatedSprite2D.animation` follows the current runtime state/action when that clip exists.
- `AnimatedSprite2D.frame` is inspectable and kept aligned with the runtime frame index used by boxes/hits.
- Debug overlays remain available and aligned with the owning character.
- Current rectangle placeholder rendering remains a fallback for invalid or missing generated resources.

### R6. Creator Lab Preview Integration

- Preview uses the same frame order and clip mapping as the generated runtime resource.
- Preview frame controls from v0.4.2 remain required:
  - First
  - Prev
  - Next
  - Last
  - frame slider/direct frame selection
  - Play
  - Pause
  - Reset
  - `0.5x` and `1x`
- Preview shows real, empty, missing, and placeholder frame states.
- Preview can edit boxes against the selected frame index.
- Preview must not stop at the first frame when a generated resource is available.

### R7. Skeleton as the First v0.5 NPC Template Target

The first v0.5 NPC template target is Skeleton Pack / Default / Unarmed.

Proposed identities:

```text
template_id: skeleton_default_unarmed_s64
sprite_set_id: skeleton_default_unarmed_s64
sprite_frames_path: res://godot/resources/sprite_frames/skeleton_default_unarmed_s64.tres
```

Initial animation mapping:

| Clip | Source sheet | Frames | Loop |
| --- | --- | ---: | --- |
| `idle` | `Skeleton_Default_Idle_Unarmed.png` | 6 | true |
| `run` | `Skeleton_Default_Run_Unarmed.png` | 6 | true |
| `walk` | `MP_Skeleton_Default_Walk_Unarmed.png` | 6 | true |
| `basic_punch` | `Skeleton_Default_Attack_Unarmed.png` | 6 | false |
| `hurt` | `Skeleton_Default_Hurt.png` | 2 | false |

Rules:

- Commit normalized Skeleton PNG frames to the repo with a license note.
- Commit the generated Skeleton `.tres` resource for the approved template.
- Do not switch the current runtime default template to Skeleton unless that is explicitly chosen in a later UAT task.
- Missing actions such as `dead`, `jump`, `basic_kick`, and `heavy_punch` stay explicit missing/empty/placeholder slots until an approved source is selected.

### R8. Validation

Validation must detect:

- Required action has no mapped clip.
- Clip references a missing frame sequence.
- Real frame path is missing or unloadable.
- `move.frame_count` differs from sequence slot count.
- Empty/missing/placeholder frame slots exist.
- Generated `.tres` is missing.
- Generated `.tres` is stale relative to authoring data or normalized frame files, where feasible.
- Generated `SpriteFrames` is missing expected animation names.
- Generated animation frame counts differ from source sequence slot counts.
- Generated loop flags differ from clip metadata.
- Generated resource cannot be loaded by Godot.
- Runtime `AnimatedSprite2D` cannot play an expected clip.

## 6. Product Rules

- Do not add art generation to Creator Lab.
- Do not add GIF decoding/conversion to Creator Lab.
- Do not add sprite-sheet slicing to Creator Lab unless a later importer issue explicitly scopes it.
- Do not create a permanent parallel runtime animation engine.
- Do not make generated `.tres` the only source of action/box truth.
- Do not silently drop missing frames to make generation pass.
- Do not commit raw downloaded third-party ZIPs, GIFs, sheets, or source files.
- Commit normalized Skeleton frames only with a license note.
- Commit generated `.tres` resources for approved templates.
- Do not break existing v0.3 validation or v0.4/v0.4.2 UAT behavior.

## 7. Spec Closure Decisions

These decisions close the v0.5 spec for issue #15:

| Topic | Decision |
| --- | --- |
| Skeleton asset scope | Commit normalized Skeleton PNG frames with a license note. |
| Generated `.tres` policy | Commit generated `.tres` resources for approved templates. |
| Frame slot data shape | Keep `frame_sequences` as string URI arrays in v0.5. |
| Insert behavior | Block insert until the user chooses the timing-shift behavior. |
| Delete behavior | Block delete if active windows, hitboxes, or events reference the frame. |
| Reorder scope | Reorder is out of scope for v0.5. |
| Timing parity | Require frame order/index parity, not playback speed parity. |
| Missing real frame generation | Generate with missing placeholder and warning. |
| `user://` scope | Local UAT only and always warns. |
| Save failure behavior | JSON save succeeds, generation error is visible, live apply is blocked. |
| Issue #15 definition of done | Pipeline plus real Skeleton committed and spawnable. |
| Delivery shape | One PR closes issue #15. |

Action frame count is the authoring timeline. Real visual art may be sparse inside that timeline. v0.5 must support an action where only frames `0`, `3`, and `7` have real art while the other timing frames are blank, missing, or placeholder slots waiting for later replacement.

## 8. Acceptance Criteria

v0.5 is complete when all are true:

- Creator Lab can register or load a normalized PNG frame sequence for an action without processing raw GIF/sheet content.
- Creator Lab can bind the frame sequence to an `animation_clip`.
- Creator Lab can preview the bound sequence frame-by-frame.
- Creator Lab can insert an empty frame slot.
- Creator Lab can replace an empty/missing slot with a real PNG frame reference.
- Creator Lab can mark a slot as empty, missing, or placeholder.
- Frame slot insert/replace operations keep hitbox/hurtbox/footbox edits aligned to the intended frame index.
- Save/apply generates a `SpriteFrames` `.tres` resource for the sprite set.
- Generated `SpriteFrames` contains one animation per configured clip.
- Generated animation names match `clip_id` values.
- Generated timeline frame counts match authoring sequence slot counts.
- Generated loop flags match clip metadata.
- Generated resource loads in Godot headless.
- Generated resource uses loadable texture references from approved frame paths for committed assets.
- Missing or unloadable real frame slots generate with a missing placeholder texture and visible warning.
- `user://` frame slots are accepted for local UAT only and always warn.
- `CombatCharacter` has an `AnimatedSprite2D` child for visual playback.
- `CombatCharacter` can play `idle`, `walk` or `run`, and `basic_punch` through `AnimatedSprite2D`.
- Preview and runtime use the same frame ordering for the same action.
- Preview and runtime are not required to have identical playback speed in v0.5.
- Missing/unloadable frame paths produce visible validation warnings.
- Empty/missing/placeholder slots produce visible preview states.
- Skeleton target can generate a resource with `idle`, `walk`, `run`, `basic_punch`, and `hurt`.
- Skeleton normalized frames are committed with a license note.
- The generated Skeleton `.tres` resource is committed.
- An NPC can spawn with `skeleton_default_unarmed_s64`.
- Existing v0.3/v0.4.2 validation and smoke tests remain green.

## 9. Required Verification

Required existing checks:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
```

New v0.5 verification must also prove:

```text
spriteframes_generation_from_sprite_set
spriteframes_animation_names_match_clips
spriteframes_frame_counts_match_sequences
spriteframes_loop_flags_match_clips
spriteframes_resource_loads_headless
spriteframes_runtime_animatedsprite2d_playback
preview_and_runtime_frame_order_match
frame_slot_insert_preserves_index_contract
frame_slot_replace_updates_resource
empty_missing_placeholder_slots_are_visible
missing_real_frame_warns_and_generates
user_frame_slot_warns_local_only
skeleton_default_unarmed_resource_contract
skeleton_default_unarmed_npc_spawn_contract
```

Manual UAT:

- Register or load a normalized frame sequence for a single action.
- Bind it to an animation clip.
- Use First/Prev/Next/Last, slider, Play, Pause, Reset, `0.5x`, and `1x`.
- Insert an empty frame slot and confirm the selected frame and boxes remain inspectable.
- Replace the empty slot with a real frame path.
- Save/apply and confirm the `.tres` file is generated.
- Launch Playground and confirm the character visual is an `AnimatedSprite2D` playback path, not only rectangle fallback.
- Spawn Skeleton NPC and confirm `basic_punch` plays.

## 10. Out of Scope

Do not implement these in v0.5:

- AI image generation.
- PixelLab or other remote asset generation calls.
- Built-in GIF decoder/converter.
- Built-in sprite-sheet/frame-strip cutter.
- Aseprite source editing.
- Full asset license management workflow.
- Full schema migration to object-shaped frame slots unless separately approved.
- Frame reorder UI or reorder semantics.
- Runtime/preview playback speed parity.
- AnimationTree or AnimationPlayer migration.
- Weapon, projectile, combo, stamina, mana, or paper-doll systems.
- Replacing v0.4.2 multi-NPC/depth behavior.
