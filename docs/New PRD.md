
# "And God said, Let there be light: and there was light." World Rules & Environment

These are the fundamental rules of the playground world: a clear target and simplified rule set that unifies sprite behavior. It includes:

**rules:** define how the world runs, judges, and validates behavior
**environment**: defines the default project inputs and shared settings
**boundaries**: define what is allowed, what is out of scope, and what must be explicitly validated

## **World Rules**

the god of this world is a lazy god. he is lazy and sharp.  never do things for un predicable future, one line is he never use 2,  use exisiting wheels unleast it doesnt fit.

Sprites gain abilities by equipping different components. Once a sprite has a component, it gains the corresponding ability, but it is also constrained by that component's rules. If a sprite does not equip that component, it is not affected by those rules. For example, if Ugo does not equip the Health component, then Ugo cannot be hurt, cannot die, and will not have the related hurt/death behavior or visuals.

We define rules to specify which sprites are allowed to equip which components, and therefore which abilities and constraints they can have.

No reinvented wheels. Use proven tools first. The lazy god never builds the same thing twice.


World Rules 负责：

- 时间如何流动
- 坐标和分辨率如何解释
- pixel art 如何显示
- 碰撞体积系统
	- 碰撞如何判断
- 有伤害生命值系统 伤害如何结算
- 有生命值系统
- 
- There are only mankind sprite
- sprite size 如何分类 --不是世界规则

World Rules 不负责：

- 单个角色的外观设定
- 单个角色的 move list
- 单个角色的数值平衡
- 单个角色的 AI 行为树
- 单个 sprite 的具体动画帧内容

## World Environment Variables


**Environment Variables** they parameterize World Rules into the specific fixed default values for this repository;

| Input Item           | Default Value / Boundary          | Definition                                                   |
| -------------------- | --------------------------------- | ------------------------------------------------------------ |
| `game_style`         | `2D pixel ACT side-scroll arcade` | Art & genre: pixel-art 2D side-scrolling action arcade.      |
| `timeline`           | `frame_based`                     | Time advances in discrete frames, not real-time seconds.     |
| `default_fps`        | `12`                              | Default animation and logic frame rate.                      |
| `frame_unit`         | `1 frame = 1 beat`                | One frame equals one timing beat for action synchronization. |
| `screen_resolution`  | `1280×720`                        | Final display resolution.                                    |
| `screen_aspect`      | `16:9`                            | Display aspect ratio.                                        |
| `logical_resolution` | `640×360`                         | Base canvas size for the game-world coordinate system.       |
| `logical_aspect`     | `16:9`                            | Logical canvas aspect ratio.                                 |
| `logical_pixel_size` | `2×2`                             | Scale factor: 1 logical pixel = 2×2 screen pixels.           |
| `sprite_palette`     | `Lospec EDG64`                    | Sprite color palette constraint for visual consistency.      |
| `scene_palette`      | `unrestricted`                    | Scene/background palette has no restrictions.                |
# "Let Us make man like Us": the origin (No. 0)

## Definition

**the origin / No.0** is the smallest valid sprite entity in the world.

It is not a player, not a fighter, and not a living character yet. It only proves that a sprite can **exist** under the world rules.

No.0 can:

- render pixel art
- occupy space
- own a size class
- play idle animation
- expose collision/debug information
- pass validation

No.0 cannot:

- move
- attack
- take damage
- die
- receive input
- run AI
- own combat logic

> No.0 is visible, sized, idle, collidable, and validateable -- but not alive, not controllable, and not combat-capable.

## No.0 Node Tree

No.0 is not Adam's parent class. No.0 is the **origin composition**: the smallest reusable node composition that Adam also uses.

