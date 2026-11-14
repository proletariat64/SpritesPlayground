---
title: "米多放学路：单关设计与试玩"
doc_type: runbook
status: active
owner: SpritesPlayground maintainers
source: user request
created: 2026-11-13
updated: 2026-11-13
---

# 米多放学路：单关设计与试玩

## 启动

在已完成项目 bootstrap 的环境运行 `godot --path .`，默认进入中文标题菜单。
选择「开始回家」或按 Enter；「精灵实验室 / Playground」保留原实验室入口。
本关是用户新增的可玩清关切片，不替代历史实验室 PRD；共享角色、动作数据和 Playground 保持原样。

## 玩法

- WASD / 方向键移动；Ctrl 跑；Shift 冲刺。
- 空格跳，Ctrl + 空格大跳；J-J 连拳，K-K 连踢，↓+K 扫腿，空中 K 飞踢。
- L「放学旋风」：复用米多回旋踢动画，以实际攻击框覆盖身体两侧；每个敌人每次窗口只结算一次，冷却 5.5 秒，无蓝条。
- Esc 暂停：继续、重新挑战、返回标题。菜单支持鼠标和方向键/Enter。
- 菜单切回游戏后须松开游戏键，避免按键穿透；菜单、失败、胜利期间战斗冻结。

## 路线与敌人

夕阳校门 → 商铺/自行车街 → 林荫小巷 → 回家路口 → 暖灯住宅。
四场固定遭遇：拳手×2，冲锋手+踢手，小头目·铁腿，路口头领。
同时至多两名普通敌人；清空活着的敌人后路障解锁，跟随 GO 向右走。
最后一战后仍须走到 HOME 门前，才显示到家结算。

拳手近身出拳，冲锋手预警后直线突进，踢手贴近踢击。
小头目有 0.7 秒重踢预警；头领交替突进拳/回旋踢。红线方向在预警时锁定，离开攻击线后利用收招反击。
普通敌人 HP 22/24/24，小头目 60，头领 90；米多 100。
米多受轻击有 0.65 秒伤害保护，重击为 1.65 秒，避免连续硬直；没有常驻无敌。
本关运行时独立深拷贝调参，六帧攻击采用 12fps；不保存或重写原始资源。
重试重建全部角色、波次、相机、输入缓冲、冷却和保护时间。

## 实现边界

`homeward_stage.gd` 负责固定波次、矩形行走区、镜头、UI 与团队碰撞结算。
先收集全部攻击快照，再标记窗口，最后扣血，保留双方同时命中。
`homeward_actor.gd` 继承现有战斗角色，继续通过 request_attack、AnimationPlayer 和 LimboAI 驱动。
`homeward_street.gd` 现在实际加载三张 AI 生成背景 PNG：校门、商店街、回家小巷，已移除原程序化街景块。
原始背景均为 1672×941；使用 Pillow NEAREST 预处理为 768×432，分别放在世界坐标 (0,-72)、(768,-72)、(1536,-72)，不在运行时拉伸，继续使用最近邻过滤。
顶部裁去 72 像素天空，路面与原 y=230..320 行走区相接；HOME 地面指示在原 x≈2010 到家判定附近。关卡长度、波次、角色坐标与判定未因美术更改。
中文字体随包附带 Droid Sans Fallback，授权见 `godot/assets/homeward/`。
运行时无联网、生成服务、掉落装备、多关存档或音频；本次集成没有额外提供方调用。

## AI 美术交付状态：五种新敌人动画已接入

背景三张继续使用第一批生成 PNG。第二批上限为 16，实际使用 13 槽，取得 3 张新身份设计和 10 张动作图集；剩余 3 槽未提交，已停止。本次离线整理和集成没有提供方调用。
来源为 Codex 原生 `image_gen.imagegen`；实际图像模型版本未公开。调用次数来自代理报告，不是独立提供方账单认证。第一批 8 槽/5 PNG 的历史记录完整保留在来源清单的 `batches.batch1`，不代表当前资源缺口或后续全局授权政策。

