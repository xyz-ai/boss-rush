# Code Audit README

## 目录用途
`docs/code_audit/` 用于记录 **当前代码实际结构**，不是设计稿，也不是未来规划。
本轮文档已按当前仓库代码重新整理，重点对齐以下事实：

- 当前真正的启动主链路是 `project.godot -> scenes/main/Main.tscn -> scenes/main/Main.gd -> scripts/ui/Main.gd -> scripts/game/*`
- 项目里仍并存一套更完整但非当前启动入口的并行战斗链路：`scenes/battle/* + scripts/core/* + scripts/data/* + scripts/systems/*`
- 主链路里 `BossDeckView` 与 `BossBattleDeckView` 职责不同，不能混写
- 当前很多 UI 内容是运行时动态生成的，文档会明确哪些是静态壳子，哪些是运行时内容

## 推荐阅读顺序
### 第一轮快速接手
1. [01_project_overview.md](./01_project_overview.md)
2. [06_entrypoints_and_call_flow.md](./06_entrypoints_and_call_flow.md)
3. [02_scene_structure.md](./02_scene_structure.md)
4. [03_ui_module_audit.md](./03_ui_module_audit.md)

### 排查刷新、重建、显示不一致问题
5. [05_runtime_generation_and_refresh.md](./05_runtime_generation_and_refresh.md)
6. [07_risk_points_and_dev_notes.md](./07_risk_points_and_dev_notes.md)

### 继续看战斗逻辑或辨认并行链路
7. [04_gameplay_module_audit.md](./04_gameplay_module_audit.md)
8. [08_parallel_paths_and_usage_status.md](./08_parallel_paths_and_usage_status.md)

## 文档分工
### 结构类
- [01_project_overview.md](./01_project_overview.md)：项目阶段、目录用途、当前主链路
- [02_scene_structure.md](./02_scene_structure.md)：主场景、关键节点、布局与功能节点
- [08_parallel_paths_and_usage_status.md](./08_parallel_paths_and_usage_status.md)：主链路与并行链路的实际使用状态

### 调用流类
- [06_entrypoints_and_call_flow.md](./06_entrypoints_and_call_flow.md)：从启动到出牌、结算、推进回合/局的调用链
- [05_runtime_generation_and_refresh.md](./05_runtime_generation_and_refresh.md)：初始化、每局重置、每回合刷新、运行时重建

### 模块审查类
- [03_ui_module_audit.md](./03_ui_module_audit.md)：`scripts/ui/`、`scenes/ui/` 与主场景 UI 职责
- [04_gameplay_module_audit.md](./04_gameplay_module_audit.md)：`scripts/game/` 与战斗状态流

### 风险与开发建议
- [07_risk_points_and_dev_notes.md](./07_risk_points_and_dev_notes.md)：最容易误改、最值得警惕的结构风险和 MVP 阶段建议

## 当前最关键结论
- `Main.tscn` 现在是主入口场景，主布局主要由编辑器场景控制，不再由 `scripts/ui/Main.gd` 全面接管几何。
- `scripts/ui/Main.gd` 是当前 MVP 的实际总控制器，既负责主流程，也负责大部分 UI 刷新调度。
- `scripts/game/*` 是当前主链路的战斗逻辑来源，使用固定 3 类牌模型与固定模板，不依赖 `DataLoader` 的 JSON 牌库。
- `BossDeckView` 是表现层，表示 Boss 手里还剩几张；`BossBattleDeckView` 是信息层，表示本局固定 5 张对战牌池、Reveal 状态和已使用灰掉状态。
- 并行 `BattleScene` 链路仍在仓库中，并且测试脚本会实例化它，不能简单视为废弃代码。

## 阅读时的判断原则
- 先判断问题发生在 **主链路** 还是 **并行链路**。
- 遇到“编辑器改了、运行时不一样”，优先看 [05_runtime_generation_and_refresh.md](./05_runtime_generation_and_refresh.md)。
- 遇到“到底谁负责 reveal / 手牌 / clash / 回合推进”，优先看 [03_ui_module_audit.md](./03_ui_module_audit.md) 和 [04_gameplay_module_audit.md](./04_gameplay_module_audit.md)。
