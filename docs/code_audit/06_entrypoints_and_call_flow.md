# Entrypoints and Call Flow

## 模块范围
本文件梳理当前项目主链路的入口与调用流。  
重点覆盖：

- 从项目启动到进入主战斗界面
- 从点击玩家出牌到 Boss 出牌、结算、刷新 UI
- 从一局结束到下一局开始
- 从 reveal 操作到 BossBattleDeckView 刷新的过程

## 一、项目启动链路
### 启动入口
1. [project.godot](../../project.godot) 指定主场景为 [scenes/main/Main.tscn](../../scenes/main/Main.tscn)
2. Godot 实例化 `Main.tscn`
3. [scenes/main/Main.gd](../../scenes/main/Main.gd) `_ready()` 执行
4. `Main.gd` 创建 [scripts/ui/Main.gd](../../scripts/ui/Main.gd) 中的 `MvpMainController`
5. `Main.gd` 调用 `controller.ready()`

### `MvpMainController.ready()` 调用顺序
1. `_bind_nodes()`
2. `_configure_mouse_filters()`
3. `_setup_views()`
4. `_sync_reveal_battle_deck_layout()`
5. `_ensure_overlay_log()`
6. `ScreenEffects.bind_target(_content_root)`
7. `_start_new_challenge()`

## 二、初始化战斗链路
### `_start_new_challenge()`
1. 清空日志
2. 重置比分与 controller 状态
3. 随机化 Boss 模板随机数生成器
4. 创建玩家 `MvpCombatActorState`
5. 创建 Boss `MvpCombatActorState`
6. 设置双方长期状态为 `BOD 3 / SPR 3 / REP 3`
7. 调用 `_reset_for_current_set()`
8. 写初始日志
9. 调用 `_refresh_ui()`

### `_reset_for_current_set()`
1. 玩家 deck blueprint 固定为 `Aggression / Aggression / Defense / Pressure / Pressure`
2. Boss 从 `template_a / template_b / template_c` 中随机选 1 套
3. 用 blueprint 重置双方本局牌组
4. 重置双方 HP 到 `SET_HP`
5. 清空 used slots
6. reveal 设回 `false`
7. `Turn` 设回 `1`
8. 清空 clash area

## 三、Reveal 链路
### 触发链
1. 玩家点击 `RevealBattleDeckButton`
2. [BossBattleDeckView.gd](../../scripts/ui/BossBattleDeckView.gd) `_on_reveal_pressed()`
3. `reveal_requested.emit()`
4. [scripts/ui/Main.gd](../../scripts/ui/Main.gd) `_on_reveal_requested()`

### 状态写回
1. 若挑战未结束且当前 set 尚未 reveal：
2. `_boss_battle_revealed = true`
3. 写一条日志
4. 调用 `_refresh_ui()`

### 视图刷新
1. `_boss_battle_deck_view.set_deck(_boss_state.cards, _boss_battle_revealed, _boss_state.used_slots)`
2. `BossBattleDeckView` 重建 5 张牌
3. 未使用槽位从 `hidden` 变成 `normal`
4. 已使用槽位保持 `used`

## 四、玩家出牌到回合结算链路
### 事件入口
1. 玩家点击玩家手牌中的 `CardView`
2. [PlayerHandView.gd](../../scripts/ui/PlayerHandView.gd) `_on_card_pressed(slot_index)`
3. `card_play_requested.emit(slot_index)`
4. [scripts/ui/Main.gd](../../scripts/ui/Main.gd) `_on_card_play_requested(slot_index)`

### 回合处理顺序
1. 检查：
   - `challenge_over`
   - `input_locked`
   - 槽位是否已使用
2. 读取玩家当前牌
3. `BossAI.choose_slot(_boss_state, player_card)` 选 Boss 槽位
4. 锁输入
5. `BattleResolver.resolve_round(...)` 计算结果
6. `_apply_round_result(result)`

## 五、结果应用链路
### `_apply_round_result(result)`
1. `mark_card_used()` 标记双方使用的槽位
2. `modify_hp()` 应用双方本回合伤害
3. 逐条写入 `log_lines`
4. 对 `status_changes` 调 `_apply_status_change()`
5. `ClashAreaView.show_clash(player_card, boss_card, summary_text)`
6. 记录当前 HP 和比分日志
7. `print` 调试输出
8. 依次判定：
   - 玩家长期状态是否崩溃
   - Boss 长期状态是否崩溃
   - 当前 set 是否结束
9. 若本局未结束：
   - `Turn + 1`
   - 解锁输入
   - 写日志
   - `_refresh_ui()`

### `_apply_status_change(change)`
1. 判断目标是 `player` 还是 `boss`
2. 调对应 `CombatActorState.modify_status()`
3. 写日志

## 六、一局结束到下一局开始
### `_is_set_finished()`
满足任意条件即结束当前 set：
- 玩家 HP <= 0
- Boss HP <= 0
- Turn 到达上限
- 玩家牌用尽
- Boss 牌用尽

### `_determine_set_winner()`
判定顺序：
1. 先看谁 HP 先归零
2. 再比较剩余 HP
3. 再比较 `REP`
4. 若还相同，Boss 胜

### `_finish_set(set_winner)`
1. 更新 set 胜场
2. 写日志
3. 若已达到挑战结束条件：
   - `_finish_challenge(...)`
4. 否则：
   - `current_set_index += 1`
   - `_reset_for_current_set()`
   - 写“新 set 开始”日志
   - `_refresh_ui()`

## 七、挑战结束链路
### `_finish_challenge(challenge_winner, reason)`
1. `_challenge_over = true`
2. `_input_locked = false`
3. 写结果日志和最终比分日志
4. `print` 一条 challenge ended
5. `_refresh_ui()`

### 当前表现
- 当前主链路没有单独的总结弹窗。
- 挑战结果主要通过日志和当前 UI 禁止继续交互来表现。

## 八、`_refresh_ui()` 是当前主链路的刷新中枢
每次调用会做这些事：
1. 更新 `RoundLabel / TurnLabel`
2. 更新 `PlayerHP / BossHP`
3. 更新 `PlayerBOD / PlayerSPR / PlayerREP`
4. 更新 `BossBOD / BossSPR / BossREP`
5. 固定 `BattleDeckTitle`
6. 隐藏 `BossBetArea`
7. 刷新玩家手牌
8. 刷新 Boss 剩余手牌
9. 刷新 BossBattleDeck 5 槽位状态
10. 调用 `_sync_reveal_battle_deck_layout()`
11. 刷新 overlay 日志

## 九、定位主流程时该先看哪里
### 想查“点击玩家牌后发生了什么”
先看：
- `PlayerHandView._on_card_pressed()`
- `Main._on_card_play_requested()`
- `BattleResolver.resolve_round()`
- `Main._apply_round_result()`

### 想查“Reveal 为什么不更新”
先看：
- `BossBattleDeckView._on_reveal_pressed()`
- `Main._on_reveal_requested()`
- `Main._refresh_ui()`
- `BossBattleDeckView.set_deck()`

### 想查“为什么新局会重置这些内容”
先看：
- `Main._finish_set()`
- `Main._reset_for_current_set()`

## 当前调用链的关键结论
1. 当前主链路调用流是清晰的，入口集中在 `MvpMainController`。
2. 玩家出牌、Boss 出牌、结算、刷新 UI 全部通过一条顺序逻辑完成，没有第二套隐藏回合控制器。
3. Reveal 的状态归属在 controller，不在 view。
4. set/challenge 的推进同样由 controller 持有，不在 `scripts/game/*` 里封装成独立状态机。
