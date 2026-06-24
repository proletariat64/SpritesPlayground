# Implementation Spec: Creator Lab Action Authoring Tool v1

Status: ready for coding plan

Source of truth:

- `docs/PRD_v0.4_ACTION_AUTHORING_TOOL.md`
- GitHub issue #13
- `docs/PRD_v0.3.md`
- `docs/CREATOR_LAB_V0_3_STRUCTURE.md`
- `data/schemas/v0_3/*.schema.json`
- `data/v0_3/**`

## 1. Goal

Implement the next Creator Lab wave without changing the v0.3 JSON schema:

```text
selected player/NPC instance
-> Creator Lab bound instance HUD
-> required action catalog coverage
-> live action preview with overlays
-> real Move Lab editing
-> template-level foot collision that affects arena clamp
-> exact save/reload
-> smoke + UAT verification
```

The result should feel like the first real action-game sprite authoring lab, not a decorative JSON form.

## 2. Current Baseline

Already present:

- `CreatorLabV03Panel` loads v0.3 template, moves, sprite set, validates, saves, reloads, and roundtrips.
- Three-panel UI already exists with Character, Moves, Wardrobe, and Runtime navigation.
- Compact input/dropdown helpers already exist.
- `PrdV03DataStore` validates schema contracts and supported frame events.
- `PrdV03Runtime` can load a v0.3 bundle, start a selected move, step frames, expose hurtboxes, active hitboxes, and foot collision.
- `Playground` spawns `player` and `dummy`, has a debug HUD, and hosts Creator Lab.
- `CombatCharacter` draws hurtboxes, hitboxes, and foot collision, and clamps foot center to the arena.
- `tools/runtime_smoke.gd` already covers Creator Lab close-focus release.
- `tools/creator_lab_v0_3_smoke.gd` already covers v0.3 field editing, validation, and roundtrip.

Important gaps:

- Creator Lab is not bound to a selected runtime instance.
- v0.3 runtime data is still separate from the older live combat runtime data path.
- Current foot clamp uses foot center only; foot radius does not affect wall proximity.
- Wardrobe coverage only checks equipped moves, not the required v1 action catalog.
- Placeholder action status is implicit in `placeholder://` frame paths but has no coverage engine.
- Runtime preview is textual; it does not render a live preview canvas.

## 3. Fixed Product Decisions

These decisions are final for this spec:

- Keep schema version `0.3`.
- Do not add JSON schema fields for visual role, placeholder, action category, or per-instance overrides.
- Keep the six v0.3 control states: `idle`, `walk`, `dash`, `jump`, `hurt`, `dead`.
- Treat the required action catalog as derived diagnostic data.
- Detect placeholders from frame paths beginning with `placeholder://`.
- Use explicit `Bind Player` and `Bind Dummy` controls first. Click selection can come later.
- Make arena boundary clamp the only required real foot-collision runtime behavior for v1.
- Keep saved foot collision template-level. No saved per-instance override schema in this wave.
- F5/editor launch is the required manual UAT path. Standalone launch remains optional.

## 4. In Scope

### 4.1 Selected Instance Binding

Creator Lab must bind to either:

```text
player_1
test_dummy_1
```

The bound instance HUD must show:

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

Implementation path:

- Add bind buttons to Creator Lab, or place them in Playground and call Creator Lab APIs.
- Preferred: buttons in Creator Lab top/tool row:
  - `Bind P`
  - `Bind D`
- Creator Lab emits signals:
  - `bind_player_requested`
  - `bind_dummy_requested`
- `Playground` connects those signals and calls `creator_lab.bind_instance(player)` or `creator_lab.bind_instance(dummy)`.
- `CreatorLabV03Panel.bind_instance(instance: Node)` stores only runtime-safe summary data plus a weak reference if needed.
- Binding loads `instance.template_id` into the v0.3 panel when that id exists in `data/v0_3/templates`.
- If the v0.3 template is missing, Creator Lab shows a visible status error and keeps the previous editable data.

### 4.2 Required Action Catalog

Add one catalog source:

```text
godot/scripts/creator_lab_action_catalog.gd
```

Class:

```gdscript
class_name CreatorLabActionCatalog
```

Public constants:

