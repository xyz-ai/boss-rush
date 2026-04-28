# Entrypoints and Call Flow

## 模块范围
本文件梳理当前项目主链路的入口、调用流和已验证的战斗回合语义。  
重点覆盖：

- 从项目启动到进入主战斗界面
- 从点击战斗牌到 Boss 出牌、主结算、Post-Bet、EndTurn 的完整流程
- `TurnResultPopup`、`EndTurn`、`Hold Steady` 在当前仓库中的真实职责
- 对应的 smoke 测试入口与验收结论

## 当前基线结论
当前仓库已经满足本轮目标语义，不需要再新增运行时修复补丁：

1. 点击战斗牌会立即提交本回合主行动，不会等待 `Hold Steady` 或其他按钮二次确认。
2. 主行动一旦提交，会立即完成玩家出牌、Boss 出牌、clash 主结算、HP 与状态更新、手牌刷新，以及 `TurnResultPopup` 展示。
3. 若 bet mode 开启且本回合未直接进入终局，则主行动结算后会进入 `Post-Bet` 窗口。
4. `EndTurn` 只在 `Post-Bet` 窗口中显示，只负责结束 `Post-Bet` 并推进到下一回合。
5. `Hold Steady` 只是普通的 0 费 bet 卡，可用于 `Pre-Bet` 和 `Post-Bet`，但不再承担“提交主行动”或“结束回合”的职责。

## 一、项目启动链路
### 启动入口
1. [project.godot](../../project.godot) 指定主场景为 [scenes/main/Main.tscn](../../scenes/main/Main.tscn)
2. Godot 实例化 `Main.tscn`
3. [scenes/main/Main.gd](../../scenes/main/Main.gd) `_ready()` 执行
4. `Main.gd` 创建 [scripts/ui/Main.gd](../../scripts/ui/Main.gd) 中的 `MvpMainController`
5. `Main.gd` 调用 `controller.ready()`

### `MvpMainController.ready()` 调用顺序
1. `_bind_nodes()`
2. `_hide_turn_result_popup(true)`
3. `_configure_mouse_filters()`
4. `_setup_views()`
5. `_sync_reveal_battle_deck_layout()`
6. `_ensure_overlay_log()`
7. `ScreenEffects.bind_target(_content_root)`
8. `_start_new_challenge()`

## 二、初始化战斗链路
### `_start_new_challenge()`
1. 隐藏并重置 `TurnResultPopup`
2. 清空日志、比分、阶段状态和随机数状态
3. 创建玩家与 Boss 的 `MvpCombatActorState`
4. 设置双方长期状态为 `BOD 3 / SPR 3 / REP 3`
5. 调用 `_reset_for_current_set()`
6. 写入挑战开始日志
7. 调用 `_refresh_ui()`

### `_reset_for_current_set()`
1. 玩家 deck blueprint 固定为 `Aggression / Aggression / Defense / Pressure / Pressure`
2. Boss 从 `template_a / template_b / template_c` 中随机选 1 套
3. 用 blueprint 重置双方本局牌组
4. 重置双方 HP 到 `SET_HP`
5. reveal 设回 `false`
6. `Turn` 设回 `1`
7. 调用 `_reset_turn_bet_state(true)` 清空本回合 bet 状态
8. 清空 `ClashArea`

## 三、Reveal 链路
### 触发链
1. 玩家点击 `RevealBattleDeckButton`
2. [scripts/ui/BossBattleDeckView.gd](../../scripts/ui/BossBattleDeckView.gd) `_on_reveal_pressed()`
3. `reveal_requested.emit()`
4. [scripts/ui/Main.gd](../../scripts/ui/Main.gd) `_on_reveal_requested()`

### 状态写回
1. 若挑战未结束且当前 set 尚未 reveal：
2. `_boss_battle_revealed = true`
3. 写一条日志
4. 调用 `_refresh_ui()`

### 视图刷新
1. `_boss_battle_deck_view.set_deck(_boss_state.cards, _boss_battle_revealed, _boss_state.used_slots)`
2. `BossBattleDeckView` 维持固定 5 槽位
3. 未使用槽位从 `hidden` 变成 `normal`
4. 已使用槽位保持 `used`

## 四、玩家点击战斗牌后的主行动链路
### 事件入口
1. 玩家点击玩家手牌中的 `CardView`
2. [scripts/ui/PlayerHandView.gd](../../scripts/ui/PlayerHandView.gd) `_on_card_pressed(slot_index)`
3. `card_play_requested.emit(slot_index)`
4. [scripts/ui/Main.gd](../../scripts/ui/Main.gd) `_on_card_play_requested(slot_index)`

### `_on_card_play_requested()` 的当前语义
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 631-656 行

1. 拦截非法输入：
   - `challenge_over`
   - `input_locked`
   - `post_bet_window_open`
   - 该手牌槽位已使用
