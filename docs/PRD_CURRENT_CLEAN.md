---
title: SpritesPlayground PRD - Current Clean Version
tags:
  - prd
  - spritesplayground
  - godot
status: current-clean
updated: 2026-06-26
supersedes:
  - PRD.md
  - PRD_v0.3.md
  - PRD_v0.4_ACTION_AUTHORING_TOOL.md
  - PRD_v0.4.1_ACTION_AUTHORING_TOOL_ADDON.md
  - PRD_v0.4.2_PLAYGROUND_MULTI_NPC_PREVIEW.md
  - PRD_v0.5_RUNTIME_SPRITEFRAMES_PIPELINE.md
---

# SpritesPlayground PRD：Current Clean Version

## 0. Product Boundary

SpritesPlayground 是 Godot 里的 2D pixel ACT sprite / combat authoring lab。

它负责：

```text
环境规则 -> sprite 数据 -> move 数据 -> frame 事件 -> preview -> runtime playground -> validation
```

它不是：

- 正式关卡游戏
- combo tree / weapon / projectile 完整系统
- art generation tool
- raw GIF / sheet / ZIP / Aseprite importer
- 深继承角色模板系统
- 用动画名驱动 gameplay 的系统

硬规则：

```text
State = 控制/物理上下文
Move + category = behavior unit
Frame = 唯一时间单位
Event = frame-attached instruction
SpriteSet = visual frame source
CharacterTemplate = character-owned collision/status/equipment
Runtime = schema 数据的执行结果
```

---

## 1. Stage 0：World Rules & Environment

Stage 0 在任何 Sprite Create 之前完成。它只定义项目共享环境，不定义单个 sprite 的动作细节。

### 1.1 World Rules

| Rule | Current Contract |
| --- | --- |
| `game_style` | 2D pixel ACT side-scroll arcade |
| `timeline` | Frame + FPS 是唯一时间线；禁止用 seconds 作为 gameplay 数据主单位 |
| `default_fps` | 12 FPS；1 frame = 1 beat |
| `logical_resolution` | 640×360，16:9；gameplay 坐标、camera、stage layout 以此为准 |
| `screen_resolution` | 1280×720，16:9；演示窗口 / QA 观察窗口 |
| `logical_pixel_size` | 2×2 screen pixels |
| `texture_filter` | nearest / pixel perfect；禁止模糊采样 |
| `sprite_palette` | Sprite 默认 Lospec EDG64 |
| `scene_palette` | 不强制限制；但必须服务于 sprite 可读性 |
| `sprite_size_model` | 使用 size class，不让单个角色随意自定义基础尺寸模型 |
| `current_s_class_contract` | S class 当前按 80×80 Godot frame contract 设计 |
| `origin` | character-local foot-center ground point |
| `collision_space` | 2D side-scroll；z 只用于 layer / depth / priority，不是自由 3D 空间 |
| `visibility` | 缺图、占位、错误映射、失败验证必须显式可见 |
| `override_rule` | 偏离 Stage 0 必须写明原因、影响范围、验证方式 |

### 1.2 Environment Data

```json
{
  "game_style": "2D pixel ACT side-scroll arcade",
  "timeline": "frame_based",
  "default_fps": 12,
  "frame_unit": "1 frame = 1 beat",
  "logical_resolution": { "w": 640, "h": 360 },
  "screen_resolution": { "w": 1280, "h": 720 },
  "logical_pixel_size": { "x": 2, "y": 2 },
  "sprite_palette": "Lospec EDG64",
  "scene_palette": "unrestricted",
  "default_sprite_class": "s_class",
  "s_class_contract": { "w": 80, "h": 80 },
  "collision_space": "2d_side_scroll",
  "z_axis_rule": "layer_depth_priority_only",
  "missing_asset_visibility": "required",
  "silent_fallback": "forbidden"
}
```

Stage 0 输出：`World Rules`、`Environment Data`、`Validation Boundary`、`Sprite Create Default Input`、`Debug Visibility Contract`。

