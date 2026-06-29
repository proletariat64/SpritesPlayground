# SpritesPlayground Rebuild Milestone Spec

Status: draft for Milestone 1 implementation
Updated: 2026-06-29
Scope: runtime rebuild blueprint plus Milestone 1 execution contract

## 1. Product Target

Milestone 1 is the first end-to-end rebuild slice. It must deliver a polished playable combat prototype and the Genesis authoring baseline in the same running Godot project.

The goal is to validate the complete product chain:

```md
Genesis JSON authoring
-> explicit save
-> validation
-> runtime load
-> Adam vs Cain playable combat
-> debug proof of state, move, segment, frame, input, HP, and collision overlays
```

This milestone is not a narrow runtime proof, not a legacy restoration, and not a general engine rewrite. It proves that the rebuild can author source JSON, load it into a shared actor runtime, execute LimboAI-first state transitions, resolve MoveData-owned hitboxes against CharacterTemplate-owned hurtboxes, and present a playable pixel-action prototype.

## 2. Milestone 1 Visible Result

Opening the Godot project must enter a polished prototype shell with two primary surfaces:

| Surface | Required Result |
| --- | --- |
| `Genesis` | Select, edit, validate, save, reload, and smoke-run Adam and Cain SpriteDefinition JSON. |
| `Playground` | Run Adam vs Cain combat using the saved JSON definitions. |

In Playground:

- Adam moves with `WASD`.
- `J` starts `basic_punch`.
- `J/J/J` inside gate windows advances `basic_punch_3hit` segments.
- Cain is an enemy dummy that can be hit, lose HP, enter `hurt`, and enter `dead` when HP is `<= 0`.
- The screen shows HP bars, current state, current move, segment, authored frame, runtime frame/tick if exposed, and input buffer.
- Hitbox, hurtbox, foot anchor, and debug overlay visibility can be toggled without changing combat logic.

In Genesis:

- Adam and Cain can be selected.
- Identity, spawn, input, move loadout, hurtbox, HP, and SpriteSet coverage can be reviewed and edited where they are source fields.
- Save explicitly writes JSON.
- Validate shows blocking errors and does not silently patch malformed source fields.
- Playground Smoke starts runtime from the saved JSON, not from unsaved UI draft state.

## 3. Source Truth Decisions

| Decision | Contract |
| --- | --- |
| JSON source truth | Authoring JSON is the authoritative data source for M1. |
| Godot Resource boundary | Godot resources may exist only as runtime adapters, generated caches, or presentation assets. They must not become authoring truth. |
| Shared actor scene | Use one `RuntimeActor.tscn`; no per-character actor scenes. |
| State driver | `StateDriver` is LimboAI-first and uses LimboAI concepts for state orchestration. |
| Genesis form | Genesis is a Godot `Control` scene, not a Godot editor plugin or toolbar button. |
| Art strategy | Create lightweight pixel placeholder assets from scratch for Adam, Cain, stage, and effects. |
| Legacy boundary | Do not restore `data/v0_3`, old tools, old scenes, or old runtime scripts as M1 implementation sources. Historical material can be reference only. |

## 4. Data Contracts

Milestone 1 must introduce these JSON source files:

```md
data/rebuild/characters/adam.json
data/rebuild/characters/cain.json
data/rebuild/moves/basic_punch.json
data/rebuild/moves/basic_punch_3hit.json
data/rebuild/sprite_sets/adam.json
data/rebuild/sprite_sets/cain.json
```

The implementation may add schema files, validation reports, and generated caches, but these six records are the minimum source-truth data set.

### 4.1 Character Records

`adam.json` and `cain.json` must be valid SpriteDefinition records that include at least:

- stable identity fields: id, display name, role/faction.
- spawn defaults: position policy or scene placement handoff, facing, HP initialization.
- input policy: Adam receives player input; Cain is enemy dummy or AI-disabled M1 target unless a later AI slice is added.
- move loadout: Adam includes `basic_punch` and `basic_punch_3hit`; Cain may omit player attack moves if it remains a dummy.
- `hp_max`.
- foot collision.
- body collision.
- character-owned hurtboxes with `id`, `rect`, `priority`, optional `def`, and enabled state.
- SpriteSet reference.

Missing hurtbox `def` means `0`.

### 4.2 Move Records

`basic_punch.json` must be a single-segment MoveData record with:

- id `basic_punch`.
- category `combat`.
- state event `ev_attack`.
- input command bound to `J` / `attack_light`.
- side-facing visual policy for baseline attack coverage.
- one segment with startup, active, and recovery frames.
- at least one MoveData-owned hitbox with `id`, `rect`, active window, and `atk`.
- finish event `ev_finished`.

