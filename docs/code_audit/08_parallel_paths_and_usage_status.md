# Parallel Paths and Usage Status

## 模块范围
本文件专门回答一个问题：  
**当前项目到底有哪些并行路径，它们各自是否还在被使用？**

结论必须基于：
- `project.godot` 启动入口
- 场景挂载关系
- 脚本直接调用关系
- 测试脚本实际实例化路径

## 路径 A：当前主用 MVP 路径
### 当前状态
- **当前主用**
- 由 `project.godot` 直接启动

### 组成
- [project.godot](../../project.godot)
- [scenes/main/Main.tscn](../../scenes/main/Main.tscn)
- [scenes/main/Main.gd](../../scenes/main/Main.gd)
- [scripts/ui/Main.gd](../../scripts/ui/Main.gd)
- [scripts/ui/*](../../scripts/ui)
- [scripts/game/*](../../scripts/game)

### 证据
- `project.godot` 的 `run/main_scene` 指向 `scenes/main/Main.tscn`
- `Main.gd` 在 `_ready()` 中直接创建 `scripts/ui/Main.gd` controller
- `scripts/ui/Main.gd` 直接使用 `scripts/game/BattleCard.gd`、`CombatActorState.gd`、`BossAI.gd`、`BattleResolver.gd`

### 当前用途
- 当前玩家启动后看到的界面和玩法
- 当前最小可玩战斗闭环
- Reveal / BossBattleDeckView / BossDeckView / ClashArea 联动验证

## 路径 B：并行 BattleScene 数据驱动路径
### 当前状态
- **并行存在**
- **不是当前启动主入口**
- **测试仍会实例化**

### 组成
- [scenes/battle/BattleScene.tscn](../../scenes/battle/BattleScene.tscn)
- [scenes/battle/BattleScene.gd](../../scenes/battle/BattleScene.gd)
- [scripts/core/*](../../scripts/core)
- [scripts/data/*](../../scripts/data)
- [scripts/systems/*](../../scripts/systems)
- [data/*.json](../../data)

### 证据
- `project.godot` 没有把它设为 main scene
- [scripts/core/GameRun.gd](../../scripts/core/GameRun.gd) 仍会通过 `SignalBus` 请求切到 battle screen
- [tests/smoke_runner.gd](../../tests/smoke_runner.gd) 会显式实例化 `BattleScene.tscn`

### 当前用途
- 未来更完整的数据驱动方向
- 仍被 smoke 覆盖
- 仍被 autoload `GameRun` / `DataLoader` / `SignalBus` 体系使用

### 当前不适合作为哪类判断依据
- 不适合作为“当前玩家进入游戏会看到什么”的第一参考
- 不适合作为 `Main.tscn` 主界面问题的第一排查目标

## 路径 C：autoload 与全局服务路径
### 当前状态
- **全局存在**
- 同时服务不同链路，但主链路并不完全依赖它们

### 组成
- [scripts/util/SignalBus.gd](../../scripts/util/SignalBus.gd)
- [scripts/data/DataLoader.gd](../../scripts/data/DataLoader.gd)
- [scripts/core/GameRun.gd](../../scripts/core/GameRun.gd)

### 证据
- `project.godot` 中已注册 autoload

### 当前作用判断
- `SignalBus`
  - 是全局信号层
  - 当前主链路 `Main.tscn` 并不高度依赖它推进战斗
- `DataLoader`
  - 当前主链路没有把主牌模型建立在它上面
  - 并行 BattleScene 路径高度依赖它
- `GameRun`
  - 更偏并行正式链路
  - 当前主链路主要依靠 `MvpMainController` 自己维护状态

## 路径 D：测试与探针路径
### 当前状态
- **开发辅助**
- 不面向玩家

### 组成
- [tests/smoke_runner.gd](../../tests/smoke_runner.gd)
- [tests/capture_battle.gd](../../tests/capture_battle.gd)
- [tests/layout_probe.gd](../../tests/layout_probe.gd)

### 当前用途
- 同时验证主链路与并行 BattleScene 链路
- 做布局边界检查
- 做截图和探针输出

### 需要特别注意
- smoke 失败不一定说明主入口坏了
- 也可能是并行路径或 core/data/systems 的断言失败

## 当前仓库里的“未删除但非主用”内容
### `scenes/battle/*`
- 当前非主入口
- 但不是废弃

### `scripts/core/*`
- 当前非主链路逻辑来源
- 但仍是 autoload / 测试 / 并行 battle path 的重要依赖

### `scripts/data/*` 与 `data/*.json`
- 当前主链路不是主要消费者
- 但并行链路仍需要

### `scenes/shop/*`
- 当前主链路未直接进入 shop 流程
- 更偏并行完整 run 路径的一部分

## 当前“预留接口”与“遗留/旧实现”的判断
### 更像预留接口
- `BossHandAnimationAnchor`
- `BossBetArea`
- `scripts/core` 中更完整的 challenge/set/run 数据模型

### 更像并行旧实现 / 临时共存实现
- `scenes/battle/BattleScene.gd` 中自带的大量布局与 battle flow
- `scripts/core/BattleResolver.gd` 与 `scripts/game/BattleResolver.gd` 的并存
- `scripts/core/BossAI.gd` 与 `scripts/game/BossAI.gd` 的并存

### 当前代码中未发现明确证据可直接判废弃
- `scripts/core/*`
- `scenes/battle/*`
- `scripts/data/*`

它们不是当前主入口，但仍有被测试或 autoload 体系引用的证据。

## 当前最重要的判断原则
### 如果你要改玩家现在实际看到的战斗界面
优先看：
- `scenes/main/Main.tscn`
- `scenes/main/Main.gd`
- `scripts/ui/*`
- `scripts/game/*`

### 如果你要改未来更完整的数据驱动体系
优先看：
- `scripts/core/*`
- `scripts/data/*`
- `scripts/systems/*`
- `scenes/battle/*`

### 如果你要解释 smoke 失败
先判断断言是来自：
- 主链路 `Main.tscn`
- 并行 `BattleScene`
- 还是 `core/data/systems`

## 最终结论
当前项目最关键的结构事实不是“有很多文件”，而是：  
**有两套并行存在的战斗实现，而当前真正启动给玩家看的，是 `Main.tscn + scripts/ui + scripts/game` 这套 MVP 主链路。**