---

## 2. Frozen Core Model

### 2.1 State

State 只表达控制/物理上下文，不表达具体攻击、受击动画、combo 或 art variant。

Frozen states:

```text
idle
walk
dash
jump
hurt
dead
```

禁止：

- `walk_start` / `walk_stop` 作为 State
- `run_state`
- `attack_state`
- `knockdown_state`
- 用动画名生成 State

允许：

- `run` 是 walk context 的 move / speed variant
- `jump_start` / `jump_air` / `jump_land` 是 visual coverage，不是新 State
- `hurt_light` / `hurt_heavy` / `knockdown` / `get_up` 是 reaction move / coverage，不是新 State

### 2.2 Move

Move 是唯一 editable gameplay unit。

```text
Move = category + frame_count + timing + boxes + damage/status effect + events
```

Move categories:

```text
locomotion
combat
reaction
utility
```

Move rules:

- Move 用 frame 驱动。
- Move owns hitboxes。
- Move owns active window。
- Move owns damage / hitstop / velocity events。
- Move 可以带 `state_context_override`，但不能创造新 State。
- `move_id` 必须稳定、schema-valid、可被 SpriteSet 映射。

### 2.3 Frame

Frame 是唯一 timing unit。

- `frame_count` 定义 move/action 长度。
- `active_window`、hitbox window、event frame、preview slider、runtime frame index 都用 frame。
- 秒只允许用于 UI 辅助显示，不写入 gameplay 数据。

### 2.4 Event

FrameEvent 是 frame-attached instruction。

Current event types:

```text
enable_hitbox
disable_hitbox
set_velocity
apply_hitstop
change_state_context
```

Example:

```text
Frame 3 -> enable_hitbox(hit_fist_1)
Frame 5 -> disable_hitbox(hit_fist_1)
Frame 5 -> apply_hitstop(3)
```

---

## 3. Data Structures

Current schema version remains `0.3` until an explicit migration is approved。

### 3.1 CharacterTemplate

Character-owned data only。

```json
{
  "schema_version": "0.3",
  "template_id": "combat_gray_s64",
  "sprite_set_ref": "combat_gray_s64",
  "hurtboxes": {
    "hurt_head": { "x": -12, "y": -64, "w": 24, "h": 18 },
    "hurt_upper_body": { "x": -16, "y": -46, "w": 32, "h": 24 },
    "hurt_lower_body": { "x": -14, "y": -22, "w": 28, "h": 22 }
  },
  "foot_collision": {
    "center": { "x": 0, "y": -4 },
    "radius": { "x": 18, "y": 8 }
  },
  "hp": 100,
  "equipped_moves": ["idle", "walk", "dash", "basic_punch", "hurt", "dead"]
}
```

Rules:

- Hurtbox belongs to character/template。
- Foot collision belongs to character/template。
- HP 当前属于 template baseline。
- Equipped moves 是可用 move pool。
- 不存 legacy `action` / `actions` / `attack` / `base_action_set` / `base_actions` / `base_attack_moves`。
- 不存 seconds fields。

### 3.2 MoveTemplate

Move-owned gameplay data only。

```json
{
  "schema_version": "0.3",
  "move_id": "basic_punch",
  "move_type": "combat",
  "state_context_override": "idle",
  "frame_count": 8,
  "active_window": { "start_frame": 3, "end_frame": 5 },
  "damage": 8,
  "hitstop_frames": 3,
  "hitboxes": [
    {
      "hitbox_id": "hit_fist_1",
      "active_window": { "start_frame": 3, "end_frame": 5 },
      "rect": { "x": 12, "y": -48, "w": 24, "h": 14 }
    }
  ],
  "multi_hit": false,
  "events": [
    { "frame": 3, "event_type": "enable_hitbox", "payload": { "hitbox_id": "hit_fist_1" } },
    { "frame": 5, "event_type": "disable_hitbox", "payload": { "hitbox_id": "hit_fist_1" } },
    { "frame": 5, "event_type": "apply_hitstop", "payload": { "frames": 3 } }
  ]
}
```

