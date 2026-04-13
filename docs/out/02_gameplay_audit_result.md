# Gameplay 审计结果

## 当前战斗流程状态
- 主入口链路：
  - `project.godot:14` 指向 `Main.tscn`
  - `scenes/main/Main.gd:7-15` 创建 `MvpMainController`
  - `scripts/ui/Main.gd:160-168` 完成主控初始化
- 当前实际主流程：
  1. 玩家点击战斗牌
  2. `Main._on_card_play_requested():1232` 立即锁输入并调用 `BattleResolver.resolve_round()`
  3. `Main._apply_round_result()` 立即写回已用牌、HP、状态变化与 clash 画面
  4. `Main._present_round_feedback():937` 进入短暂结果播报
  5. 如未终局，则 `Main._open_post_bet_window():1259`
  6. `EndTurn` 触发 `Main._on_end_turn_pressed():1427`
  7. `Main._finalize_current_turn():1433` 才真正推进下一回合

## 主行动 / EndTurn / Post-Bet 的关系
- 主行动：
  - 由点击战斗牌触发，不需要二次确认。
  - 结算发生在 `Main._on_card_play_requested():1232` 同一条链路里。
- `Post-Bet`：
  - 只在主行动结算后打开。
  - 本质是“主行动后的一次补充窗口”，不是主行动提交按钮。
- `EndTurn`：
  - 只在 `Post-Bet` 阶段承担“关闭窗口并推进回合”的职责。
  - 不负责主行动结算。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_on_card_play_requested():1232`，`_present_round_feedback():937`，`_open_post_bet_window():1259`，`_on_end_turn_pressed():1427`
- 风险等级：中
- 问题说明：
  当前回合主链路语义已经正确，但它不是通过一个显式 round-state 对象表达的，而是分散在多个阶段字段和 followup 分支中。
- 影响范围：
  主行动、结果播报暂停、`Post-Bet` 打开、`EndTurn` 推进。
- 最小修复建议：
  下一轮先在 `Main.gd` 内形成更明确的内部 round state 注释和 helper，再考虑正式抽象状态对象。

## Boss 出牌逻辑现状
- Boss 使用 `scripts/game/BossAI.gd`
- 核心入口：`choose_slot():27`
- 决策方式：
  - 根据玩家当前牌型分类为 `counter / neutral / wrong`
  - 按 `50 / 30 / 20` 基础权重抽取
  - 再叠加 archetype bonus
  - 返回未使用的 slot，而不是返回一张新建卡牌
- Boss 套牌来源：
  - `BattleCard.gd:24` 的 3 套固定模板
  - `pick_random_boss_template():66`

### 判断
- Boss 出牌逻辑目前是轻量且可测的。
- 风险不在算法复杂，而在“控制流仍由 UI controller 串起来”。

## 加注系统现状
- bet 卡入口仍在 `Main.gd` 内编排。
- 关键字段：
  - `_bet_phase:136`
  - `_post_bet_window_open:142`
  - `_post_bet_effects_applied`
  - `_player_pre_bet / _player_post_bet / _boss_post_bet`
- 关键函数：
  - `_on_player_bet_selected()`
  - `_apply_bet_modifiers()`
  - `_apply_post_bet_effects_if_needed():1404`
- 语义上已经稳定：
  - `Pre-Bet` 是可选前置
  - `Post-Bet` 是主行动后的补充窗口
  - `Hold Steady` 是普通 0 费 bet 卡，不再承担结束回合职责

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_bet_phase:136`，`_post_bet_window_open:142`，`_apply_post_bet_effects_if_needed():1404`
- 风险等级：中
- 问题说明：
  bet 系统语义清楚，但状态字段较多，切换路径也都压在主控脚本里。
- 影响范围：
  Pre-Bet、Post-Bet、EndTurn、回合反馈暂停。
- 最小修复建议：
  不要先改玩法，优先把 bet 相关状态读写收敛成几组固定 helper。

## 回合推进、局推进、挑战结束判断
- 局推进：
  - `Main._finish_set():1495`
- 挑战结束：
  - `Main._finish_challenge():1515`
- Actor 状态容器：
  - `CombatActorState.gd:20-91`
- 回合结算公式：
  - `BattleResolver.gd:6-72`

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_finalize_current_turn():1433`，`_finish_set():1495`，`_finish_challenge():1515`
- 风险等级：高
- 问题说明：
  set / challenge 推进目前仍然放在 UI controller 内，而不是独立运行时对象内。
- 影响范围：
  新增结算分支、未来存档/回放/调试工具、复杂规则扩展。
- 最小修复建议：
  先抽出“挑战级状态推进 helper”，不必一步到位重构成完整系统。

## 当前 gameplay 风险点

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`get_state_snapshot():175`
- 风险等级：中
- 问题说明：
  当前对外可观察状态依然主要从 UI controller 暴露，说明 gameplay 真正的统一状态源还未独立出来。
- 影响范围：
  smoke、调试、后续编辑器工具。
- 最小修复建议：
  后续如果继续扩玩法，优先考虑把 challenge/set/turn 的状态收束成独立对象，再由 UI 读。

### 问题标题
- 文件：`scripts/game/BattleResolver.gd`
- 位置：`resolve_round():6`
- 风险等级：低
- 问题说明：
  结算器本身足够轻量，但返回体仍包含 `summary_text`、`log_lines` 这类偏 UI/展示导向信息。
- 影响范围：
  纯逻辑层和展示层的边界。
- 最小修复建议：
  暂不必改；先在审计层明确它是“逻辑 + 展示友好输出”的折中实现。

