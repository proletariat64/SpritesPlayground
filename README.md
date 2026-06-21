# SpritesPlayground

SpritesPlayground 是《米多毕业大冒险 / Miduo Holiday》的独立 sprite 资产实验室。

这个仓库不是正式游戏仓库，而是用于整理、预览、调试和验证 pixel-art 角色动画资源的 Godot 工具仓库。正式游戏项目可以在确认素材稳定后，再从这里导入干净、标准化、可用的角色动画资产。

## 项目定位

本仓库用于管理以下内容：

- AI 生成的角色 sprite 原稿
- GIF 动画预览图
- PNG sprite sheet
- 已拆分的单帧 PNG
- Godot `SpriteFrames` 动画资源
- Godot 可视化调试场景
- sprite manifest 元数据
- 自动检查脚本
- 动作命名与尺寸标准文档

当前重点角色：

- `dad_chibi_64`
- `mam_chibi_64`
- `miduo_chibi_64`

## 核心目标

SpritesPlayground 的目标是建立一个统一的 sprite 动作管理流程：

1. 所有角色使用统一的 64×64 logical sprite frame。
2. 每个角色的动作按 state 分类管理。
3. Godot 内提供一个 SpriteLab 可视化调试场景。
4. 可以点击角色并预览全部动作。
5. 可以在下方生成 state 方阵，同时循环播放所有动作。
6. 可以测试默认 east 方向与 8-direction rotation state。
7. 可以检查动作缺帧、尺寸错误、命名错误、透明背景问题和动画抖动。
8. 最终输出可迁移到正式游戏项目的干净资源。

## 尺寸标准

当前统一标准：

```text
真实 sprite frame: 64×64 px
Godot 动画帧尺寸: 64×64 px
SpriteLab 调试显示格: 96×96 px
默认方向: east
默认 pivot: bottom center
默认显示过滤: nearest / no smoothing
```

注意：

- 不要把 64×64 原始资源强行改成 80×80 或 96×96。
- 96×96 是调试显示槽，不是当前角色素材尺寸。
- 未来如果攻击动作、特效或 boss 需要更大空间，可以单独使用 96×96 safe canvas。

## 推荐目录结构

```text
SpritesPlayground/
├── README.md
├── project.godot
├── assets/
│   └── sprites/
│       ├── dad_chibi_64/
│       │   ├── source/
│       │   ├── gifs/
│       │   ├── sheets/
│       │   ├── frames/
│       │   │   ├── idle/
│       │   │   ├── walk/
│       │   │   ├── run/
│       │   │   ├── punch/
│       │   │   └── hurt/
│       │   └── sprite_manifest.json
│       │
│       ├── mam_chibi_64/
│       │   └── ...
│       │
│       └── miduo_chibi_64/
│           └── ...
│
├── debug/
│   └── sprite_lab/
│       ├── SpriteLab.tscn
│       ├── SpriteLab.gd
│       ├── SpriteLabActor.tscn
│       ├── SpriteLabActor.gd
│       ├── SpriteStateCell.tscn
│       └── SpriteStateCell.gd
│
├── resources/
│   └── sprite_frames/
│       ├── dad_chibi_64_sprite_frames.tres
│       ├── mam_chibi_64_sprite_frames.tres
│       └── miduo_chibi_64_sprite_frames.tres
│
├── tools/
│   ├── generate_manifest.py
│   ├── check_sprite_frames.py
│   ├── build_spriteframes_godot.py
│   └── README.md
│
└── docs/
    ├── sprite_standard.md
    ├── state_naming.md
    └── godot_sprite_lab_design.md
```

## 资产目录说明

每个角色目录建议保持相同结构：

```text
assets/sprites/<character_id>/
├── source/
├── gifs/
├── sheets/
├── frames/
└── sprite_manifest.json
```

说明：

| 目录 | 用途 |
|---|---|
| `source/` | 原稿、参考图、AI 生成原图，不直接进入 Godot 动画 |
| `gifs/` | GIF 预览图，仅用于人工观察 |
| `sheets/` | sprite sheet 总图或未拆分动作图 |
| `frames/` | Godot 真正使用的单帧 PNG |
| `sprite_manifest.json` | 角色动作元数据 |

