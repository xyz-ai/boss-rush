# Project Overview

## 模块范围
本文件概述项目当前整体结构，重点说明：
- 当前项目处于什么阶段
- 当前实际运行的是哪条主链路
- 各目录的用途
- 哪些路径是当前主用，哪些是并行备用

## 当前项目阶段
当前项目处于 **MVP 验证阶段**。

当前真正追求的不是完整内容量，而是验证以下闭环是否成立：
- 进入场景后能看到玩家手牌和 Boss 牌列
- 点击玩家手牌后能触发 Boss 自动出牌
- 中央对撞区能显示本回合双方出牌
- HP、回合、局数、挑战胜负能推进
- BossDeckView 的“未查看 / 已查看 / 已使用”三态能支撑最小信息博弈

## 当前主目标
当前最重要的目标不是扩系统，而是维持一个可玩的原型：
- 主布局由 `Main.tscn` 控制
- `Main.gd` 负责绑定和流程推进
- 玩家手牌、BossDeck、中央 ClashArea 通过子视图动态刷新
- 继续保留后面切回更完整数据驱动架构的可能性

## 当前实际主入口
### 项目入口
- 路径：`project.godot`
- 当前主场景：`run/main_scene="uid://botjw7r3wvlpd"`
- 该 UID 对应场景：`res://scenes/main/Main.tscn`

### 当前主链路
1. `project.godot`
2. `scenes/main/Main.tscn`
3. `scenes/main/Main.gd`
4. `scripts/ui/Main.gd`
5. `scripts/ui/PlayerHandView.gd`
6. `scripts/ui/BossDeckView.gd`
7. `scripts/ui/ClashAreaView.gd`
8. `scripts/ui/CardView.gd`
9. `scripts/game/BattleCard.gd`
10. `scripts/game/CombatActorState.gd`
11. `scripts/game/BossAI.gd`
12. `scripts/game/BattleResolver.gd`

## 目录用途概览
### `scenes/main/`
- 当前主场景入口
- `Main.tscn` 提供编辑器可视布局
- `Main.gd` 只是一个薄封装，负责创建 `scripts/ui/Main.gd` 控制器

### `scripts/ui/`
- 当前 MVP 主 UI 控制层
- 负责节点绑定、UI 刷新、玩家手牌生成、BossDeck 生成、中央 ClashArea 展示
- 不负责数据驱动卡牌库，也不负责完整 Run/Shop/Boss 链路

### `scripts/game/`
- 当前 MVP 主战斗逻辑层
- 使用硬编码测试牌组
- 与 `scripts/ui/` 紧耦合但边界相对清晰：UI 调用这些脚本结算，脚本本身不直接持有 Godot 节点

### `scenes/ui/`
- 通用 UI 场景和视觉效果
- 当前主链路实际使用的是 `scenes/ui/CardView.tscn` 和 `ScreenEffects.tscn`
- `TooltipPanel.tscn` 当前存在，但主链路里没有直接实例化到 `Main.tscn`

### `scenes/battle/`
- 并行存在的另一套 BattleScene 体系
- 更接近未来的正式数据驱动结构
- 当前不是 `project.godot` 的 main_scene
- 测试脚本仍会实例化它，因此不能简单视为废弃

### `scripts/core/`
- 并行战斗/挑战状态链路的核心逻辑
- 包含 `RunState / SetState / ChallengeState / GameRun / BattleResolver / BossAI`
- 当前主入口未直接使用，但 Autoload `GameRun` 和测试链路会使用

### `scripts/data/`
- 数据加载与查询层
- `DataLoader` 是 Autoload
- 面向 JSON 数据驱动路径

### `scripts/systems/`
- 系统级辅助逻辑
- 包括窥牌、加注、崩坏效果、日志等
- 当前主链路和并行 BattleScene 链路都有不同程度依赖

### `tests/`
- 项目当前最重要的自检脚本目录
- 包含 `smoke_runner.gd`、`capture_battle.gd`、`layout_probe.gd`
- `smoke_runner.gd` 会同时覆盖当前主链路和并行 BattleScene 链路

## 核心文件 vs 辅助文件
## 当前主链路核心文件
### `project.godot`
- 决定真实入口和 Autoload

### `scenes/main/Main.tscn`
- 决定当前运行 UI 的主静态壳子
- 编辑器布局修改应优先在这里完成

### `scenes/main/Main.gd`
- 薄控制器入口
- 负责把场景交给 `scripts/ui/Main.gd`

### `scripts/ui/Main.gd`
- 当前 MVP 最核心控制器
- 决定绑定哪些节点、何时刷新 UI、何时推进回合/局/挑战

### `scripts/game/BattleResolver.gd`
- 当前 MVP 回合结算核心

### `scripts/game/BossAI.gd`
- 当前 MVP Boss 自动出牌核心

## 辅助但重要的文件
### `scripts/ui/PlayerHandView.gd`
- 只负责手牌内容生成

### `scripts/ui/BossDeckView.gd`
- 只负责 Boss 牌列内容生成和三态展示

### `scripts/ui/ClashAreaView.gd`
- 只负责中央对撞区

### `scenes/ui/ScreenEffects.gd`
- 不决定主布局，但会在运行时给绑定目标增加位置偏移

### `tests/smoke_runner.gd`
- 当前验证“能不能跑”的最直接入口

## 当前最重要的结构判断
### 当前主 UI 控制链路
- `Main.tscn` 负责主布局
- `scripts/ui/Main.gd` 负责控制流程和数据刷新
- `PlayerHandView / BossDeckView / ClashAreaView` 负责动态内容

### 当前并行备用链路
- `scenes/battle/BattleScene.tscn` + `scenes/battle/BattleScene.gd`
- `scripts/core/` + `scripts/data/` + `scripts/systems/`
- 更完整、更数据驱动，但不是当前 `main_scene`

后续开发时必须先判断自己要改的是哪条链路。

