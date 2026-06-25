# Implementation Spec v0.4.2: Playground Multi-NPC and Preview Controls

Status: implementation plan for `docs/PRD_v0.4.2_PLAYGROUND_MULTI_NPC_PREVIEW.md`

Source of truth:

- `docs/PRD_v0.4.2_PLAYGROUND_MULTI_NPC_PREVIEW.md`
- `docs/PRD_v0.4.1_ACTION_AUTHORING_TOOL_ADDON.md`
- `docs/IMPLEMENTATION_SPEC_V0_4_1_ACTION_AUTHORING_TOOL_ADDON.md`
- Current implementation in `godot/scripts/playground.gd`, `godot/scripts/combat_character.gd`, and `godot/scripts/creator_lab_v0_3_panel.gd`

## 1. Goal

Implement the v0.4.2 UAT gap set without changing saved v0.3 data schema:

```text
screen-depth sorting for overlapping characters
+ dynamic 1..10 NPC management
+ complete selected-action preview frame controls
```

## 2. Scope Summary

v0.4.2 has three implementation tracks:

1. Generalize Playground from fixed `player`/`dummy` pair handling to player plus NPC collection handling.
2. Add deterministic character depth ordering based on foot contact y.
3. Extend Creator Lab preview from forward-step controls to full frame selection and playback verification.

## 3. Playground Character Collection

Update:

```text
godot/scripts/playground.gd
tools/runtime_smoke.gd
```

Replace fixed pair assumptions with a managed character list while preserving existing `player` and `dummy` compatibility where useful.

New constants:

```gdscript
const MIN_NPC_COUNT := 1
const MAX_NPC_COUNT := 10
```

New state:

```gdscript
var characters: Array[Node2D] = []
var npcs: Array[Node2D] = []
var next_npc_index: int = 1
var npc_template_id: String = "combat_gray_s64"
var playground_status: String = ""
```

Compatibility:

- Keep `player` as the single manually controlled character.
- Keep `dummy` as an alias to the first NPC until callers/tests are migrated.
- Keep `select_player_character()`.
- Replace fixed `select_dummy_character()` behavior with selecting the first NPC, or keep it as an alias to `select_npc(0)`.

Recommended new methods:

```gdscript
func all_characters() -> Array
func npc_count() -> int
func add_npc(template_id: String = npc_template_id) -> Node2D
func remove_npc(character: Node2D) -> bool
func remove_selected_npc() -> bool
func select_npc(index: int) -> void
func reset_playground() -> void
func _sync_character_aliases() -> void
func _next_npc_instance_id() -> String
func _spawn_npc_position(index: int) -> Vector2
```

Rules:

- `add_npc()` returns `null` and sets visible status when `npc_count() >= MAX_NPC_COUNT`.
- `remove_npc()` returns `false` and sets visible status when removing would leave fewer than `MIN_NPC_COUNT`.
- Removing the selected NPC rebinds selection to the nearest remaining NPC, or to player if no safe NPC target exists.
- Adding an NPC selects the new NPC only if the user action explicitly asks for that behavior.
- Spawned NPCs default to `is_test_dummy = true` unless a later PR adds AI mode selection.
- Every spawned NPC gets a stable instance id such as `npc_001`, `npc_002`, etc.
- Spawn positions must be inside the arena and separated enough for immediate UAT readability.

## 4. Pairwise Runtime Loops

Update:

```text
godot/scripts/playground.gd
tools/runtime_smoke.gd
```

Replace fixed pair runtime logic:

```gdscript
player.tick_character(...)
dummy.tick_character(...)
_resolve_foot_spacing()
_clamp_characters_to_arena()
_process_hits(player, dummy)
_process_hits(dummy, player)
```

With collection-based logic:

```gdscript
for character in all_characters():
    character.tick_character(delta, arena_center, arena_radius)

_resolve_all_foot_spacing()
_clamp_all_characters_to_arena()
_update_character_depth_order()
_process_all_hits()
```

Required helpers:

```gdscript
func _resolve_all_foot_spacing() -> void
func _clamp_all_characters_to_arena() -> void
func _process_all_hits() -> void
```

Pairwise rules:

- Foot spacing considers every unordered pair in `all_characters()`.
- Hit detection considers every ordered attacker/target pair where attacker != target.
- Dead characters do not attack and cannot be damaged again, matching current pair behavior.
- Per-hit target marking must continue to use unique `instance_id`.
- Clamp after spacing to keep all characters inside the arena.
- Avoid one-pass order bias where possible. If needed, repeat separation for a small fixed number of deterministic iterations.

Smoke requirements:

- Adding three NPCs results in player plus four total NPC-capable targets.
- Player hit can damage each overlapping NPC.
- NPC hit can damage player if NPC combat is triggered in test setup.
- Increasing foot radius on one NPC changes pairwise separation against all neighbors.
- Removing an NPC removes it from spacing, hit detection, debug HUD, and selection candidates.

## 5. Depth Ordering

Update:

```text
godot/scripts/playground.gd
godot/scripts/combat_character.gd
tools/runtime_smoke.gd
```

Required behavior:

- Draw order follows each character's current foot contact world y.
- Lower foot contact y renders in front.
- Depth updates after movement, spacing, and clamp.
- Jump visual offset does not change ground sort position.

Preferred implementation:

```gdscript
func depth_sort_key() -> float:
    return foot_center_world().y
```

In `Playground`:

```gdscript
func _update_character_depth_order() -> void:
    var sorted := all_characters()
    sorted.sort_custom(func(a, b): return a.foot_center_world().y < b.foot_center_world().y)
    for index in sorted.size():
        sorted[index].z_index = index
```

Notes:

- Explicit `z_index` is acceptable and easy to smoke-test.
- A dedicated `character_layer` with `y_sort_enabled = true` is acceptable if tests can prove the same ordering.
- If explicit `z_index` is used, keep UI CanvasLayers above gameplay as they are today.
- Do not sort using `state_machine.visual_jump_offset`.

Smoke requirements:

- Character A with lower `foot_center_world().y` has higher render order/z than character B.
- After swapping y positions, render order/z changes.
- During jump, depth order remains based on foot contact y, not visual jump offset.

## 6. NPC UI and Creator Lab Binding

Update:

```text
godot/scripts/playground.gd
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
tools/runtime_smoke.gd
```

Creator Lab new signals:

```gdscript
signal add_npc_requested(template_id: String)
signal remove_selected_npc_requested
signal bind_npc_requested(index: int)
signal npc_template_selected(template_id: String)
```

Creator Lab new UI in the selected-instance/runtime area:

- NPC count display: `NPCs: current / 10`
- Template selector populated from `DataStore.list_template_ids()`
- Add NPC button
- Remove NPC button
- NPC selection control or compact next/previous NPC buttons
- Status text for min/max guardrails

Playground wiring:

```gdscript
creator_lab.add_npc_requested.connect(_on_add_npc_requested)
creator_lab.remove_selected_npc_requested.connect(_on_remove_selected_npc_requested)
creator_lab.bind_npc_requested.connect(select_npc)
```

Bound summary additions:

```text
npc_count
npc_limit
selected index or instance id
template selector id
last add/remove status
```

Rules:

- Add/remove controls must not steal keyboard focus permanently from gameplay.
- Existing `Bind P` and `Bind D` can stay, but the UI must not imply there is only one dummy.
- If only one template exists, the selector still renders and selects it.

## 7. Preview Timeline and Frame Controls

Update:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/creator_lab_action_preview.gd
tools/creator_lab_v0_3_smoke.gd
```

Current preview methods to keep:

```gdscript
preview_play()
preview_pause()
preview_step_forward()
preview_reset()
set_preview_speed(value)
```

New preview methods:

```gdscript
func preview_step_backward() -> void
func preview_first() -> void
func preview_last() -> void
func set_preview_frame(frame_index: int) -> void
func preview_frame_count() -> int
```

Rename internal `_preview_frame_count()` only if the public wrapper is cleaner; do not break existing smoke access unless the tests are updated in the same PR.

Required UI controls:

- First frame
- Previous frame
- Play/Pause
- Next frame
- Last frame
- Frame slider or frame-number input
- Existing `0.5x` and `1x` speed controls
- Existing hurt/hit/foot overlay toggles

Frame strip/timeline:

- Render one compact segment per frame for small frame counts.
- For large frame counts, render a compressed strip with tick marks and current-frame highlight.
- Highlight active hitbox frames differently from inactive frames where data exists.
- Placeholder/missing/real texture status must remain visible for the current frame.

Behavior:

- `preview_play()` starts from frame `0` if already at the last frame.
- Playback advances at `PREVIEW_FRAME_SECONDS / preview_speed`.
- Playback stops at the last frame unless a loop toggle is explicitly added.
- `preview_pause()` freezes the current frame.
- Changing action clamps the current frame to the new action frame count.
- Editing frame count or sprite sequence refreshes the strip and clamps the current frame.

Smoke requirements:

- `basic_punch` or another multi-frame action reports frame count greater than `1`.
- `preview_step_forward()` increments the frame.
- `preview_step_backward()` decrements the frame.
- `preview_first()` sets frame `0`.
- `preview_last()` sets `frame_count - 1`.
- `set_preview_frame(3)` selects frame `3` when in range.
- Out-of-range frame selection clamps.
- `preview_play()` advances beyond frame `0` after enough process time.
- `preview_pause()` stops advancement after enough process time.
- The embedded preview and floating preview show the same selected frame.

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
depth_order_follows_foot_y
depth_order_ignores_jump_visual_offset
npc_add_until_max_10
npc_remove_until_min_1
npc_template_spawn_and_bind
npc_add_remove_status_feedback
all_characters_pairwise_spacing
all_characters_pairwise_hits
reset_all_characters
preview_step_backward
preview_first_last
preview_set_frame_clamps
preview_play_advances_multi_frame_action
preview_pause_freezes_frame
preview_frame_strip_matches_frame_count
```