| 关卡角色 | 新身份 | 实际动作 |
| --- | --- | --- |
| 拳手 | 红夹克拳手 red_jacket_brawler | 拳击、步行/跑步/冲刺、受击和倒地起身 |
| 冲锋手 | 田径短跑手 track_sprinter | 同上；突进攻击仍用拳击图和原速度事件 |
| 踢手 | 紫发踢手 violet_kicker | 踢击及上述基础动作 |
| 小头目 | 铁腿 iron_leg | 重踢复用本角色真实踢击帧 |
| 最终 Boss | 银发路口头领 crossroads_captain | 拳/踢；回旋踢复用真实踢击帧，无独立生成必杀图集 |

原始图集为 1536×1024、6列4行、256px格。核心行依次为步行6、拳6、踢6、受击3+倒地3；扩展行为跑6、冲刺6、源待机6、倒地3+起身3。
13 张第二批原 PNG **字节不变**保存在 `godot/assets/homeward/source_art/batch2/`；第一批原图也保留。
运行 `python3 tools/build_homeward_enemy_art.py`（依赖 Pillow）可确定性重建 `enemies/` 的五张 480×640 图集与接触表。它只处理本地文件，无联网或提交逻辑。

派生图使用 alpha>=128 阈值转为严格 0/255，清理低透明噪点，最近邻缩小；原图不覆盖。队长核心末格向左扩展4源像素保留越格手部，并清除前一格最右4像素的异物。
每个身份使用一致缩放，正常站立约53px、Boss约59px；所有姿势保留固定水平站位锚点，不按每帧包围盒横向居中。80px格地面基线68，结合 sprite 中心和 y=-32 得到角色局部脚底-4；跑/冲刺保留源图脚部抬升。
扩展待机包含抬膝/踏步，因此运行时**有意只停留核心拳击第0格作为警戒**，不冒称完整呼吸。

`homeward_enemy_frames.gd` 按身份缓存内存 SpriteFrames，`homeward_actor.gd` 仅对 team1 覆盖显示解析；取消旧换色调制。原蓝色模板仍提供战斗数据，但不提供敌人最终画面。米多的原始八方向资源和共享类没有改变。
新敌人只有左右两朝向，源图朝左，朝右时镜像。跑/步行的起步、转身、停止共享本角色动作循环；受击、倒地、伏地、起身分别使用真实对应帧，死亡停留最终躺地帧。敌人 AI 不跳跃，未生成敌人跳跃图，缺失动作不静默替换成待机。

攻击画面仍由 MoveExecutor.current_frame 驱动并暂停独立播放，不改变 12fps、时长、伤害或事件。原拳击命中窗口为执行器1..2，而源接触格为2..3，因此拳击显示索引映射为 `[0,2,3,4,5,5]`（压缩预备姿势，末帧保持）；踢击执行器与源图都在2..3接触，索引0..5直接对应。突进拳仍展示真实拳击，不声称专门生成突进必杀。

[来源清单](../../godot/assets/homeward/art_provenance.json) 保留两批历史、素材路径和剩余限制；[新动作接触表和运行证据](../06_testing/evidence/homeward-enemies/) 可审阅。美术经过像素化整理，但不承诺与米多严格完美像素密度一致，队长细节仍较细。没有新增音频或多关完整战役。

## 聚焦验证

```bash
godot --headless --path . --editor --import --quit
python3 -m unittest tests.test_homeward_enemy_art -v
godot --headless --path . --script tools/homeward_enemy_art_smoke.gd
godot --headless --path . --script tools/homeward_stage_smoke.gd
godot --headless --path . --script tools/homeward_input_smoke.gd
godot --headless --path . --script tools/input_event_controls_smoke.gd
godot --headless --path . --script tools/miduo_import_smoke.gd
godot --headless --path . --script tools/gdscript_remediation_smoke.gd
```

关卡 smoke 用实际执行器攻击/碰撞走完四波，另测窗口去重、多人必杀、同队过滤、双方致命互换、锁、暂停、冷却和重建。
输入 smoke 使用真实 InputEventKey 测试本场景菜单、移动、攻击、必杀、暂停和重试。
确定性关卡流程将敌人设为测试靶以隔离波次与命中；不能替代真人难度、视觉和输入 UAT。