`basic_punch_3hit.json` must be one segmented MoveData record, not three states and not three separate combo state nodes. It must include:

- id `basic_punch_3hit`.
- category `combat`.
- state event `ev_attack`.
- segment policy `linear_continue`.
- three ordered segments.
- segment gates that accept `J` / `attack_light` inside explicit frame windows.
- one attack instance for each segment or an equivalent segment-derived attack instance id.
- finish event `ev_finished`.

### 4.3 SpriteSet Records

`adam.json` and `cain.json` under `data/rebuild/sprite_sets/` must represent visual coverage truth for M1:

- idle coverage.
- walk coverage for Adam movement.
- attack coverage for `basic_punch` and `basic_punch_3hit`.
- hurt coverage for Cain.
- dead coverage for Cain.
- placeholder status/provenance for assets created in M1.

SpriteSet records own visual coverage and frame sequence references. They do not own damage, hit logic, HP, or state transitions.

### 4.4 Round Trip Rule

JSON load, edit, save, reload, and runtime load must preserve source truth.

Validation, runtime adapters, and generated resources may normalize internal runtime views, but they must not silently rewrite source fields. Any source mutation must come from explicit Save or explicit confirmed Rescan behavior.

## 5. Runtime Contracts

`RuntimeActor.tscn` is shared by all actors. Actor instances differ by scene placement and `definition_path` only.

Required actor tree:

```md
RuntimeActor : CharacterBody2D
|-- CollisionBody
|   |-- FootCollisionShape
|   `-- BodyCollisionShape
|-- StateDriver
|-- RuntimeBlackboard
|-- InputSystem
|-- MoveRuntime
|-- CombatPorts
|   |-- HitboxSource
|   `-- HurtboxReceiver
|-- LifeRuntime
`-- VisualPresenter
    |-- SpriteSetPlayer
    |-- HealthBars
    `-- DebugOverlay
```

Allowed instance-level scene differences:

- node name.
- scene position/transform.
- `definition_path`.
- scene grouping for spawn/debug use.

Forbidden instance-level scene differences:

- per-character HP, DEF, hurtboxes, hitboxes, timing, move loadout, or SpriteSet coverage edited directly in scene files.
- generated per-character actor scenes.
- runtime blackboard values persisted as authoring truth.

## 6. State and Move Contracts

`StateDriver` must use LimboAI-first orchestration. If a temporary fallback is required during early implementation, it must be documented as a blocker with a replacement path back to LimboAI; the fallback must not become the accepted M1 architecture.

Required M1 states:

| State | Purpose |
| --- | --- |
| `idle` | Neutral state with no movement input or committed move. |
| `walk` | Adam movement state driven by `WASD`. |
| `attack` | Committed MoveData execution state. |
| `hurt` | Reaction state after accepted hit. |
| `dead` | Terminal state after HP reaches `<= 0`. |

Required M1 events:

| Event | Producer | Consumer |
| --- | --- | --- |
| `ev_move` | InputSystem or AI intent | StateDriver |
| `ev_stop` | InputSystem or AI intent | StateDriver |
| `ev_attack` | InputSystem or MoveRuntime request | StateDriver / MoveRuntime |
| `ev_hurt` | CombatResolver / HurtboxReceiver | StateDriver |
| `ev_dead` | LifeRuntime | StateDriver |
| `ev_finished` | MoveRuntime or hurt behavior | StateDriver |

`basic_punch_3hit` uses MoveData segment gates. It must not add per-segment states such as `attack_1`, `attack_2`, or `attack_3`.

## 7. Combat Contracts

Hitboxes belong to MoveData. Hurtboxes belong to CharacterTemplate.

Damage formula:

```gdscript
max(0, hitbox_atk - selected_hurtbox_def)
```

Rules:

- Missing selected hurtbox DEF defaults to `0`.
- Direct `damage` fields are not gameplay truth in M1.
- One `attack_instance_id + hitbox_id + target_id` can hit once.
- A segment can create a new attack instance, allowing the next segment of `basic_punch_3hit` to hit the same target once.
- Same-frame multi-hurtbox contact resolves to one selected hurtbox.
- Same-frame selection order is priority first, then smallest area, then registration order.
- CombatResolver owns cross-actor traversal, intersection, hit-once registry, formula application, and HurtResult dispatch.
- LifeRuntime applies final damage and emits `ev_dead` when HP reaches `<= 0`.
- StateDriver consumes `ev_hurt` and `ev_dead`; combat resolution does not directly choose animation clips.

## 8. Genesis Contracts