2. 读取玩家当前战斗牌
3. `BossAI.choose_slot(_boss_state, player_card)` 立即选出 Boss 槽位
4. 锁定输入并禁用玩家手牌点击
5. `BattleResolver.resolve_round(...)` 立即结算本轮主行动
6. 若存在 `Pre-Bet`，先把其效果写入本轮主结算文本
7. `_apply_round_result(result)` 立即应用本轮主结算
8. 若本轮已进入终局状态，则直接 `_finalize_current_turn()`
9. 否则 `_open_post_bet_window(result)`，进入 `Post-Bet`

### 这意味着什么
点击战斗牌时，以下事情会立刻发生：

- 战斗牌被锁定并视为已提交
- 玩家手牌立即减少
- Boss 立即出牌
- clash 主结算立即完成
- HP、长期状态、已用牌、ClashArea 立即刷新
- `TurnResultPopup` 立即显示
- 若本轮未终局，则立即切入 `Post-Bet`

当前仓库里不存在“点击战斗牌只记录选择，等再点 `Hold Steady` 才真正结算”的路径。

## 五、Post-Bet 与 EndTurn 链路
### `_open_post_bet_window(result)`
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 658-664 行

1. `_post_bet_window_open = true`
2. `_post_bet_effects_applied = false`
3. `_bet_phase = post`
4. `_lock_boss_post_bet(result)` 锁定 Boss 当前回合的 Post-Bet
5. 写日志 `"Post-Bet phase opened."`
6. `_refresh_ui()`

### `_apply_post_bet_effects_if_needed()`
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 803-824 行

1. 仅在 `Post-Bet` 打开、效果尚未应用、且已有本轮主结算结果时生效
2. 用 `_player_post_bet` 和 `_boss_post_bet` 生成附加伤害/反噬结果
3. 立即把 Post-Bet 的 HP 变化写回玩家和 Boss
4. 写日志
5. `_refresh_ui()`

### `_on_end_turn_pressed()`
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 826-830 行

1. 只允许在 `Post-Bet` 窗口打开时触发
2. 先 `_apply_post_bet_effects_if_needed()`
3. 再 `_finalize_current_turn()`

### `_finalize_current_turn()`
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 832 行起

1. 关闭 `Post-Bet`
2. 关闭 bet phase
3. 写入 HP / score / round debug 日志
4. 判断 challenge 是否结束
5. 判断 set 是否结束
6. 若都未结束，则 `Turn + 1`
7. 调用 `_reset_turn_bet_state(false)`，把下一回合重新置为 `Pre-Bet`
8. 写入 `"Turn X begins."`
9. `_refresh_ui()`

### EndTurn 的显示规则
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 504-525 行

1. `EndTurn` 的显示由 `_refresh_bet_ui()` 控制
2. 只有满足 `bet_mode_enabled and _post_bet_window_open and not _challenge_over` 时才显示
3. 所以它不会在“尚未打出战斗牌”时出现
4. 它出现时只表示：
   - 本回合主行动已经完成
   - 当前仍处于 `Post-Bet` 可选窗口
   - 玩家现在可以继续用 1 张 `Post-Bet`，或者点 `EndTurn` 推进下一回合

