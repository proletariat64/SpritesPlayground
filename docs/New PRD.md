


| Visibility  | 缺图、占位、错误映射、失败验证必须显式可见                    |
| ----------- | ---------------------------------------- |
**Definition**
Timeline 
Frame and FPS is the only timeline. 是唯一计时和判断时间先后顺序和时间定位的唯一依据. 
FPS 12  1拍1

Palette
Scene  map  不强制限制 palette
Sprite  palette is lospec EDG64

Sprite s class is by size 

Screen resolution  1280 720 16:9
Screen pixel resolution 640 360 16:9
logical pixel size 2*2

game style 2d  pixel act side scroll arcade 

| `category` | locomotion / combat / reaction / utility/debug |
| ---------- | ---------------------------------------------- |
Sprite create lab 过程looks like 
过程充满配置感觉



第一
Sprite
配装池  --  基础属性和可用装备池
所有状态都为了2D arcade act 特化, 比如 Size 就只有 s class , palette 就默认都是, repo 默认

**基础属性**
Hurtbox
State: idle/dead (基础状态必须至少一个)
基础Move  + 属性

**扩展组合**
扩展状态包
扩展Move包(每个move 都含有 category tag) 
血条包
体力条包
buffer/defbuffer状态包  异常状态不是一个state 是在state action , 和其数据影响他们的数值
每个包的实现都尽量引入

使用大量预设状态和数据,已经圈定访问和需求访问可以让create-ai 在 limbo-ai上专著效率提升而不是颠覆性的.

move + category 完整的定义了一个behavior

move+category是个稀疏

| move        | locomotion                                               | combat                                                                                       | reaction                                                            | utility/debug                                                     |
| ----------- | -------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------- |
| idle        | <span style="color:#2e7d32">standing / idle</span>       | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#2e7d32">default placeholder / preview</span>  |
| dead        | <span style="color:#9e9e9e">Not used</span>              | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#2e7d32">death state</span>                      | <span style="color:#2e7d32">death placeholder / validation</span> |
| walk/run    | <span style="color:#2e7d32">ground movement</span>       | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">movement validation</span>            |
| jump        | <span style="color:#1565c0">takeoff</span>               | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">jump validation</span>                |
| fall        | <span style="color:#1565c0">falling</span>               | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">fall validation</span>                |
| land        | <span style="color:#1565c0">landing recovery</span>      | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#1565c0">hit-stun landing</span>                 | <span style="color:#1565c0">landing validation</span>             |
| dash        | <span style="color:#1565c0">dash / evade movement</span> | <span style="color:#1565c0">combat displacement with collision / invincibility frames</span> | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">dash validation</span>                |
| attack      |                                                          | <span style="color:#1565c0">attack action</span>                                             | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">hitbox validation</span>              |
| hurt        |                                                          | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#1565c0">hit reaction / knockback</span>         | <span style="color:#1565c0">hurtbox validation</span>             |
| block/parry | -                                                        | <span style="color:#1565c0">block / parry</span>                                             | <span style="color:#1565c0">block success / failure feedback</span> | <span style="color:#1565c0">defense-window validation</span>      |
| interact    |                                                          | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">interact / pickup</span>              |
| debug_probe |                                                          | <span style="color:#9e9e9e">Not used</span>                                                  | <span style="color:#9e9e9e">Not used</span>                         | <span style="color:#1565c0">debug probe</span>                    |



`—` 表示该 `move + category` 组合存在于笛卡尔积中，但当前 PRD 不使用；所有 `✅` 组合都需要在配置、验证和可视化里显式支持。



# Stage 0：World Rules & Environment

These are the fundamental rules of the playground world: a clear target and simplified rule set that unifies sprite behavior. It includes:

**rules:** define how the world runs, judges, and validates behavior
**environment**: defines the default project inputs and shared settings
**boundaries**: define what is allowed, what is out of scope, and what must be explicitly validated

## **World Rules**

the god of this world is a lazy god. he is lazy and sharp.  never do things for un predicable future, one line is he never use 2,  use exisiting wheels unleast it doesnt fit.

Sprites gain abilities by equipping different components. Once a sprite has a component, it gains the corresponding ability, but it is also constrained by that component's rules. If a sprite does not equip that component, it is not affected by those rules. For example, if Ugo does not equip the Health component, then Ugo cannot be hurt, cannot die, and will not have the related hurt/death behavior or visuals.

