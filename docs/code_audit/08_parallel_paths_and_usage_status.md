# Parallel Paths and Usage Status

## 模块范围
本文件专门回答一个问题：

当前项目里，究竟有哪几条“可运行但并行存在”的路径？  
哪条是主链路，哪条是备用/旧路径，哪条只在测试里被用到？

## 路径 A：当前主入口 MVP 路径

## 当前使用状态
- **当前主用**
- `project.godot` 直接启动这条路径

## 核心组成
- `project.godot`
- `scenes/main/Main.tscn`
- `scenes/main/Main.gd`
- `scripts/ui/Main.gd`
- `scripts/ui/PlayerHandView.gd`
- `scripts/ui/BossDeckView.gd`
- `scripts/ui/ClashAreaView.gd`
- `scripts/ui/CardView.gd`
- `scripts/game/BattleCard.gd`
- `scripts/game/CombatActorState.gd`
- `scripts/game/BossAI.gd`
- `scripts/game/BattleResolver.gd`

## 主要特点
- 目标明确：提供最小可玩的战斗原型
- 卡牌数据是硬编码测试牌
- 布局主壳子由 `Main.tscn` 控制
- 动态内容由 `scripts/ui/*` 重建
- 战斗状态由 `scripts/game/*` 管理

## 适合做什么
- 继续打磨当前可玩的 MVP
- 做快速交互验证
- 调整当前主 UI 的静态布局

## 不适合做什么
- 不适合作为完整数据驱动内容扩展入口
- 不适合作为长期 Run/Shop/Boss 多内容系统的唯一基础

## 路径 B：并行 BattleScene 数据驱动路径

## 当前使用状态
- **并行存在**
- 不是 `project.godot` 的 main_scene
- 测试脚本会实例化

## 核心组成
- `scenes/battle/BattleScene.tscn`
- `scenes/battle/*.gd`
- `scripts/core/*.gd`
- `scripts/data/*.gd`
- `scripts/systems/*.gd`
- `data/*.json`

## 主要特点
- 更接近正式架构
- 使用 `RunState / SetState / ChallengeState`
- 使用 `DataLoader` 和 JSON
- 包含 Shop、Addon、Peek、CollapseEffects 等正式系统
- BattleScene 自带完整绑定和刷新逻辑

## 适合做什么
- 恢复/推进未来正式内容链路
- 做数据驱动战斗、商店、Boss 扩展

## 当前不适合做什么
- 不适合作为当前 main_scene 的直接说明文档主线
- 当前如果只是排查 `Main.tscn` 的显示问题，不应先改这套

## 路径 C：测试和探针路径

## 当前使用状态
- **开发辅助**
- 不直接面向玩家

## 核心组成
- `tests/smoke_runner.gd`
- `tests/capture_battle.gd`
- `tests/layout_probe.gd`

## 作用
- 验证两套链路都还能实例化
- 验证当前主入口 `Main.tscn` 的基本可玩性
- 验证并行 `BattleScene.tscn` 的场景和局部流程
- 验证布局越界和截图

## 为什么必须关注这条路径
- 因为它会同时测主链路和并行链路
- 继续开发时，测试失败不一定代表当前主入口坏了，也可能是并行链路断了

## 路径对比

| 路径 | 当前是否主用 | 数据来源 | 布局控制 | 主要目标 |
| --- | --- | --- | --- | --- |
| `Main.tscn + scripts/ui + scripts/game` | 是 | 硬编码 MVP 数据 | 编辑器主壳子 + 局部动态内容 | 当前可玩 MVP |
| `BattleScene.tscn + scripts/core/data/systems` | 否，并行存在 | JSON + DataLoader | BattleScene 自己绑定和部分运行时布局 | 未来正式数据驱动链路 |
| `tests/*` | 否，开发辅助 | 混合 | 无主布局 | 验证两套路径都还能跑 |

## 当前开发建议
### 如果你要改当前玩家真正看到的画面
优先看：
- `scenes/main/Main.tscn`
- `scenes/main/Main.gd`
- `scripts/ui/*`

### 如果你要改未来正式挑战/商店/多 Boss
优先看：
- `scripts/core/*`
- `scripts/data/*`
- `scripts/systems/*`
- `scenes/battle/*`

### 如果你要改测试
先确认测试断言覆盖的是：
- 主入口 MVP
- 还是并行 BattleScene