Genesis is a Godot `Control` scene in M1.

Required surfaces:

- character selector for Adam and Cain.
- detail editor for editable source fields.
- validation drawer or equivalent blocking-error surface.
- raw JSON review or source-preview surface sufficient to confirm saved truth.
- Playground Smoke command that loads saved JSON into the runtime.

Required behavior:

- Genesis edits a draft in memory.
- Save is explicit and writes JSON.
- Reload discards unsaved draft changes only after user intent is clear.
- Validate reports blocking errors and warnings without silently mutating source fields.
- Missing required fields are shown as validation issues, not auto-created hidden defaults.
- Rescan may update scanned/coverage status only after confirmation.
- Rescan must not change combat, state, HP, hitbox, or hurtbox truth.
- Genesis may show friendly labels, but saved IDs remain canonical, for example `basic_punch` and `basic_punch_3hit`.

Not included in M1:

- Godot editor plugin button.
- pixel-art editor.
- animation frame editor.
- generalized asset database.
- branch-combo authoring beyond the required linear segment gate case.

## 9. Visual Target

M1 must look like a polished prototype, not an empty technical harness.

Required visual assets:

- lightweight pixel-art placeholder Adam.
- lightweight pixel-art placeholder Cain.
- simple but polished pixel stage background.
- readable HP bars.
- state/move/debug HUD.
- toggleable hitbox overlay.
- toggleable hurtbox overlay.
- toggleable foot anchor / collision debug marker.

Placeholder art is acceptable. Production art is not required. The placeholder assets must be new rebuild assets and must not depend on restoring the old build.

## 10. Implementation Boundaries

Required:

- build from `data/rebuild`.
- keep runtime components thin and project-specific.
- use Godot primitives for scene, body, collision, file access, JSON, UI, and rendering.
- use LimboAI-first StateDriver architecture.
- keep JSON authoring truth separate from runtime blackboard and generated cache data.
- add only the minimum data, scenes, scripts, and assets required to complete M1.

Forbidden:

- restoring old `data/v0_3` as the active implementation.
- reviving old runtime scripts as authoritative rebuild code.
- generating per-character actor scenes.
- making Godot Resource files the source of authoring truth.
- using animation names as gameplay logic.
- mutating source JSON from validation or runtime load.
- making hitbox/hurtbox overlay state affect combat logic.

## 11. Acceptance Checks

Milestone 1 is accepted only when these checks pass:

| Check | Expected Result |
| --- | --- |
| `godot --headless --path . --quit` | Project opens cleanly. |
| Genesis loads Adam/Cain JSON | Both definitions are selectable and displayed. |
| Genesis save -> reload | Saved JSON is preserved and reloaded without source-truth drift. |
| Malformed SpriteDefinition validation | Blocking errors are shown; source is not silently patched. |
| Playground spawn | Adam and Cain spawn from JSON via `RuntimeActor.tscn` instances. |
| `D` press | Adam moves and enters `walk`. |
| movement release | Adam returns to `idle`. |
| `J` press | Adam enters `attack` and starts `basic_punch`. |
| `J/J/J` inside gates | `basic_punch_3hit` advances through its required segments. |
| Cain hit | Cain receives HurtResult, enters `hurt`, and HP decreases by formula. |
| Cain HP `<= 0` | Cain enters `dead`. |
| Debug HUD | Reports state, move, segment, authored frame, input buffer, and HP. |
| Overlay toggles | Hitbox, hurtbox, and foot anchor overlays render without affecting combat logic. |

Automated and manual checks should both record enough evidence to distinguish:

- configured vs loaded.
- JSON source truth vs generated runtime adapter.
- state transition vs visual-only change.
- overlay display vs combat collision behavior.

## 12. Milestone Exit Criteria

M1 is complete when:

- Adam/Cain source JSON files exist under `data/rebuild`.
- `basic_punch` and `basic_punch_3hit` MoveData records execute from JSON.
- Genesis can edit, validate, save, reload, and smoke-run Adam/Cain.
- Playground can run Adam vs Cain using saved JSON.
- Combat formula, hit-once registry, segment gates, hurt, HP loss, and death are observable.
- Debug HUD and overlays provide enough runtime evidence to diagnose failures.
- No legacy build path is required for normal M1 execution.

## 13. Later Milestones

These are intentionally outside M1:

- Eva ally AI.
- Solomen neutral interaction systems.
- full AI combat for Cain.
- production art pipeline.
- external pixel-art editing integration.
- Godot editor plugin integration for Genesis.
- local Git hook CI/CD.
- generalized combo tree with same-prefix branching.
- projectile, weapon, multiplayer, or full level progression systems.
