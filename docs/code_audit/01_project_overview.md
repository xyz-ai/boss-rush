# Project Overview

## 模块范围
本文件说明当前项目整体结构、当前阶段定位、主链路和目录职责。重点不是列文件，而是回答：

- 当前项目现在到底跑的是哪条链路
- 当前 MVP 在验证什么
- 哪些目录是主用，哪些目录是并行或预留
- 当前开发最不该误判的结构事实是什么

## 当前项目阶段
项目当前处于 **MVP 验证阶段**。当前代码重心不是扩内容，而是验证以下问题是否成立：

1. 玩家在有限信息下，是否能根据 Boss 固定 5 张对战牌池做推理
2. Reveal 后的 Boss 信息，是否真的能影响出牌决策
3. 胜负是否能被归因到判断与预判，而不是纯随机

因此，当前代码优先保证：

- 有一条能稳定跑通的单人 PvE 战斗闭环
- Boss 信息层与表现层职责清晰
- 回合、局、Reveal、Boss 剩余手牌数、中央结算区可以联动

当前不优先追求：

- 完整内容驱动
- 复杂 Boss 扩展
- 正式美术和复杂特效
- 商店、加注、连续 Boss 的完成度

## 当前主链路
### 启动入口
- 配置文件：[project.godot](../../project.godot)
- `run/main_scene` 指向 [scenes/main/Main.tscn](../../scenes/main/Main.tscn)

### 当前实际运行链
1. [project.godot](../../project.godot)
2. [scenes/main/Main.tscn](../../scenes/main/Main.tscn)
3. [scenes/main/Main.gd](../../scenes/main/Main.gd)
4. [scripts/ui/Main.gd](../../scripts/ui/Main.gd)
5. [scripts/ui/\*](../../scripts/ui)
6. [scripts/game/\*](../../scripts/game)

### 当前主链路的重要事实
- `Main.tscn` 提供主场景静态壳子和编辑器布局。
- `scenes/main/Main.gd` 很薄，只负责创建并转发给 `MvpMainController`。
- 真正驱动当前主链路的是 [scripts/ui/Main.gd](../../scripts/ui/Main.gd)。
- 战斗牌、手牌模板、Boss 模板、AI、结算逻辑来自 [scripts/game/](../../scripts/game)。
- 当前主链路不依赖 `DataLoader` 提供卡牌内容，也不依赖 `scripts/core/*` 的状态模型。

## 核心目录说明
### `scenes/main/`
- 当前启动入口场景。
- [Main.tscn](../../scenes/main/Main.tscn) 是主 UI 壳子。
- [Main.gd](../../scenes/main/Main.gd) 只是 controller wrapper，不承担战斗业务。

### `scripts/ui/`
- 当前主链路 UI 控制层。
- 包含主流程编排器 [Main.gd](../../scripts/ui/Main.gd) 以及各视图模块。
- 负责节点绑定、刷新调度、动态生成卡牌、写日志、更新 reveal 状态对应的视图。

### `scripts/game/`
- 当前主链路战斗逻辑层。
- 负责：
  - 极简 3 类牌模型
  - actor 状态
  - Boss 选牌
  - 回合结算
- 这些脚本基本不直接依赖 Godot 场景节点。

### `scenes/ui/`
- 通用 UI 小场景与效果层。
- 当前主链路里确定在用的是：
  - [CardView.tscn](../../scenes/ui/CardView.tscn)
  - [ScreenEffects.tscn](../../scenes/ui/ScreenEffects.tscn)
- 其余 UI 场景更多偏复用件或并行链路组件。

### `scenes/battle/`
- 并行存在的另一套 BattleScene 链路。
- 它更接近正式数据驱动方向，但不是当前启动入口。
- 不能说“没用”，因为测试脚本仍会实例化它。

### `scripts/core/`
- 并行战斗状态与 Run/Set/Challenge 模型。
- 包含 `GameRun`、`RunState`、`SetState`、`ChallengeState`、并行版 `BossAI` / `BattleResolver`。
- 当前主链路不直接使用，但 `GameRun` 是 autoload，测试和并行 battle path 会用。

### `scripts/data/`
- 数据加载层。
- [DataLoader.gd](../../scripts/data/DataLoader.gd) 是 autoload，服务于并行数据驱动链路。
- 当前主链路里的卡牌模板并不从这里取。

### `scripts/systems/`
- 一组系统级逻辑，如加注、peek、崩坏表现、日志等。
- 主要服务并行 `scripts/core + scenes/battle` 链路。
- 当前主链路里直接用到的很少。

### `data/`
- JSON 数据目录。
- 主要被 `DataLoader` 和并行链路消费。
- 当前主链路没有把卡牌与 Boss 模板完全切到这里。

### `tests/`
- 当前项目最重要的自检目录。
- [smoke_runner.gd](../../tests/smoke_runner.gd) 会同时检查主链路和并行 BattleScene 链路。
- 这意味着 smoke 失败不一定只说明主入口坏了，也可能是并行路径坏了。

## 当前最关键的系统约束
1. 主入口必须继续是 `Main.tscn` 链路，除非明确要切回并行 BattleScene。
2. `BossDeckView` 与 `BossBattleDeckView` 的职责不能混淆。
3. `scripts/ui/Main.gd` 现在是主链路总控制器，很多行为都集中在这里，修改时要注意牵一发而动全身。
4. 当前主链路的卡牌模型已经极简化为 3 类固定模板，不应再误按旧多标签/多变体逻辑理解。
5. 并行链路仍然存在，后续改动要先判断自己在改哪条链。

## 当前结构的核心结论
- 当前项目不是“只有一套系统”，而是主用 MVP 链路和并行数据驱动链路并存。
- 面向玩家当前看到的主界面，应优先阅读 `Main.tscn + scripts/ui + scripts/game`。
- 面向未来正式 Run/Shop/Boss 扩展，应优先阅读 `scripts/core + scripts/data + scripts/systems + scenes/battle`。