```gdscript
const FROZEN_STATES := ["idle", "walk", "dash", "jump", "hurt", "dead"]
const REQUIRED_ACTIONS := [
    {
        "action_id": "idle",
        "category": "utility",
        "state_context": "idle",
        "visual_role": "upright neutral loop",
        "backing": "move:idle",
        "required_this_wave": true,
    },
    ...
]
```

Required v1 entries:

```text
idle
walk
dash
jump_start
jump_air
jump_land
basic_punch
basic_kick
dash_attack
jump_attack
hurt_light
hurt_heavy
knockdown
get_up
dead
```

Deferred entries must not appear as required:

```text
run
turn
heavy_punch
round_kick
guard
stun
win_pose
```

Catalog helper methods:

```gdscript
static func required_actions() -> Array
static func action_ids() -> Array
static func action_for(action_id: String) -> Dictionary
static func backing_move_id(entry: Dictionary) -> String
static func backing_kind(entry: Dictionary) -> String
static func visual_role_for(action_id: String) -> String
```

`backing` grammar:

```text
move:<move_id>
coverage:<move_id>
move-or-placeholder:<move_id>
coverage-or-move:<move_id>
```

Rules:

- `move:` requires a concrete move fixture.
- `coverage:` uses an existing move as the timing/context reference but does not create a separate move.
- `move-or-placeholder:` should prefer a concrete move fixture when it exists; otherwise coverage may still preview placeholder mapping.
- `coverage-or-move:` supports reaction entries that may begin as sprite coverage and later become concrete moves.

### 4.3 Catalog Fixtures

Expand `data/v0_3` enough for coverage and editing without changing schemas.

Concrete move fixtures to add:

```text
data/v0_3/moves/basic_kick.json
data/v0_3/moves/dash_attack.json
data/v0_3/moves/jump_attack.json
data/v0_3/moves/hurt_light.json
data/v0_3/moves/hurt_heavy.json
data/v0_3/moves/knockdown.json
data/v0_3/moves/get_up.json
data/v0_3/moves/dead.json
```

Keep existing `hurt.json` for compatibility until no tests or callers depend on it. It is not a required v1 catalog entry.

Recommended fixture defaults:

| move_id | move_type | state_context_override | frames | damage | hitbox |
| --- | --- | --- | --- | --- | --- |
| basic_kick | combat | none | 8 | 10 | `hit_leg_1` |
| dash_attack | combat | dash | 8 | 9 | `hit_fist_1` |
| jump_attack | combat | jump | 8 | 9 | `hit_leg_1` |
| hurt_light | reaction | hurt | 4 | 0 | none |
| hurt_heavy | reaction | hurt | 6 | 0 | none |
| knockdown | reaction | hurt | 8 | 0 | none |
| get_up | reaction | hurt | 8 | 0 | none |
| dead | reaction | dead | 4 | 0 | none |

Template fixture update:

- Add concrete move-backed catalog entries to `data/v0_3/templates/combat_gray_s64.json.equipped_moves`.
- Do not add `jump_start`, `jump_air`, or `jump_land` to `equipped_moves`; they are coverage entries over `jump`.
- Do not store the required catalog in the template.

Sprite set fixture update:

- Add `required_moves_mapping` entries for all 15 required catalog entries.
- Add `animation_clips` for all mapped clip ids.
- Add `frame_sequences` for all mapped clips.
- Use unique sequence refs for `dead`, `knockdown`, `hurt_light`, and `hurt_heavy` so default fixtures do not trigger duplicate-idle warnings.
- Use `placeholder://combat_gray_s64/<action_id>/frame_000.png` style paths for placeholder frames.

Fixture policy:

- Placeholder warnings are allowed in default data.
- Missing/invalid mapping warnings should not appear in default data.
- Duplicate-idle warnings should not appear in default data.
- Schema validation must still pass.

### 4.4 Action Coverage Engine

Add one shared engine:

```text
godot/scripts/creator_lab_action_coverage.gd
```

Class:

```gdscript
class_name CreatorLabActionCoverage
```

Public API:

```gdscript
static func analyze(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> Dictionary
static func warnings_for_row(row: Dictionary) -> Array
static func is_placeholder_sequence(sequence: Array) -> bool
```