## 六、Hold Steady 的真实职责
参考：[scripts/game/BetCard.gd](../../scripts/game/BetCard.gd) 第 86-100 行，以及 [scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 742-778 行

1. `Hold Steady` 定义为：
   - `id = hold_steady`
   - `base_cost = 0`
   - `timing_windows = [pre, post]`
2. 在 `_apply_single_bet_modifier()` 中，`HOLD_STEADY_ID` 分支直接 `return`
3. 这表示：
   - 它是普通 bet 卡
   - 它不会增加或回退伤害
   - 它不会触发回合推进
   - 它不会承担主行动提交职责

## 七、`_apply_round_result()` 的当前职责
参考：[scripts/ui/Main.gd](../../scripts/ui/Main.gd) 第 780-801 行

1. 缓存 `_current_round_result`
2. 标记玩家与 Boss 已用牌槽位
3. 立即应用主结算伤害
4. 写入主结算日志
5. 应用 `status_changes`
6. `ClashAreaView.show_clash(...)`
7. `_show_round_feedback(result)`，显示现有 `TurnResultPopup`
8. `_refresh_ui()`

注意：  
当前 turn 的推进不在 `_apply_round_result()` 内完成。  
当 bet mode 开启且本轮未终局时，主结算后会停留在 `Post-Bet`，等待 `EndTurn`。

## 八、`_refresh_ui()` 与当前可见性规则
`_refresh_ui()` 是主链路的刷新中枢，负责：

1. 更新 `RoundLabel / TurnLabel`
2. 更新 `PlayerHP / BossHP`
3. 更新 `PlayerBOD / PlayerSPR / PlayerREP`
4. 更新 `BossBOD / BossSPR / BossREP`
5. 刷新玩家手牌可点击状态
6. 刷新 Boss 剩余手牌
7. 刷新 BossBattleDeck 5 槽位状态
8. 调用 `_refresh_bet_ui()`，刷新：
   - `PlayerBetArea`
   - `BossBetArea`
   - `BetPhaseHint`
   - `BetResultHint`
   - `EndTurn`
9. 调用 `_sync_reveal_battle_deck_layout()`
10. 刷新 overlay 日志

需要注意的是：  
当前仓库中 `BossBetArea` 并不是固定隐藏，而是由 `bet_mode_enabled` 控制。  
`EndTurn` 也不是固定可见，而是严格跟随 `_post_bet_window_open`。

## 九、场景节点基线
当前场景已经包含本轮需求所需节点，无需新增 UI：

- [scenes/main/Main.tscn](../../scenes/main/Main.tscn) 中已存在 `TurnResultPopup`
- [scenes/main/Main.tscn](../../scenes/main/Main.tscn) 中已存在 `TurnResultPopup/FeedbackLabel`
- [scenes/main/Main.tscn](../../scenes/main/Main.tscn) 中已存在 `EndTurn`

## 十、测试与验收入口
### 关键 smoke 测试
参考：[tests/smoke_runner.gd](../../tests/smoke_runner.gd)

- 第 369 行起：`_test_main_mvp_pre_bet_selection_still_allows_battle_card()`
  - 验证 `Pre-Bet` 后仍可立即点击战斗牌
  - 验证主行动立即结算并进入 `Post-Bet`
  - 验证 `TurnResultPopup` 与 `EndTurn` 立即出现

- 第 430 行起：`_test_main_mvp_post_bet_end_turn()`
  - 验证点击战斗牌后立即进入 `Post-Bet`
  - 验证主行动已完成，但 turn 不会前进
  - 验证点击 `EndTurn` 后才进入下一回合

- 第 482 行起：`_test_main_mvp_post_bet_card_then_end_turn()`
  - 验证 `Post-Bet` 卡会立即生效
  - 验证 `Post-Bet` 卡本身不会结束回合
  - 验证仍需 `EndTurn` 才推进下一回合

- 第 553 行起：`_test_main_mvp_with_bets()`
  - 验证 `Hold Steady` 仍作为普通 `Post-Bet` 卡存在
  - 验证使用 `Hold Steady` 后 `EndTurn` 仍保持可见
  - 验证 `Hold Steady` 不再单独结束回合

### 复跑命令
```powershell
<GODOT_EXE> --headless --log-file <PROJECT_ROOT>/tests/out/smoke_tmp.log --path <PROJECT_ROOT> --script res://tests/smoke_runner.gd
```

### 当前验收结论
预期结果为 `SMOKE OK`。  
本仓库当前基线已经满足以下验收项：

1. 不点任何 bet，直接点击战斗牌，会立刻发生出牌、手牌减少、Boss 出牌、主结算与 `TurnResultPopup` 展示。
2. 主结算完成后会进入 `Post-Bet`，此时 `EndTurn` 显示。
3. 玩家此时既可以点一张 `Post-Bet`，也可以直接点 `EndTurn`。
4. 点击 `EndTurn` 后，本回合结束、进入下一回合、`EndTurn` 隐藏。
5. `Hold Steady` 不再承担结束回合功能，只是普通 0 费 bet 卡。

## 十一、定位主流程时该先看哪里
### 想查“点击战斗牌后发生了什么”
先看：

- `PlayerHandView._on_card_pressed()`
- `Main._on_card_play_requested()`
- `BattleResolver.resolve_round()`
- `Main._apply_round_result()`
- `Main._open_post_bet_window()`
- `Main._on_end_turn_pressed()`

### 想查“为什么 EndTurn 现在才显示”
先看：

- `Main._refresh_bet_ui()`
- `Main._post_bet_window_open`
- `Main._finalize_current_turn()`

### 想查“为什么 Hold Steady 不再结束回合”
先看：

- `BetCard._blueprint_hold_steady()`
- `Main._apply_single_bet_modifier()`
- `Main._on_end_turn_pressed()`

## 当前调用链的关键结论
1. 当前主链路的实际回合控制集中在 `MvpMainController`，不存在第二套隐藏状态机。
2. “点击战斗牌立即结算主行动”已经是当前仓库的真实行为，不是待实现目标。
3. `Post-Bet` 仍然完整保留，但它发生在主行动之后，而不是主行动之前的确认步骤。
4. `EndTurn` 的职责已经被限定为“结束 Post-Bet 并推进下一回合”。
5. `Hold Steady` 已经退回到普通 bet 卡语义，不承担提交或结束回合职责。
