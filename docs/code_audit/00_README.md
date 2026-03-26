# Code Audit README

## 目的
这组文档用于给后续继续开发 `Boss Rush Prototype` 的人快速建立项目心智模型。

本轮文档只做两件事：
- 标出当前实际运行的主链路
- 把 UI、战斗逻辑、动态生成、并行旧链路拆开说明

这些文档不是“文件清单”，而是“接手说明书”。阅读时应优先理解：
- 当前真正跑起来的是哪一套场景和脚本
- 哪些节点是编辑器静态壳子
- 哪些内容是运行时动态生成
- 哪些路径仍然是并行存在的备用/旧链路

## 推荐阅读顺序
### 第一轮先看
1. [01_project_overview.md](./01_project_overview.md)
2. [06_entrypoints_and_call_flow.md](./06_entrypoints_and_call_flow.md)
3. [02_scene_structure.md](./02_scene_structure.md)
4. [03_ui_module_audit.md](./03_ui_module_audit.md)

### 继续排查运行时问题时看
5. [05_runtime_generation_and_refresh.md](./05_runtime_generation_and_refresh.md)
6. [07_risk_points_and_dev_notes.md](./07_risk_points_and_dev_notes.md)

### 需要理解战斗逻辑或并行体系时看
7. [04_gameplay_module_audit.md](./04_gameplay_module_audit.md)
8. [08_parallel_paths_and_usage_status.md](./08_parallel_paths_and_usage_status.md)

## 文档范围
本目录聚焦以下内容：
- `project.godot`
- `scenes/main/`
- `scripts/ui/`
- `scripts/game/`
- `scenes/ui/`
- `tests/`
- 与当前 MVP 强相关的 `scenes/battle/`、`scripts/core/`、`scripts/data/`、`scripts/systems/`

不作为主叙述重点，但会记录：
- `scenes/shop/`
- JSON 数据文件
- 并行存在但当前不是主入口的 BattleScene 路径

## 当前判断结论
- 当前主入口是 `project.godot -> scenes/main/Main.tscn`
- 当前主 UI/战斗链路是 `scenes/main/Main.gd -> scripts/ui/Main.gd -> scripts/ui/* + scripts/game/*`
- 项目中还并存一套更完整、更数据驱动的链路：`scenes/battle/* + scripts/core/* + scripts/data/* + scripts/systems/*`
- 这两套链路共存，是当前项目结构最重要的风险点

## 本目录文件说明
### [01_project_overview.md](./01_project_overview.md)
项目阶段、目录概览、当前主目标、当前主链路的总览。

### [02_scene_structure.md](./02_scene_structure.md)
主场景和关键 UI 场景结构，哪些节点由编辑器控制，哪些只是动态内容容器。

### [03_ui_module_audit.md](./03_ui_module_audit.md)
审计 `scripts/ui/` 和 `scenes/ui/`，说明谁负责节点绑定、UI 刷新、动态生成卡牌、BossDeck 三态、中央对撞区、日志和特效。

### [04_gameplay_module_audit.md](./04_gameplay_module_audit.md)
审计 `scripts/game/` 和并行的 `scripts/core/`、`scripts/systems/`，说明职责边界和与 UI 的关系。

### [05_runtime_generation_and_refresh.md](./05_runtime_generation_and_refresh.md)
专门整理所有运行时 `instantiate / add_child / queue_free / Label.new / RichTextLabel.new` 的地方，方便后续排查“编辑器改了为什么运行不一样”。

### [06_entrypoints_and_call_flow.md](./06_entrypoints_and_call_flow.md)
用文字步骤还原入口、初始化、出牌、结算、推进回合/局/挑战的调用链。

### [07_risk_points_and_dev_notes.md](./07_risk_points_and_dev_notes.md)
总结最容易踩坑的点，并给出只作为建议的后续开发方向。

### [08_parallel_paths_and_usage_status.md](./08_parallel_paths_and_usage_status.md)
专门对比“当前主链路”和“并行 BattleScene 链路”，避免后续接手时误判哪套代码在生效。