```md
the origin / No.0 : CharacterBody2D
|-- CollisionShape2D
|
|-- VisualSystem : Node2D
|   |-- AnimatedSprite2D
|   `-- AnimationPlayer
|
|-- SizeSystem : Node / Resource
|   |-- sprite_size_class : s64
|   |-- sprite_size : 64x64
|   `-- frame_size : 80x80
|
|-- StateMachine : LimboHSM
|   `-- idle : BTState
|       `-- behavior_tree : bt_idle.tres
|
|-- BlackboardPlan : Resource
|   |-- agent
|   |-- animation_player
|   `-- current_move
|
`-- ValidationSystem : Node
    |-- missing_visual_check
    |-- frame_size_check
    |-- palette_check
    |-- body_collision_check
    |-- required_idle_state_check
    `-- required_idle_move_check
```

## Engineering Rules

- No.0 and Adam share the same basic node shape.
- No.0 is composed into Adam's design; Adam does not inherit from No.0 as a special class.
- Root is `CharacterBody2D` so the origin composition can become a controllable actor without changing its basic scene shape.
- No.0 owns no input, no attack, no life, and no hurt receiving.
- `VisualSystem`, `SizeSystem`, and `ValidationSystem` are custom project systems. `StateMachine` uses LimboAI `LimboHSM`; state behavior uses `BTState` and BehaviorTree assets.
- `CollisionShape2D` only proves body presence at No.0 stage; Adam later uses it for real movement collision.
- Z-axis never affects gameplay logic.
- No optional combat systems are allowed.

Forbidden systems:

```md
Health / LifeSystem
Damage / HurtSystem
AttackSystem
MoveSystem
InputSystem
AISystem
Death state
Combat state
```

## Sprite Size Class Table

`size` is not a free-form value. It is a fixed `sprite_size_class` that defines the sprite body size, the single-frame `frame_size`, and the default collision reference. No character may define its own dimensions.

| `s_class` | `sprite_size` | `frame_size` | alias  | Notes   |
| --------- | ------------- | ------------ | ------ | ------- |
| `s32`     | `32x32`       | `48x48`      | kids   |         |
| `s48`     | `48x48`       | `64x64`      | small  | -       |
| `s64`     | `64x64`       | `80x80`      | normal | default |
| `s80`     | `80x80`       | `96x96`      | large  | -       |
| `s96`     | `96x96`       | `112x112`    | giant  | -       |

- `sprite_size`: logical body size.
- `frame_size`: square canvas for one animation frame, always `sprite_size + 16` for the action-safe margin.
- Every frame must match its class `frame_size` exactly.
- A sprite without a class falls back to `s64`. `silent_fallback` is `forbidden`; log every fallback.

# "Be fruitful and multiply": Adam (No. 1)

## Definition

**Adam / No.1** is the first real controllable human sprite.

Adam is composed from the same origin node composition as No.0, then equipped with the minimum extra systems needed for a playable 2D action character:

- player input
- movement
- life
- hurt receiving
- move-based attacks
- LimboAI state machine
- behavior-tree move execution

Adam is not a special-case character. Adam is the first complete example of the reusable sprite composition.

## LimboAI First Rule

Use LimboAI as the default behavior architecture.

```md
Do not implement custom StateMachine, State, or MoveSystem framework unless LimboAI cannot express the requirement.
```

Mapping:

```md
StateMachine        = LimboHSM
State               = BTState / LimboState
State behavior      = BehaviorTree
Move / 招式          = MoveData Resource
Runtime shared data = Blackboard
Exact frame timing  = AnimationPlayer
Visual frame output = AnimatedSprite2D
```

Lazy-god rule:

```md
Write only thin glue code around LimboAI.
Let LimboHSM switch states.
Let BTState run behavior.
Let Blackboard carry runtime data.
Let AnimationPlayer own exact timing.
Let MoveData describe 招式.
```

## Adam Node Tree

```md
Adam : CharacterBody2D
|-- CollisionShape2D
|
|-- VisualSystem : Node2D
|   |-- AnimatedSprite2D
|   `-- AnimationPlayer
|
|-- StateMachine : LimboHSM
|   |-- idle : BTState
|   |   `-- behavior_tree : bt_idle.tres
|   |-- walk : BTState
|   |   `-- behavior_tree : bt_ground_move.tres
|   |-- jump : BTState
|   |   `-- behavior_tree : bt_airborne.tres
|   |-- fall : BTState
|   |   `-- behavior_tree : bt_airborne.tres
|   |-- attack : BTState
|   |   `-- behavior_tree : bt_execute_move.tres
|   |-- hurt : BTState
|   |   `-- behavior_tree : bt_hurt_reaction.tres
|   `-- dead : BTState
|       `-- behavior_tree : bt_dead.tres
|
|-- BlackboardPlan : Resource
|   |-- agent
|   |-- animation_player
|   |-- animated_sprite
|   |-- current_move
|   |-- move_input
|   |-- facing_dir
|   |-- velocity
|   |-- is_grounded
|   |-- hurt_result
|   `-- hp
|
|-- SizeSystem : Node / Resource
|   `-- SpriteSizeConfig
|       |-- sprite_size_class : s64
|       |-- sprite_size : 64x64
|       `-- frame_size : 80x80
|
|-- InputSystem : Node
|   |-- read_player_input
|   |-- write_blackboard
|   `-- dispatch_limbo_events
|
|-- HurtSystem : Node
|   |-- HurtboxSet : Area2D
|   |   |-- hurt_head : CollisionShape2D
|   |   |-- hurt_upper_body : CollisionShape2D
|   |   `-- hurt_lower_body : CollisionShape2D
|   |-- defense
|   |-- damage_formula
|   `-- invincibility_frame
|
|-- LifeSystem : Node
|   |-- max_hp
|   |-- current_hp
|   `-- death_check
|
`-- HitboxRuntime : Area2D
    |-- active_hitbox_shape : CollisionShape2D
    `-- attack_instance_id