We define rules to specify which sprites are allowed to equip which components, and therefore which abilities and constraints they can have.

we don't 重复造wheel, if there is 成熟的构建 we always try to use it first. we lazy god


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

**Environment Variables**

Environment Variables = 当前项目环境的固定输入值。  
它定义“这个世界在本项目里具体使用什么默认值”。

Environment Variables 是 World Rules 的参数化结果。  
例如：`timeline` 是 World Rule，`default_fps = 12` 是 Environment Variable。

Environment Variables 负责：

- 给 World Rules 提供默认值
- 给 Sprite Create 提供边界
- 给 importer / validator / preview / runtime 提供一致输入
- 防止每个角色单独发明自己的基础环境

Environment Variables 不负责：

- 覆盖 World Rules
- 为单个角色开例外
- 在没有显式说明时改变项目基准

## General Rules

| Rule                     | Definition / Boundary                                             |
| ------------------------ | ----------------------------------------------------------------- |
| game_style               | 2D pixel ACT side-scroll arcade；所有状态、动作、验证都以横版街机 ACT 为默认目标        |
| timeline                 | Frame + FPS 是唯一时间线；所有动作时长、窗口、判定、冷却、恢复都必须用 frame 表达                |
| default_fps              | 12 FPS；1 frame = 1 拍；禁止用秒作为主要设计单位，秒只能作为辅助说明                       |
| screen_resolution        | 1280×720，16:9；用于最终窗口、截图、演示和 QA 观察                                 |
| logical_resolution       | 640×360，16:9；用于游戏逻辑、坐标、关卡布局、镜头和 sprite 摆放                         |
| logical_pixel_size       | 2×2；1 logical pixel 在最终显示中放大为 2×2 screen pixels                   |
| game_camera              | Camera 以 logical_resolution 为基准；不得用 screen pixel 直接驱动 gameplay    |
| sprite_palette           | Sprite 默认使用 Lospec EDG64；Scene / map 不强制限制 palette                |
| size_model               | Sprite 使用 size class；Sprite 0 默认目标为 S class                       |
| sprite_canvas            | S class 默认按 80×80 sprite contract 设计；超出必须显式标记为 exception          |
| collision_model          | 碰撞以 2D side-scroll 为主；z 轴只用于 layer / depth / priority，不作为自由 3D 空间 |
| collision_visibility     | Hurtbox / hitbox / bodybox / ground check 必须能被 debug view 显式显示    |
| missing_asset_visibility | 缺图、占位、错误映射、失败验证必须显式可见；禁止 silent fallback                          |
| validation_rule          | 所有默认值都必须能被 importer、preview、runtime、validator 使用同一套规则验证           |
| override_rule            | 任何偏离 Stage 0 的设定都必须显式声明原因、影响范围和验证方式                               |

## Environment Variables

| Input Item              | Default Value / Boundary                         |
| ----------------------- | ------------------------------------------------ |
| `game_style`            | `2D pixel ACT side-scroll arcade`                |
| `timeline`              | `frame_based`                                    |
| `default_fps`           | `12`                                             |
| `frame_unit`            | `1 frame = 1 beat`                               |
| `screen_resolution`     | `1280×720`                                       |
| `screen_aspect`         | `16:9`                                           |
| `logical_resolution`    | `640×360`                                        |
| `logical_aspect`        | `16:9`                                           |
| `logical_pixel_size`    | `2×2`                                            |
| `sprite_palette`        | `Lospec EDG64`                                   |
| `scene_palette`         | `unrestricted`                                   |
| `size_model`            | `sprite_size_class`                              |
| `default_sprite_class`  | `S class`                                        |
| `s_class_contract`      | `80×80`                                          |
| `collision_space`       | `2D side-scroll`                                 |
| `z_axis_rule`           | `layer / depth / priority only`                  |
| `debug_visibility`      | `required`                                       |
| `silent_fallback`       | `forbidden`                                      |

## Stage 0 Output

Stage 0 的输出不是 sprite，而是一组可复用的项目基准：

- `World Rules`
- `Environment Variables`
- `Validation Boundary`
- `Sprite Create Default Input`
- `Debug Visibility Contract`

Sprite 0 Create 必须读取这些规则作为默认环境；只有当 Stage 0 中没有定义的内容，Sprite 0 Create 才能新增角色级设定。
