# 风险与修复建议

## 使用说明
- 本文只记录“值得修的结构问题”，不记录无意义的小瑕疵。
- 结论基于当前代码与 smoke 结果，不基于旧的乱码审计稿。
- 所有建议都以“最小修复”为原则，不建议在下一轮直接全量重构。

## 风险分级

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`ready():160`，`_refresh_ui():1040`，`_on_card_play_requested():1232`，`_finalize_current_turn():1433`
- 风险等级：高
- 问题说明：
  主控脚本已经成为 UI、流程、状态、结果播报、局推进的单点中心。
- 影响范围：
  主战斗全链路。
- 最小修复建议：
  先做内部 helper 拆分和职责注释，不直接做跨文件大重构。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_bind_nodes():261-403`
- 风险等级：高
- 问题说明：
  节点绑定过于刚性，主场景 UI 的局部改动很容易触发 assert。
- 影响范围：
  主场景启动、UI 迭代、多人改场景。
- 最小修复建议：
  重排 required/optional/legacy 三类节点，不再用一套规则处理所有显示节点。

### 问题标题
- 文件：`scripts/ui/Main.gd`，`tests/smoke_runner.gd`
- 位置：`_bind_nodes():293-349`；smoke 中多处 `_find_scene_node([...])`
- 风险等级：中
- 问题说明：
  新 UI 已经成型，但旧路径兼容仍然常驻主线。
- 影响范围：
  UI 路径收敛、维护成本、审计难度。
- 最小修复建议：
  先列出正式支持结构，再逐项删除旧路径 fallback。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_round_feedback_active:151`，`_bet_phase:136`，`_post_bet_window_open:142`，`_pending_round_followup:153`
- 风险等级：中
- 问题说明：
  主流程时序依赖多个字段组合表达，语义正确但结构脆弱。
- 影响范围：
  结果播报暂停、`Post-Bet`、`EndTurn`、下一回合准备。
- 最小修复建议：
  增加集中读取/写入 helper，先减少散点状态判断。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_ensure_summary_labels():421`，`_ensure_turn_result_popup_nodes():507`
- 风险等级：中
- 问题说明：
  部分关键 UI 节点只在运行时创建，场景编辑器里不可见。
- 影响范围：
  UI 协作、场景审阅、审计可读性。
- 最小修复建议：
  在代码与文档中明确这些运行时节点的存在与职责。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_boss_deck_root` 相关分支，`_setup_views():743`
- 风险等级：低
- 问题说明：
  `BossDeckView` 兼容层尚未完全清退，仍增加了理解成本。
- 影响范围：
  Boss 剩余手牌显示、旧结构兼容。
- 最小修复建议：
  在确认不再需要旧视图后统一移除。

### 问题标题
- 文件：`scenes/main/`
- 位置：`Main.tscn19834674964.tmp`、`Main.tscn19840351916.tmp`、`Main.tscn19867366818.tmp`、`Main.tscn19878347429.tmp`
- 风险等级：低
- 问题说明：
  临时场景文件会干扰人工检索和审计阅读。
- 影响范围：
  开发协作、文件检索、误引用。
- 最小修复建议：
  下轮仓库整理时清理无效临时文件。

## 修复优先级顺序
1. 先减轻 `scripts/ui/Main.gd` 的职责密度
2. 再缩小 `_bind_nodes()` 的硬依赖面
3. 然后清理旧路径 fallback
4. 再整理回合状态表达方式
5. 最后处理兼容残留和临时文件