```

## Why `CharacterBody2D`

Adam is controllable and moves in the world, so the root should be:

```md
Adam : CharacterBody2D
```

`CharacterBody2D` handles:

- ground movement
- velocity
- collision with world
- floor detection
- jump / fall physics

No.0 and Adam both use `CharacterBody2D`; Adam activates movement through `InputSystem`, `LimboHSM`, and BehaviorTrees rather than by changing the root type.

```md
No.0 = origin composition with idle BTState only
Adam = origin composition + input + life + hurt + attack BTStates + MoveData
```

## State Events

LimboHSM transitions should be event-driven.

```md
ev_move
 ev_stop
 ev_jump
 ev_fall
 ev_land
 ev_attack
 ev_hurt
 ev_dead
 ev_finished
```

Basic transition intent:

```md
idle   --ev_move-->   walk
walk   --ev_stop-->   idle
idle   --ev_jump-->   jump
walk   --ev_jump-->   jump
jump   --ev_fall-->   fall
fall   --ev_land-->   idle / walk
idle   --ev_attack--> attack
walk   --ev_attack--> attack
attack --ev_finished--> idle / walk
any    --ev_hurt-->   hurt
hurt   --ev_finished--> idle / walk
any    --ev_dead-->   dead
```

## Visual System

Adam uses:

```md
AnimatedSprite2D
AnimationPlayer
```

`AnimatedSprite2D` handles pixel-frame animation display.

`AnimationPlayer` handles exact action timing:

- enable hitbox
- disable hitbox
- call move events
- play flash
- play SFX
- mark startup / active / recovery
- finish move
- dispatch `ev_finished` back to `LimboHSM`

Rule:

```md
AnimatedSprite2D = what Adam looks like
AnimationPlayer = exact timing and callbacks
BTState          = why this animation is being played
```

## Move / 招式 System

A move is not a Node tree. A move is a data contract executed by LimboAI.

Each move should be defined as a `MoveData` resource.

```md
MoveData : Resource
|-- id
|-- state_event
|-- category
|-- animation_name
|-- startup_frames
|-- active_frames
|-- recovery_frames
|-- attack_profile
|-- cancel_rules
`-- finish_event
```

Example:

```md
basic_punch : MoveData
|-- id : basic_punch
|-- state_event : ev_attack
|-- category : combat
|-- animation_name : basic_punch
|-- startup_frames : 3
|-- active_frames : 2
|-- recovery_frames : 7
|-- attack_profile
|   |-- damage : 1
|   |-- hitbox_shape : fist_light
|   |-- knockback : { x: 40, y: 0 }
|   `-- hitstun_frames : 6
`-- finish_event : ev_finished
```

Runtime execution:

```md
InputSystem selects MoveData
-> writes blackboard.current_move
-> dispatches MoveData.state_event to LimboHSM
-> attack BTState runs bt_execute_move.tres
-> BT plays AnimationPlayer animation
-> AnimationPlayer opens/closes HitboxRuntime on exact frames
-> AnimationPlayer or BT dispatches ev_finished
```

## Move Type Matrix

The matrix below is the design surface for comparing and simulating different move types. A move is valid only when its row/category combination is explicitly supported.

Legend:

```md
PRIMARY = normal intended use
ALLOWED = allowed but not required for Adam No.1
DEBUG   = tool / validation use only
NO      = not used in current PRD
```

| move | locomotion | combat | reaction | utility/debug | default state_event | uses attack_profile | uses HurtResult | minimum animation need |
| ---- | ---------- | ------ | -------- | ------------- | ------------------- | ------------------- | --------------- | ---------------------- |
| idle | PRIMARY: standing baseline | NO | NO | PRIMARY: preview/default | ev_stop / ev_finished | no | no | idle loop |
| walk | PRIMARY: ground movement | NO | NO | ALLOWED: movement validation | ev_move | no | no | walk loop |
| run | ALLOWED: faster ground movement | NO | NO | ALLOWED: speed validation | ev_move | no | no | run loop |
| jump | PRIMARY: takeoff | NO | NO | ALLOWED: jump validation | ev_jump | no | no | jump start |
| fall | PRIMARY: airborne falling | NO | ALLOWED: hit-fall reaction | ALLOWED: fall validation | ev_fall | no | optional | fall loop |
| land | PRIMARY: landing recovery | NO | ALLOWED: hit landing / knockdown recovery | ALLOWED: landing validation | ev_land | no | optional | land clip |
| dash | ALLOWED: evade / burst movement | ALLOWED: dash attack carrier | NO | ALLOWED: dash validation | ev_dash | optional | no | dash clip |
| attack | NO | PRIMARY: active attack move | NO | ALLOWED: hitbox validation | ev_attack | yes | no | attack clip with timing callbacks |
| hurt | NO | NO | PRIMARY: hit reaction / knockback | ALLOWED: hurtbox validation | ev_hurt | no | yes | hurt clip |
| dead | NO | NO | PRIMARY: death reaction | ALLOWED: death validation | ev_dead | no | yes | dead clip |
| block | NO | ALLOWED: defensive move | ALLOWED: block success/failure reaction | ALLOWED: defense-window validation | ev_block | optional counter only | optional | block clip |
| parry | NO | ALLOWED: timed defensive move | ALLOWED: parry success/failure reaction | ALLOWED: parry-window validation | ev_parry | optional counter only | optional | parry clip |
| interact | NO | NO | NO | ALLOWED: pickup / talk / trigger | ev_interact | no | no | interact clip |
| debug_probe | NO | NO | NO | DEBUG: inspect boxes/timing | ev_debug_probe | optional test only | optional test only | optional |


## Move Comparison Fields

Every row in the matrix should be comparable using the same fields:

| field | meaning | owner |
| ----- | ------- | ----- |
| `id` | stable move id | MoveData |
| `category` | locomotion / combat / reaction / utility-debug | MoveData |
| `state_event` | LimboHSM event used to enter the state | MoveData |
| `animation_name` | AnimationPlayer clip to play | MoveData |
| `startup_frames` | frames before effect is active | MoveData |
| `active_frames` | effect / hitbox / guard active frames | MoveData |
| `recovery_frames` | frames before normal control returns | MoveData |
| `attack_profile` | damage, hitbox, hitstop, knockback | MoveData, only for attack-capable moves |
| `reaction_profile` | hitstun, knockback receive, reaction tag | HurtResult / reaction MoveData |
| `cancel_rules` | what can interrupt or chain this move | MoveData + BTState |
| `finish_event` | event dispatched when move completes | MoveData |