Rules:

- Hitbox belongs to move。
- Hitbox id pattern: `hit_[a-z0-9_]+`。
- Rect is character-local: `{ x, y, w, h }`。
- `multi_hit = false`：同一 move 对同一 target 在同一 active window 只结算一次 hit。
- `multi_hit = true`：允许多段 frame-attached hit opportunity；不是 combo system，不是多 hitbox 自动多伤害。

### 3.3 SpriteSet

Sprite-owned visual mapping data only。

```json
{
  "schema_version": "0.3",
  "sprite_set_id": "combat_gray_s64",
  "animation_clips": {
    "idle": { "clip_id": "idle", "frame_sequence_ref": "idle", "loop": true },
    "basic_punch": { "clip_id": "basic_punch", "frame_sequence_ref": "basic_punch", "loop": false }
  },
  "frame_sequences": {
    "idle": [
      "placeholder://combat_gray_s64/idle/frame_000.png",
      "placeholder://combat_gray_s64/idle/frame_001.png"
    ],
    "basic_punch": [
      "res://godot/assets/sprites/combat_gray_s64/basic_punch/frame_000.png",
      "missing://combat_gray_s64/basic_punch/frame_001.png"
    ]
  },
  "required_moves_mapping": {
    "idle": "idle",
    "basic_punch": "basic_punch"
  }
}
```

Frame URI schemes:

| Scheme | Meaning |
| --- | --- |
| `res://...png` | committed/imported Godot asset |
| `user://...png` | local experiment; allowed only if runtime can load it in UAT |
| `placeholder://...` | explicit placeholder visual |
| `missing://...` | expected art missing |
| `empty://...` | intentional timing slot without art |

Rules:

- `animation_clips` maps clip id to frame sequence。
- `frame_sequences` preserves ordered timing slots。
- Empty/missing/placeholder slots still count as real frames。
- SpriteSet never owns hitboxes, damage, HP, or AI。
- Raw GIF / sheet / ZIP / Aseprite are source material, not runtime dependencies。

### 3.4 Generated Runtime SpriteFrames

Save/apply generates or refreshes:

```text
res://godot/resources/sprite_frames/<sprite_set_id>.tres
```

Rules:

- Resource type: `SpriteFrames`。
- Animation name = `clip_id`。
- Frames come from `frame_sequences[frame_sequence_ref]`。
- Loop flag comes from clip metadata。
- FPS default = `12.0` unless explicitly supported by approved data。
- Empty/missing/placeholder slots produce stable visible placeholder textures。
- Generation must not drop slots to make animation pass。
- Commit-ready `.tres` should reference imported `res://` textures when real frames exist, not hide large inline image payloads。

### 3.5 Runtime Character State

Runtime state is execution state, not authoring schema source of truth。

```json
{
  "instance_id": "npc_001",
  "template_id": "skeleton_default_unarmed_s64",
  "sprite_set_id": "skeleton_default_unarmed_s64",
  "control_mode": "ai",
  "current_state": "walk",
  "current_move": "walk",
  "current_frame": 2,
  "hp": 100,
  "velocity": { "x": 0, "y": 0 },
  "hitstop_frames_left": 0,
  "debug_boxes_visible": true,
  "selected": false
}
```

Runtime-only fields:

- selected instance
- current frame index
- current active hitbox list
- per-move/per-target hit registry
- AI/manual mode
- hitstop counter
- depth order / z-index
- transient status feedback

### 3.6 Status / Package Boundary

Current persisted v0.3 baseline:

```text
HP only
```

Allowed future packages, only after explicit schema/spec migration:

```text
stamina_bar_package
defense_buffer_package
debuff_status_package
buff_status_package
```

Rules:

- Status effect is not a new State。
- Buff/debuff modifies move/state execution data, not enum count。
- Do not fake stamina or debuff in UI unless runtime and data both own it。
- Health/stamina bars are UI views over status data, not gameplay source of truth。

---

## 4. Action Catalog

Action catalog is authoring/coverage diagnostics, not a schema field inside CharacterTemplate / MoveTemplate / SpriteSet。

Current required action coverage:

| action_id | category | state_context | backing |
| --- | --- | --- | --- |
| `idle` | utility | idle | move:idle |
| `walk` | locomotion | walk | move:walk |
| `run` | locomotion | walk | move:run |
| `turn` | locomotion | idle | move:turn |
| `dash` | locomotion | dash | move:dash |
| `jump` | locomotion | jump | move:jump |
| `jump_start` | locomotion | jump | coverage:jump |
| `jump_air` | locomotion | jump | coverage:jump |
| `jump_land` | locomotion | jump | coverage:jump |
| `basic_punch` | combat | idle | move:basic_punch |
| `basic_kick` | combat | idle | move:basic_kick |
| `heavy_punch` | combat | idle | move:heavy_punch |
| `round_kick` | combat | idle | move:round_kick |
| `guard` | combat | idle | move:guard |
| `dash_attack` | combat | dash | move-or-placeholder:dash_attack |
| `jump_attack` | combat | jump | move-or-placeholder:jump_attack |
| `hurt` | reaction | hurt | move:hurt |
| `hurt_light` | reaction | hurt | coverage-or-move:hurt_light |
| `hurt_heavy` | reaction | hurt | coverage-or-move:hurt_heavy |
| `knockdown` | reaction | hurt | coverage-or-move:knockdown |
| `get_up` | reaction | hurt | coverage-or-move:get_up |
| `stun` | reaction | hurt | move:stun |
| `dead` | reaction | dead | coverage-or-move:dead |
| `win_pose` | utility | idle | move:win_pose |

Visual states shown by diagnostics:

```text
VALID_ANIMATION
MISSING_ANIMATION
PLACEHOLDER_ANIMATION
EMPTY_SLOT
INVALID_MAPPING
DUPLICATED_OR_FAKE_MAPPING
```

Rules:

- Missing/placeholder/invalid must be visible in Creator Lab and validation output。
- Duplicate-idle fake mapping must be flagged。
- Catalog entry may be backed by a move or by visual coverage over an existing move。
- Catalog does not create new State。

---

## 5. Hit / Hurt / Collision Model

### 5.1 Hurtboxes

- Character owns hurtboxes。
- Multiple hurtboxes allowed。
- Contact resolves one prioritized hurtbox for damage/hit result。
- Other overlapping boxes may show feedback/debug only。

### 5.2 Hitboxes

- Move owns hitboxes。
- Hitboxes activate/deactivate through frame events and active windows。
- Same active window cannot cause duplicate damage unless `multi_hit = true` and separate frame opportunity exists。

### 5.3 Foot Collision

Each character has one foot collision ellipse。

Used for:

- ground occupancy
- arena boundary clamp
- room/trigger contact
- character spacing
- depth ordering reference

Not used for:

- attack damage
- hurt detection
- visual body wall feeling

Foot collision edits must prove visible runtime behavior, not just JSON diff。

### 5.4 Hitstop

- Hitstop freezes movement、animation、hitbox evaluation。
- Default is move-defined or global fallback。
- Current target range: 2–5 frames for normal hits。

---

## 6. Playground Runtime

Playground is the runtime validation surface。

Required runtime behavior:

- 640×360 logical arena, displayed in 1280×720 window。
- Player + dummy + multiple NPCs。
- NPC count range: 1–10。
- Select player / dummy / NPC。
- Bind selected instance to Creator Lab。
- Manual / AI mode visible。
- Current state / move / frame / HP visible。
- Hurtbox / hitbox / foot collision overlays toggleable。
- Character depth order sorts by foot-center world y。
- Foot collision resolves spacing and arena clamp。
- Runtime uses generated `SpriteFrames` when available。
- Rect placeholder rendering remains fallback for invalid/missing generated resources。