Result shape:

```gdscript
{
    "rows": [
        {
            "action_id": "dead",
            "category": "reaction",
            "state_context": "dead",
            "backing": "coverage-or-move:dead",
            "backing_move_id": "dead",
            "move_exists": true,
            "clip_id": "dead",
            "clip_exists": true,
            "frame_sequence_ref": "dead",
            "frame_sequence_exists": true,
            "sequence_frame_count": 4,
            "move_frame_count": 4,
            "visual_role": "final defeated pose",
            "warnings": [],
            "status": "OK",
        },
    ],
    "summary": {
        "ok": 0,
        "warning": 0,
        "fail": 0,
    },
}
```

Warning codes:

```text
MISSING_ANIMATION
PLACEHOLDER_ANIMATION
DUPLICATE_IDLE_FOR_DAMAGE_STATE
DUPLICATE_IDLE_FOR_DEAD_STATE
DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE
WRONG_FRAME_COUNT
MISSING_FRAME_SEQUENCE
MISSING_VISUAL_ROLE
INVALID_SPRITE_MAPPING
```

Algorithm:

1. Iterate `CreatorLabActionCatalog.required_actions()`.
2. Resolve `action_id` in `sprite_set.required_moves_mapping`.
3. Resolve the mapped clip in `sprite_set.animation_clips`.
4. Resolve `clip.frame_sequence_ref` in `sprite_set.frame_sequences`.
5. Resolve backing move id from the catalog entry.
6. If the backing move exists, compare `move.frame_count` to `sequence.size()`.
7. Compare `(clip_id, frame_sequence_ref)` for `dead`, `knockdown`, `hurt_light`, and `hurt_heavy` against idle.
8. Emit warnings using the exact PRD trigger table.

Severity:

- `OK`: no warnings.
- `WARNING`: placeholder or duplicate/fake visual warnings.
- `FAIL`: missing/invalid mappings, missing sequences, wrong frame count, or missing visual role.

Save policy:

- Existing schema/reference validation remains the blocking save gate.
- Coverage warnings are visible diagnostics.
- Coverage `FAIL` should be displayed prominently but should not replace schema validation unless the implementation explicitly routes it into `validate_current()`.
- Unsafe saves from malformed schema data, invalid numeric inputs, invalid event payloads, and invalid JSON remain blocked.

### 4.5 Creator Lab UI Integration

Update:

```text
godot/scripts/creator_lab_v0_3_panel.gd
```

Keep the class name for now:

```gdscript
class_name CreatorLabV03Panel
```

Do not rename the panel in this wave unless every smoke test and scene reference is updated in the same PR.

New panel state:

```gdscript
signal bind_player_requested
signal bind_dummy_requested

var bound_instance_id: String = ""
var bound_template_id: String = ""
var bound_sprite_set_id: String = ""
var bound_state: String = ""
var bound_move: String = ""
var bound_frame: int = 0
var bound_hp: String = ""
var bound_control_mode: String = ""

var coverage: Dictionary = {}
var current_action_id: String = "idle"
var preview_playing: bool = false
var preview_speed: float = 1.0
var preview_frame: int = 0
var preview_show_hurtboxes: bool = true
var preview_show_hitboxes: bool = true
var preview_show_foot: bool = true
```

New public methods:

```gdscript
func bind_instance(instance: Node) -> void
func update_bound_instance_summary(instance: Node) -> void
func refresh_action_coverage() -> Dictionary
func select_action(action_id: String) -> void
func preview_play() -> void
func preview_pause() -> void
func preview_step_forward() -> void
func preview_reset() -> void
func set_preview_speed(value: float) -> void
```

Navigation changes:

- Add `Instance` near the top of the left panel.
- Add `Action Coverage`.
- Add `Action Preview`.
- Keep existing `Character`, `Moves`, `Wardrobe`, and `Runtime` concepts.
- Do not add a fourth panel.

Recommended first-layer nav keys:

```text
instance_binding
action_coverage
action_preview
character_template
character_hurtboxes
character_foot
character_moves
move:<move_id>
wardrobe_mapping
wardrobe_clips
wardrobe_sequences
runtime_preview
```

UI behavior:

- Top/tool row shows `Bind P`, `Bind D`, `Save`, `Check`, `Reload`, `Roundtrip`.
- Instance detail shows selected instance debug fields.
- Coverage values panel lists required actions and color-codes status.
- Coverage detail panel shows the selected action row and warning list.
- Preview detail panel renders selected action with controls and overlays.
- Wardrobe detail uses the same coverage result, filtered to sprite-set/mapping fields.

Color guidance:

```text
OK = green
WARNING / placeholder = yellow
FAIL / invalid / missing = red
selected instance = blue
hitbox = red/orange
hurtbox = blue
foot collision = green
```

### 4.6 Preview Canvas

Preferred new file:

```text
godot/scripts/creator_lab_action_preview.gd
```

Class:

```gdscript
class_name CreatorLabActionPreview
extends Control
```

Public API:

```gdscript
func set_preview_data(row: Dictionary, template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void
func set_frame(frame_index: int) -> void
func set_overlay_visibility(show_hurtboxes: bool, show_hitboxes: bool, show_foot: bool) -> void
func frame_count() -> int
func current_status() -> String
```

Rendering:

- Fixed compact preview size, e.g. `Vector2(180, 128)` or available detail width.
- Draw dark tool background.
- Draw ground line.
- Draw origin / foot-center marker.
- If frame sequence resolves to `placeholder://`, draw a labeled placeholder silhouette/rectangle.
- If frame path resolves to a loadable texture later, draw the texture centered on origin.
- If missing/invalid, draw visible missing state text and keep overlays available.
- Draw hurtboxes from `template.hurtboxes`.
- Draw foot ellipse from `template.foot_collision`.
- Draw active hitboxes from selected move at current preview frame.
- Draw current frame indicator as `Frame X / N`.

Hitbox preview rule:

- Use `move.hitboxes[].active_window` and `move.active_window`.
- A hitbox is active when both the move active window and hitbox active window contain `preview_frame`.
- Do not depend on `PrdV03Runtime` events for overlay drawing in the first preview pass. Event-driven runtime preview remains available in the Runtime panel.

Playback:

- `CreatorLabV03Panel` may own the timer/process loop.
- Frame duration defaults to `1 / 12.0` seconds.
- `0.5x` doubles frame duration.
- `1x` uses default duration.
- Forward step wraps or clamps; choose one and show it consistently. Preferred: clamp at last frame until reset/play starts again.

### 4.7 Move Lab Editing

Existing fields already present:

```text
move_type
state_context_override
frame_count
active_window
damage
hitstop_frames
multi_hit
hitboxes[0]
events JSON
```

Required improvements:

- Keep `move_type` and `state_context_override` controls in Summary.
- When `frame_count` changes, preview frame clamps to valid range.
- When active window, hitbox rect, or hitbox active window changes, preview redraws immediately.
- When events are applied, run validation immediately and preserve visible failure status.
- Keep the current multi-hit explanation boundary: move-level permission only.
- Multi-hit does not create `hit_windows`, combo logic, or multiple simultaneous damage events.

Multi-hit text:

```text
multi_hit allows multiple frame-attached hit opportunities during one move. It does not make simultaneous hitboxes deal multiple hits by itself.
```

### 4.8 Foot Collision Runtime Logic

Update:

```text
godot/scripts/combat_character.gd
```

Current behavior:

```text
_clamp_foot_to_arena() clamps foot center to arena ellipse.
```

Required v1 behavior:

```text
_clamp_foot_to_arena() clamps the foot ellipse inside the arena ellipse.
```

Implementation rule:

- Use `foot_collision_profile.center` as the foot-center offset.
- Use `foot_collision_profile.radius` to reduce the available arena ellipse:

```gdscript
var foot_radius: Vector2 = foot_collision_profile.get("radius", Vector2.ZERO)
var effective_radius := Vector2(
    maxf(1.0, arena_radius.x - foot_radius.x),
    maxf(1.0, arena_radius.y - foot_radius.y)
)
```

- Clamp `foot_center_world()` inside `effective_radius` instead of full `arena_radius`.
- Move the character by `clamped_foot - foot`.
- The debug-drawn foot ellipse must still use the same `foot_collision_profile.center` and `foot_collision_profile.radius`.