正式 Godot 动画主要读取：

```text
frames/
sprite_manifest.json
resources/sprite_frames/*.tres
```

## 动作 state 命名标准

统一使用小写 snake_case：

```text
idle
walk
run
jump_start
jump_loop
fall
land
punch_1
punch_2
kick
hurt
knockdown
getup
dead
special_1
```

不要混用：

```text
Walk
WALK
walkRight
walk_right
Run01
```

## sprite_manifest.json 示例

```json
{
  "id": "miduo_chibi_64",
  "display_name": "Miduo",
  "frame_size": [64, 64],
  "debug_cell_size": [96, 96],
  "default_state": "idle",
  "default_dir": "east",
  "states": {
    "idle": {
      "fps": 6,
      "loop": true,
      "path": "res://assets/sprites/miduo_chibi_64/frames/idle/"
    },
    "walk": {
      "fps": 8,
      "loop": true,
      "path": "res://assets/sprites/miduo_chibi_64/frames/walk/"
    },
    "run": {
      "fps": 10,
      "loop": true,
      "path": "res://assets/sprites/miduo_chibi_64/frames/run/"
    },
    "punch_1": {
      "fps": 10,
      "loop": false,
      "path": "res://assets/sprites/miduo_chibi_64/frames/punch_1/"
    },
    "hurt": {
      "fps": 8,
      "loop": false,
      "path": "res://assets/sprites/miduo_chibi_64/frames/hurt/"
    }
  }
}
```

## SpriteLab 调试场景

第一阶段目标是创建一个 Godot 可视化调试场景：

```text
debug/sprite_lab/SpriteLab.tscn
```

功能目标：

- 顶部显示所有角色：
  - `dad_chibi_64`
  - `mam_chibi_64`
  - `miduo_chibi_64`
- 点击角色后选中该角色。
- 主预览区显示当前角色。
- 当前角色默认播放 `idle`。
- 当前方向默认 `east`。
- 点击角色后启动 8dir rotation state 测试。
- 下方列出该角色所有动作 states。
- 下方生成 state 方阵。
- 每个 state cell 自动循环播放对应动作。
- 点击 state cell 后，主预览区切换到该动作。
- 显示当前 actor、state、dir、frame index、frame count。

## 8-direction rotation state

第一阶段先支持逻辑方向，不要求必须有 8 套方向素材。

方向顺序：

```text
east
southeast
south
southwest
west
northwest
north
northeast
```

当前如果只有 east 方向素材：

```text
east / southeast / south / northeast 等方向：先播放 east
west / southwest / northwest：使用 flip_h
```

未来如果有完整 8dir 素材，再扩展为：

```text
walk_east
walk_southeast
walk_south
walk_southwest
walk_west
walk_northwest
walk_north
walk_northeast
```

## 第一阶段范围

Phase 1 只做 sprite 管理和调试，不进入正式游戏战斗逻辑。

包括：

- Godot 4 项目基础结构
- SpriteLab 可视化场景
- SpriteLabActor 角色预览体
- SpriteStateCell 动作预览格
- manifest 读取
- SpriteFrames 构建或加载
- 64×64 尺寸检查
- nearest-neighbor 像素显示
- 顶部角色选择
- 下方 state list
- state grid 同屏循环预览
- 8dir rotation state debug

不包括：

- 正式玩家控制器
- 敌人 AI
- 战斗 hitbox timeline
- 关卡
- 存档
- 发布导出
- 音效
- UI 菜单

## 开发方式

推荐用 issue 驱动开发：

- Issue #1: Control Board
- Issue #2: Phase 1 SpriteLab 基础功能实现

每次实现应该通过 PR 合并，不建议直接长期在 main 上堆代码。

## 边界规则

- 不提交未经授权的商业游戏素材。
- 不提交 ripped sprites。
- 不提交 `.env`、私钥、token、本机配置。
- 不提交大型临时缓存。
- `source/` 可以保留原稿，但进入 Godot 的应是整理后的 `frames/`。
- 所有可运行素材应尽量保持原创、家庭友好、可读、清晰。