Runtime must answer directly:

```text
Which instance is selected?
Which template does it use?
Which sprite set does it use?
What state/move/frame is currently executing?
Is art real, placeholder, missing, or invalid?
Did edited collision/timing affect runtime?
```

---

## 7. Creator Lab UI Interaction

Creator Lab is the authoring UI bound to selected runtime instance。

### 7.1 Layout

Keep compact three-zone model:

```text
left: instance / template / sprite-set selection
center: realtime preview and overlays
right: edit panels and validation
```

Tabs / panels:

```text
Instance
Preview
Template / Boxes
Move
Sprite / Wardrobe
Validation
Playground NPC
```

### 7.2 Instance Binding

Required controls:

- `Bind Player`
- `Bind Dummy`
- `Bind NPC <index>`
- selected instance display
- template id display
- sprite set id display
- current state / move / frame display
- HP display
- AI/manual display

Rules:

- Edits apply to selected instance's resolved template/move/sprite data path where practical。
- Saved template edits are template-level edits。
- If two instances share the same template, saved template edit affects both after reload/rebind。
- Per-instance persistent override is out of scope for current clean version。

### 7.3 Preview Controls

Required controls:

```text
First
Prev
Next
Last
Play
Pause
Reset
frame slider / direct frame select
speed: 0.5x / 1x
overlay toggles: hurtbox / hitbox / foot collision / origin / ground line
```

Preview must show:

- selected clip/action frame。
- current frame index / total frame count。
- active frame highlight。
- origin / foot-center ground point。
- ground line。
- hurtbox overlay。
- hitbox overlay。
- foot collision ellipse。
- real / placeholder / missing / invalid status。

Preview updates immediately when editing:

- frame count。
- active window。
- hitbox rect。
- hurtbox rect。
- foot collision center/radius。
- sprite sequence mapping。
- animation clip mapping。

### 7.4 Template / Box Editing

Editable:

- hurtbox rects。
- foot collision ellipse。
- template `sprite_set_ref`。
- equipped move list, if UI supports it safely。

Rules:

- Box editing uses character-local coordinates。
- Saved data stores resolved `{x,y,w,h}` / `{center,radius}` only。
- Pixel nudges are UI operations, not persisted patch layers。
- Foot collision edit must update preview and runtime behavior。

### 7.5 Move Editing

Editable:

- selected move。
- `frame_count`。
- `active_window`。
- `damage`。
- `hitstop_frames`。
- hitbox rect/window。
- frame events。
- `multi_hit` flag。

Rules:

- Insert/delete frame slots must not silently shift gameplay timing。
- If timing metadata is affected, UI must ask for explicit shift decision。
- Delete is blocked when target frame is referenced by active windows, hitboxes, or events unless user resolves those references。

### 7.6 Sprite / Wardrobe Editing

Editable:

- selected sprite set。
- clip to frame sequence mapping。
- frame sequence slots。
- slot state: real / empty / missing / placeholder。
- generate / refresh SpriteFrames。

Rules:

- Wardrobe is a sprite-set view over the same coverage engine。
- It must not become a second source of truth。
- It must expose required action coverage and missing/placeholder state。

### 7.7 Save / Reload

Required flow:

```text
edit -> preview updates -> save JSON -> reload JSON -> regenerate SpriteFrames if needed -> runtime plays edited result -> validation passes/fails visibly
```

Rules:

- Save path must be exact, schema-backed, and reloadable。
- JSON pretty formatting can change；semantic data must round-trip。
- UI must show save/reload result。
- Silent save failure is forbidden。

---

## 8. Sprite Create Flow

Sprite Create is package assembly, not free-form invention。

```text
Stage 0 environment
-> choose base template / size class
-> assign sprite set
-> choose equipped move pool
-> author visual coverage
-> edit hurtboxes / foot collision / hitboxes
-> generate SpriteFrames
-> bind in Playground
-> validate runtime
```