Required smoke:

- Place a character near the right arena edge.
- Record clamped x position with small foot radius.
- Increase foot radius.
- Tick clamp again.
- Assert the character is clamped farther inward.
- Offset foot center and assert final global position changes accordingly.

### 4.9 Playground Integration

Update:

```text
godot/scripts/playground.gd
```

New state:

```gdscript
var selected_character: Node2D
```

New methods:

```gdscript
func select_character(character: Node2D) -> void
func select_player_character() -> void
func select_dummy_character() -> void
func selected_character_summary() -> Dictionary
```

Behavior:

- Default selected character is `player`.
- `select_character()` calls Creator Lab `bind_instance()` when the lab exists.
- Debug HUD includes selected instance id/template id in a compact line.
- `Playground._process()` may refresh the bound summary once per frame or at low frequency while Creator Lab is visible.
- Closing Creator Lab still calls `gui_release_focus()`.
- Do not add click hit testing in v1 unless bind buttons are already done and tested.

Runtime data caveat:

- Existing combat runtime still reads old `data/**` through `CharacterTemplate` / `CreatorDataStore`.
- Creator Lab v0.4 continues to edit `data/v0_3/**`.
- For this wave, "run or preview from Playground" means:
  - selected instance data is visible and bindable in Creator Lab,
  - v0.3 runtime preview runs inside Creator Lab,
  - foot collision arena clamp is proven in live `CombatCharacter`,
  - full migration of live combat runtime to v0.3 data is not required.

Do not pretend the old combat runtime is fully v0.3-backed until a separate migration PR does that work.

### 4.10 Save, Reload, and Validation

Keep existing methods:

```gdscript
save_all()
reload_current()
save_reload_exact()
validate_current()
```

Required changes:

- `save_all()` must still call blocking schema validation before writing.
- Invalid field input must not write coerced values.
- Coverage analysis must refresh after any template, move, or sprite-set edit.
- Roundtrip must include all edited v0.3 files that the panel can save.
- If `equipped_moves` is expanded, `save_reload_exact()` must include the expanded move set.
- Coverage warnings must remain visible after reload.
- Placeholder warnings must not block save.

Recommended separation:

```text
Blocking validation = malformed schema/runtime bundle
Coverage diagnostics = authoring readiness warnings/failures
```

## 5. Implementation Plan

### PR 1: Selected Instance Binding