## Move Execution BehaviorTree

`bt_execute_move.tres` is the common attack-move executor.
````
```
```md
bt_execute_move.tres
|-- read blackboard.current_move
|-- play current_move.animation_name with AnimationPlayer
|-- wait until animation finished or move_finished flag
`-- dispatch current_move.finish_event
```

This keeps the number of scripts low. New attacks should usually add only:

```md
1 MoveData resource
1 animation in AnimationPlayer
optional hitbox profile data
```

No new state script should be required for every attack.

## Attack System Rule

AttackSystem should not be a permanent top-level character system in the same sense as LifeSystem.

Conceptually:

```md
Attack belongs to 招式 / MoveData.
```

Runtime:

```md
MoveData defines attack.
BTState executes the move.
AnimationPlayer controls timing.
HitboxRuntime exposes the hitbox.
Target HurtSystem receives the hit.
```

Flow:

```md
InputSystem
-> Blackboard.current_move
-> LimboHSM event
-> BTState
-> BehaviorTree
-> AnimationPlayer
-> HitboxRuntime
-> target HurtSystem
-> target LifeSystem
-> target LimboHSM
```

## Hitbox / Hurtbox Contract

Adam supports multiple hurtboxes from the beginning, even if No.1 only uses simple shapes.

```md
HurtboxSet : Area2D
|-- hurt_head
|-- hurt_upper_body
`-- hurt_lower_body
```

Each hurtbox may define:

| field | meaning |
| ----- | ------- |
| `zone_id` | stable id, e.g. `hurt_head` |
| `shape` | local CollisionShape2D |
| `damage_multiplier` | optional multiplier, default `1.0` |
| `reaction_tag_override` | optional override, e.g. `head_hit`, `low_hit` |
| `priority` | same-frame resolution priority |
| `enabled_frames` | optional frame window for animation-specific hurtboxes |

Hitbox rules:

```md
MoveData.attack_profile defines attack intent.
AnimationPlayer opens/closes HitboxRuntime on exact frames.
HitboxRuntime carries attack_instance_id to prevent duplicate hits.
HurtboxSet receives overlap and forwards hit_info to HurtSystem.
```

Same-frame multi-hurtbox resolution:

```md
1. If invincibility is active, ignore the hit before damage calculation.
2. If multiple hurtboxes are hit by the same attack_instance_id in the same frame, choose one hurtbox only.
3. Resolve by highest priority.
4. If priority ties, resolve by smallest hurtbox area.
5. If still tied, use first registered hurtbox order.
```

Default hurtbox priority:

| hurtbox | priority | default meaning |
| ------- | -------- | --------------- |
| `hurt_head` | 30 | high-value head hit / upper reaction |
| `hurt_upper_body` | 20 | normal torso hit |
| `hurt_lower_body` | 10 | low hit / leg reaction |

## Hit Resolution Contract

Attack hit flow:

```md
HitboxRuntime
-> target HurtboxSet
-> target HurtSystem.receive_hit(hit_info)
-> target LifeSystem.apply_damage(HurtResult.damage_taken)
-> target Blackboard.hurt_result = HurtResult
-> target LimboHSM dispatch ev_hurt or ev_dead
-> target hurt/dead BTState executes reaction behavior
```

Rules:

- All current damage comes from attacks.
- Environment damage is out of scope for Adam No.1.
- DOT / poison / burn is future `DotSystem`, not `HurtSystem`.
- One `attack_instance_id` can hit the same target once unless `multi_hit = true`.
- `invincibility_frame` rejects hits before `damage_formula`.
- Invincibility is treated as temporary cannot-be-hit, not as a huge defense number in implementation.
- `defense` modifies damage only; it does not choose state transitions.
- `reaction_tag`, `hitstun_frames`, `knockback`, and `hitstop_frames` come from `attack_profile` plus hurtbox overrides.
- LimboHSM owns state changes; HurtSystem only produces `HurtResult`.

Recommended `attack_profile` fields:

```md
attack_profile
|-- damage
|-- hitbox_shape
|-- active_frames
|-- hitstop_frames
|-- knockback
|-- hitstun_frames
|-- reaction_tag
|-- multi_hit
`-- target_limit
```