Sprite package layers:

| Layer | Owns |
| --- | --- |
| Environment | resolution, fps, palette defaults, visibility rules |
| CharacterTemplate | hurtboxes, foot collision, HP, sprite set ref, equipped moves |
| MoveTemplate | category, timing, hitboxes, damage, hitstop, events |
| SpriteSet | clips, frame sequences, required move mapping |
| Generated SpriteFrames | Godot playback resource |
| Runtime Instance | selected/current state, current move/frame, HP runtime, AI/manual, hit registry |
| UI | editing, preview, validation, save/reload control |

Preset packages should be reused where possible so create-AI / LimboAI can optimize within known constraints instead of inventing新 architecture。

---

## 9. Validation Contract

Validation must detect:

- schema invalid JSON。
- forbidden legacy fields。
- seconds-based gameplay fields。
- required action missing mapped clip。
- clip references missing frame sequence。
- real frame path missing or unloadable。
- empty/missing/placeholder slots。
- duplicated/fake idle mapping。
- `move.frame_count` mismatch with frame sequence slot count。
- hitbox id invalid。
- event payload invalid。
- generated `.tres` missing。
- generated `.tres` stale relative to data/assets where feasible。
- generated SpriteFrames missing expected animation names。
- generated animation frame count differs from source sequence slot count。
- loop flags differ from clip metadata。
- runtime `AnimatedSprite2D` cannot play expected clip。
- preview differs from runtime frame order。
- foot collision edit fails to affect runtime spacing/clamp/depth behavior。

Current verification commands:

```bash
python3 tools/validate_prd_v0_3.py
godot --headless --path . --script tools/prd_v0_3_runtime_smoke.gd
godot --headless --path . --script tools/creator_lab_v0_3_smoke.gd
godot --headless --path . --script tools/runtime_smoke.gd
godot --headless --path . --script tools/spriteframes_generation_smoke.gd
godot --headless --path . --script tools/spriteframes_runtime_smoke.gd
```

---

## 10. Current Approved Templates / Assets

Current data roots:

```text
data/v0_3/templates/*.json
data/v0_3/moves/*.json
data/v0_3/sprite_sets/*.json
data/schemas/v0_3/*.schema.json
godot/resources/sprite_frames/*.tres
```

Approved current examples:

| id | role |
| --- | --- |
| `combat_gray_s64` | baseline gray combat template / sprite set |
| `skeleton_default_unarmed_s64` | first v0.5 NPC template / sprite set target |

Skeleton rules:

- Commit normalized Skeleton PNG frames only with license note。
- Commit generated Skeleton `.tres` for approved template。
- Do not switch runtime default template to Skeleton unless explicitly chosen。
- Missing actions stay explicit missing/empty/placeholder slots until approved art exists。

---

## 11. Out of Scope

Current clean version does not include:

- projectile/flying-object system。
- weapon system。
- full stamina/debuff/buff persistence。
- combo tree。
- paper-doll single-piece wardrobe。
- skeleton/bone anchor model。
- multiplayer。
- raw source art decoding inside Creator Lab。
- seconds-based gameplay timeline。
- animation-name-driven gameplay。
- per-instance persistent override。
- directional sprite schema migration。

---

## 12. Acceptance Criteria

A slice is accepted only when all are true:

1. Data passes schema and validator。
2. Preview shows real/missing/placeholder/invalid state explicitly。
3. Edited boxes/timing visibly update preview。
4. Save/reload preserves edited data。
5. Generated SpriteFrames preserves frame slot count and loop flags。
6. Runtime selected instance plays the edited data。
7. Foot collision edit changes runtime spacing/clamp/depth behavior when relevant。
8. Playground can bind player/dummy/NPC and report template/sprite/state/move/frame/HP。
9. No silent fallback hides broken art or invalid mapping。
10. Smoke tests pass with the current approved commands。