Files:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/playground.gd
tools/runtime_smoke.gd
```

Work:

- Add bind signals/buttons.
- Add `bind_instance()` and bound summary state.
- Add instance nav/detail panel.
- Connect Playground player/dummy bind handlers.
- Update debug HUD with selected instance.
- Extend smoke to bind player, bind dummy, and assert displayed fields.

Exit criteria:

- Creator Lab can bind player and dummy.
- Bound HUD shows required fields.
- Existing focus smoke still passes.

### PR 2: Catalog and Fixture Expansion

Files:

```text
godot/scripts/creator_lab_action_catalog.gd
data/v0_3/templates/combat_gray_s64.json
data/v0_3/sprite_sets/combat_gray_s64.json
data/v0_3/moves/*.json
tools/validate_prd_v0_3.py
```

Work:

- Add catalog constant.
- Add required move fixtures.
- Add sprite-set mappings/clips/sequences for 15 required actions.
- Keep schema version `0.3`.
- Update Python validator only if it has hardcoded assumptions about current fixture count.

Exit criteria:

- Python validation passes.
- Existing Creator Lab smoke still loads and validates.
- No deferred catalog entries are required.

### PR 3: Shared Coverage Engine

Files:

```text
godot/scripts/creator_lab_action_coverage.gd
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
```

Work:

- Add `CreatorLabActionCoverage`.
- Add coverage result rows and warning codes.
- Replace `wardrobe_coverage()` internals or add a new method that uses the shared engine.
- Add Action Coverage nav/detail view.
- Keep old wardrobe summary labels if useful, but source them from shared coverage.

Smoke cases:

- Required action count is 15.
- Default data has no missing mapping/clip/sequence failures.
- Placeholder rows show `PLACEHOLDER_ANIMATION`.
- Temporarily map `dead` to idle and assert `DUPLICATE_IDLE_FOR_DEAD_STATE`.
- Temporarily remove a mapping and assert `INVALID_SPRITE_MAPPING`.
- Temporarily remove a sequence and assert `MISSING_FRAME_SEQUENCE`.
- Temporarily shorten a sequence and assert `WRONG_FRAME_COUNT`.

Exit criteria:

- Every warning code has at least one deterministic test path.
- Coverage table is visible and color-coded.

### PR 4: Realtime Preview Canvas

Files:

```text
godot/scripts/creator_lab_action_preview.gd
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
```

Work:

- Add preview Control.
- Add preview nav/detail.
- Add play/pause, step forward, reset, `0.5x`/`1x`.
- Add hurtbox/hitbox/foot overlay toggles.
- Render placeholder preview for `placeholder://` frames.
- Render missing/invalid preview state.
- Redraw on field edits.

Smoke cases:

- Select `basic_punch`, step forward, assert preview frame changes.
- Reset, assert frame returns to 0.
- Toggle overlays and assert preview state flags change.
- Edit hitbox rect and assert preview model uses new rect.
- Edit foot radius and assert preview model uses new radius.

Exit criteria:

- Preview is nonblank in Godot AI / screenshot inspection.
- Frame counter and overlays are readable in the existing compact panel.

### PR 5: Move Lab Live Editing Hardening

Files:

```text
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
```

Work:

- Ensure `move_type` and `state_context_override` controls are tested.
- Clamp preview frame after frame count edits.
- Refresh coverage after move edits.
- Preserve visible validation failure after events apply.
- Improve multi-hit explanatory hint.

Smoke cases:

- Change `state_context_override` to `jump`, validate, save/reload, assert persisted.
- Change `move_type`, validate, save/reload, assert persisted.
- Change frame count below current preview frame, assert preview frame clamps.
- Bad event payload blocks save and shows failure.

Exit criteria:

- Move Lab can edit every schema-backed field listed in PRD Section 9.

### PR 6: Foot Collision Arena Clamp

Files:

```text
godot/scripts/combat_character.gd
tools/runtime_smoke.gd
```

Work:

- Change clamp to use effective arena radius reduced by foot radius.
- Keep debug ellipse drawing from the same foot profile.
- Add runtime smoke proving radius and offset affect clamp.

Smoke cases:

- Larger radius clamps farther inward.
- Smaller radius allows closer boundary position.
- Center offset changes final character position.
- Debug ellipse still uses same profile.

Exit criteria:

- Editing foot collision changes real runtime boundary behavior.
- Existing combat hit/damage smoke still passes.

### PR 7: Wardrobe Coverage View

Files:

```text
godot/scripts/creator_lab_v0_3_panel.gd
tools/creator_lab_v0_3_smoke.gd
```

Work:

- Wardrobe views use shared coverage rows.
- Show sprite set id, action-to-clip mapping, missing, placeholder, invalid, sequence, frame count.
- Keep generation entry stub only.

Exit criteria:

- Wardrobe and Action Coverage report the same warning counts for the same data.

### PR 8: Save/Reload, Focus, and UAT Hardening

Files:

```text
godot/scripts/creator_lab_v0_3_panel.gd
godot/scripts/playground.gd
tools/creator_lab_v0_3_smoke.gd
tools/runtime_smoke.gd
tools/prd_v0_3_runtime_smoke.gd
```

Work:

- Finalize roundtrip coverage after expanded fixtures.
- Add blocked-save smoke for invalid schema data.
- Keep Creator Lab close-focus smoke.
- Add F5 UAT checklist to PR body or issue comment.
- Verify no field submit double-rebuild regression.

Exit criteria:

- All required commands pass.
- Manual F5 UAT confirms gameplay input after launch and after Creator Lab close.

## 6. Testing Matrix

Required commands for every implementation PR:

```bash
uv run --with-requirements requirements-dev.txt python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
```

Required GitNexus commands before editing existing symbols:

```bash
node .gitnexus/run.cjs impact <symbol> --direction upstream --repo SpritesPlayground
```

Required GitNexus command before commit/handoff:

```bash
node .gitnexus/run.cjs detect_changes --repo SpritesPlayground --scope compare --base-ref main
```

Manual UAT checklist:

```text
F5 launch from Godot editor
gameplay input works immediately
open Creator Lab
bind player
bind dummy
select Action Coverage
select Action Preview
play/pause/step/reset preview
edit hitbox and see preview update
edit hurtbox and see preview update
edit foot radius and see preview update
close Creator Lab
gameplay input works again
move to arena boundary with small radius
move to arena boundary with larger radius
confirm larger radius clamps farther inward
```

Godot AI visual verification:

- Use Godot AI to inspect the running game after preview work lands.
- Capture the Creator Lab panel with Action Preview visible.
- Verify the preview canvas is nonblank.
- Verify labels fit inside the compact panel.
- Verify overlay colors are distinguishable.
- Verify no UI text overlaps after selecting a long action id such as `DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE`.

## 7. GitNexus Impact Targets

Run impact before modifying these existing symbols:

```text
CreatorLabV03Panel.setup
CreatorLabV03Panel.load_template_id
CreatorLabV03Panel.save_all
CreatorLabV03Panel.save_reload_exact
CreatorLabV03Panel.validate_current
CreatorLabV03Panel.wardrobe_coverage
CreatorLabV03Panel._build_ui
CreatorLabV03Panel._refresh_navigation
CreatorLabV03Panel._build_values_panel
CreatorLabV03Panel._build_detail_panel
CreatorLabV03Panel._refresh_fields
CreatorLabV03Panel._on_box_fields_submitted
Playground._ready
Playground._build_creator_lab
Playground._update_debug_gui
Playground.toggle_creator_lab
CombatCharacter._clamp_foot_to_arena
CombatCharacter._draw
PrdV03DataStore.validate_runtime_bundle
PrdV03Runtime.debug_summary
```

If GitNexus cannot resolve a GDScript symbol, record the failed impact lookup in the PR notes and do manual blast-radius review over direct callers.

## 8. Acceptance Mapping

| PRD acceptance | Spec implementation |
| --- | --- |
| Select/bind player and NPC | PR 1 bind buttons/signals and Playground selection state |
| Selected instance HUD fields | PR 1 instance detail + debug HUD |
| Realtime preview | PR 4 preview canvas |
| Play/pause/step/reset/speed | PR 4 controls |
| Overlay toggles | PR 4 preview state |
| Immediate edit preview | PR 4 + PR 5 refresh hooks |
| Required action catalog | PR 2 catalog |
| Completeness panel | PR 3 coverage UI |
| Warning codes | PR 3 deterministic engine/tests |
| Move Lab editing | PR 5 |
| Foot collision affects runtime | PR 6 clamp update |
| Wardrobe coverage | PR 7 shared coverage view |
| Roundtrip and blocked save | PR 8 |
| F5 focus | PR 8 runtime smoke + manual UAT |

## 9. Out of Scope

Do not implement these in this wave:

- new schema version
- saved per-instance override data
- click hit testing if bind buttons are not complete
- live combat runtime migration to v0.3 data
- real PixelLab or AI generation
- weapon/projectile/combo systems
- frame strip/timeline UI
- reverse frame stepping
- standalone launch as a required gate
- player/NPC spacing logic
- room/lab trigger collision

## 10. Review Prompt

Use this prompt for implementation-spec review:

```text
Review docs/IMPLEMENTATION_SPEC_V0_4_ACTION_AUTHORING_TOOL.md against docs/PRD_v0.4_ACTION_AUTHORING_TOOL.md, issue #13, current Godot scripts, and v0.3 schemas.

Take a strict senior-engineer implementation-review stance.

Check:
1. Does the spec implement every PRD acceptance criterion?
2. Are any implementation slices too large or hiding architecture risk?
3. Are any proposed files/APIs inconsistent with current GDScript code style?
4. Are fixture changes schema-valid and minimal?
5. Are warning-code algorithms deterministic and testable?
6. Does foot collision runtime behavior use the real debug ellipse data?
7. Are save/reload and focus-loss regressions covered?
8. Are there any contradictions with the frozen v0.3 model?

Return findings first, ordered by severity, with file/section references.
End with an explicit verdict: PASS or FAIL for starting implementation.
```