## Z-Axis / Occlusion Contract

Z-axis is visual only.

```md
Z-axis never affects gameplay collision, attack range, hurtbox overlap, or damage logic.
```

Character occlusion / render order rules:

| rule | meaning |
| ---- | ------- |
| `depth_reference` | use foot point / bottom of body collision as the depth anchor |
| `sort_key` | lower screen Y renders in front of higher screen Y |
| `z_index` | reserved for layer priority override only |
| `y_sort_enabled` | allowed for scene/render grouping |
| `HitboxRuntime` | always uses 2D collision space, never visual Z depth |
| `HurtboxSet` | always uses 2D collision space, never visual Z depth |

Default depth formula:

```md
render_sort_y = global_position.y + foot_offset_y
```

If two sprites overlap visually:

```md
1. Compare render_sort_y.
2. Larger render_sort_y draws in front.
3. If tied, compare explicit z_index / render_priority.
4. If still tied, stable scene order is acceptable.
```

## Hurt System

Adam currently has no environment damage and no DOT/debuff damage.

Initial assumption:

```md
All damage comes from attacks.
No poison.
No burning.
No continuous HP drain.
No environment damage.
```

Therefore `HurtSystem` only handles being hit by attacks.

```md
HurtSystem : Node
|-- HurtboxSet : Area2D
|   |-- hurt_head : CollisionShape2D
|   |-- hurt_upper_body : CollisionShape2D
|   `-- hurt_lower_body : CollisionShape2D
|-- defense
|-- damage_formula
`-- invincibility_frame
```

`HurtSystem` does not decide state transitions. It outputs a `HurtResult` and writes it to Blackboard.

```md
HurtResult
|-- damage_taken
|-- knockback
|-- hitstun_frames
|-- reaction_tag
`-- should_die
```

Then:

```md
LifeSystem applies HP change.
HurtSystem / LifeSystem dispatches ev_hurt or ev_dead.
LimboHSM changes state.
BTState hurt runs bt_hurt_reaction.tres.
```

Rule:

```md
HurtSystem does math.
LifeSystem owns HP.
LimboHSM owns state change.
BTState / BehaviorTree owns reaction execution.
```

## Minimum Custom Code

Adam should start with only thin glue scripts:

```md
InputSystem.gd
- read input
- set Blackboard variables
- choose current MoveData
- dispatch LimboHSM events

HurtSystem.gd
- receive_hit(hit_info)
- check invincibility
- apply defense formula
- build HurtResult

LifeSystem.gd
- current_hp / max_hp
- apply_damage()
- death_check

HitboxRuntime.gd
- enable_from_move(move_data)
- disable()
```

Avoid writing these unless proven necessary:

```md
Custom StateMachine.gd
Custom State.gd
Custom MoveSystem.gd
One script per move
One script per state transition
```

## Adam Minimum Move List

Adam starts with only the minimum action set:

```md
idle
walk
jump
fall
basic_punch
hurt_light
dead
```

No advanced combat yet.

Not included in Adam No.1:

```md
dash
block
parry
combo
special attack
AI enemy behavior
buff/debuff
DOT
equipment
multiple weapons
```

## Adam One-Line Definition

> Adam is the origin composition plus LimboAI-driven control, life, hurt receiving, and MoveData-based attack execution -- the first controllable combat sprite.
