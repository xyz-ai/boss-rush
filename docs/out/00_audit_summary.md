# 本轮审计总览

## 审计范围
- 主入口与启动链路：`project.godot:14`、`scenes/main/Main.tscn:10`、`scenes/main/Main.gd:3-15`
- 主场景与主控：`scenes/main/Main.tscn`、`scripts/ui/Main.gd`
- Gameplay 核心：`scripts/game/BattleCard.gd`、`scripts/game/CombatActorState.gd`、`scripts/game/BossAI.gd`、`scripts/game/BattleResolver.gd`
- 回归验证：`tests/smoke_runner.gd`，以及 `tests/out/audit_smoke.log`

## 审计结论总览
- 当前主链路是可运行、可验证的，主流程行为已经稳定。
- 启动链路清晰：`project.godot` 指向 `Main.tscn`，`Main.tscn` 再通过 `scenes/main/Main.gd` 创建 `MvpMainController`。
- 战斗主流程已经符合当前设计：点击战斗牌立即结算，短暂停留在结果播报，再根据情况进入 `Post-Bet`，最后由 `EndTurn` 推进回合。
- 真正的问题不在“功能不能跑”，而在“结构风险过于集中”。风险核心集中在 `scripts/ui/Main.gd`。
- 已复跑 smoke：`E:\godot\Godot_console.exe --headless --log-file e:\boss-rush\tests\out\audit_smoke.log --path e:\boss-rush --script res://tests/smoke_runner.gd`，结果为 `SMOKE OK`。

## 整体健康度判断
- 结论：中等偏上，适合继续开发，但不适合继续无边界堆功能。
- 原因：
  - 行为层面已经稳定，有 smoke 兜底。
  - 结构层面高度依赖单一主控脚本，未来 UI 或流程继续迭代时，回归风险会快速上升。
  - 当前最需要的是“收束结构边界”，而不是继续追加新功能。

## 当前最值得优先处理的前 5 个问题

### 1. 主控脚本承担职责过多
- 文件：`scripts/ui/Main.gd`
- 位置：`ready():160`，`_bind_nodes():261`，`_setup_views():738`，`_refresh_ui():1040`，`_on_card_play_requested():1232`，`_finalize_current_turn():1433`
- 风险等级：高
- 问题说明：
  当前同一个脚本同时负责节点绑定、UI 初始化、结果弹层、回合结算编排、`Post-Bet`、局推进、挑战结束判断和调试输出。
- 影响范围：
  主战斗 UI、主流程时序、回归测试维护成本。
- 最小修复建议：
  先不要重构全量系统，只先把“回合/局/挑战推进逻辑”和“UI 显示逻辑”从 `Main.gd` 内部按 helper 级别拆分。

### 2. 旧 UI 路径兼容仍残留在运行时和测试中
- 文件：`scripts/ui/Main.gd`，`tests/smoke_runner.gd`
- 位置：`_bind_nodes():261-349`；`tests/smoke_runner.gd` 中多处 `_find_scene_node([...旧路径...])`
- 风险等级：高
- 问题说明：
  虽然新 UI 已接好，但生产代码和 smoke 仍保留 `PlayerBetArea`、`BossBetArea`、`BossDeckView`、`PeekBossBetButton` 等旧路径兼容。
- 影响范围：
  后续 UI 再调整时，容易出现“新结构能跑，但代码继续背旧包袱”的情况。
- 最小修复建议：
  等下一轮结构修复时，把“当前正式支持的场景树”收敛成一套，旧路径仅留在短期过渡分支，不长期保留在主线。

### 3. `_bind_nodes()` 的 assert 面过大
- 文件：`scripts/ui/Main.gd`
- 位置：`_assert_required():258`，`_bind_nodes():368-403`
- 风险等级：高
- 问题说明：
  当前新版 UI 的大量节点都被视为硬依赖，任何场景层的小调整都可能直接让 `_ready()` 崩掉。
- 影响范围：
  UI 改版、多人协作、场景编辑器内的小重命名或层级调整。
- 最小修复建议：
  下一轮先按“能力分级”整理节点：主流程硬依赖、可选显示节点、兼容节点分层处理，不要继续一律 assert。

### 4. UI 文本职责已经改善，但仍集中在单点手工协调
- 文件：`scripts/ui/Main.gd`
- 位置：`_current_center_guidance_text():848`，`show_turn_result_popup():867`，`_refresh_bet_ui():1070`，`_refresh_summary_texts():606`
- 风险等级：中
- 问题说明：
  `TurnResultPopup`、中心提示、Bet 提示、Summary 的职责已经比之前清晰，但仍是 `Main.gd` 单点手工切换，缺少更小粒度的显示约束。
- 影响范围：
  Result Mode、CenterInfo、BetResultHint、Summary Panel 后续联动。
- 最小修复建议：
  提炼出更少的 UI ownership helper，例如“中心提示刷新”“结果播报刷新”“summary 刷新”三条固定路径，减少交叉写入。

### 5. 回合时序正确，但编码方式较脆弱
- 文件：`scripts/ui/Main.gd`
- 位置：`_round_feedback_active:151`，`_bet_phase:136`，`_post_bet_window_open:142`，`_pending_round_followup:153`，相关逻辑分布于 `937-962`、`1232-1433`
- 风险等级：中
- 问题说明：
  当前回合状态依赖多个布尔值和 followup 字段组合成立，虽然 smoke 已覆盖主流程，但后续加分支时很容易出现时序回归。
- 影响范围：
  结果暂停、`Post-Bet` 打开、`EndTurn` 显示、下一回合准备。
- 最小修复建议：
  先在 `Main.gd` 内部定义更清晰的 round state 注释和 helper，再考虑是否升级成更明确的状态对象。