GitNexus gates before code changes:

```bash
npx gitnexus impact Playground._tick_combat --direction upstream --repo SpritesPlayground
npx gitnexus impact Playground._spawn_character --direction upstream --repo SpritesPlayground
npx gitnexus impact Playground._process_hits --direction upstream --repo SpritesPlayground
npx gitnexus impact Playground._resolve_foot_spacing --direction upstream --repo SpritesPlayground
npx gitnexus impact CreatorLabV03Panel.preview_play --direction upstream --repo SpritesPlayground
npx gitnexus impact CreatorLabV03Panel._build_action_preview_detail --direction upstream --repo SpritesPlayground
npx gitnexus detect_changes --repo SpritesPlayground --scope compare --base-ref main
```

If GitNexus cannot resolve a GDScript symbol, record the failed lookup and do manual blast-radius review over direct callers.

## 9. Implementation Slices

### PR 1: Character Collection and Pairwise Runtime

Files:

```text
godot/scripts/playground.gd
tools/runtime_smoke.gd
```

Work:

- Add `characters` and `npcs` arrays.
- Keep `player` and first-NPC `dummy` compatibility.
- Replace fixed pair tick/clamp/spacing/hit loops.
- Add reset for all characters.

Exit criteria:

- Existing two-character behavior still works.
- Runtime smoke proves pairwise spacing/hits across at least three characters.

### PR 2: Depth Ordering

Files:

```text
godot/scripts/playground.gd
godot/scripts/combat_character.gd
tools/runtime_smoke.gd
```

Work:

- Add foot-y depth sort helper.
- Update z/order after movement, spacing, and clamp.
- Add smoke for swapped y positions and jump offset.

Exit criteria:

- Overlapping characters sort by foot contact y.
- UI layers remain above gameplay.

### PR 3: NPC Add/Remove UI

Files:

```text
godot/scripts/playground.gd
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
tools/runtime_smoke.gd
```

Work:

- Add NPC template selector.
- Add add/remove controls and signals.
- Enforce min/max guardrails.
- Bind/select spawned NPCs.

Exit criteria:

- UAT can add to 10 NPCs and remove back to 1.
- Creator Lab can bind each spawned NPC.

### PR 4: Preview Frame Timeline

Files:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/creator_lab_action_preview.gd
tools/creator_lab_v0_3_smoke.gd
```

Work:

- Add previous/first/last/set-frame methods.
- Add slider or frame selector.
- Add compact frame strip/timeline.
- Add playback advancement and pause smoke.

Exit criteria:

- Multi-frame actions can be scrubbed and played.
- Preview no longer depends on forward-only `+1` stepping.

## 10. Acceptance Mapping

| PRD acceptance | Spec implementation |
| --- | --- |
| Depth-correct overlapping sprites | PR 2 depth sort by foot contact y |
| Depth updates after movement/collision | PR 1 collection loops + PR 2 update order |
| One to ten NPCs | PR 1 NPC collection + PR 3 UI guardrails |
| Template-based NPC spawning | PR 3 template selector and add signal |
| Spawned NPC selection/binding | PR 3 bind/select spawned NPCs |
| Pairwise spacing and hits | PR 1 collection-based runtime loops |
| Full preview frame range | PR 4 frame count and frame strip |
| Previous/next/first/last | PR 4 preview methods and controls |
| Scrub/direct frame selection | PR 4 slider or frame input |
| Play advances beyond first frame | PR 4 process-time smoke |
| Pause freezes frame | PR 4 process-time smoke |

## 11. Out of Scope

Do not implement these in v0.4.2:

- new saved schema version
- saved per-instance override data
- final art generation
- PixelLab or AI generation calls
- weapon/projectile/combo systems
- full AI behavior editor
- full level or room system
- room/lab trigger collision unless it falls out naturally from reusable foot contact helpers
- physics-body migration unless explicitly justified by a later implementation review
