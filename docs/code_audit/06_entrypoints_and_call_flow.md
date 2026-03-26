# Entrypoints and Call Flow

## 模块范围
本文件按“启动后实际发生什么”的顺序，说明：
- 当前项目入口
- 当前主链路如何初始化
- 玩家点击出牌后如何推进
- 并行 BattleScene 链路的入口是什么

## 当前主链路入口

## 第 1 步：项目启动
- 文件：`project.godot`
- 关键配置：
  - `run/main_scene="uid://botjw7r3wvlpd"`
  - Autoload：
    - `SignalBus`
    - `DataLoader`
    - `GameRun`

## 第 2 步：加载主场景
- 场景：`res://scenes/main/Main.tscn`
- 这个场景只是静态舞台壳子

## 第 3 步：Main 场景把控制权交给控制器
- 文件：`res://scenes/main/Main.gd`
- 调用链：
  1. `_ready()`
  2. `MAIN_CONTROLLER_SCRIPT.new(self)`
  3. `_controller.ready()`

## 当前主链路初始化流程

### 第 4 步：`scripts/ui/Main.gd::ready()`
按当前代码，初始化顺序是：
1. `_bind_nodes()`
2. `_setup_views()`
3. `_ensure_overlay_log()`
4. 可选：`_screen_effects.bind_target(_content_root)`
5. `_start_new_challenge()`

### 第 5 步：绑定静态节点
`_bind_nodes()` 从 `Main.tscn` 取得：
- Background
- ContentRoot
- BossArea / BossPortrait
- TableArea / TableBoard
- CenterInfo / RoundLabel / TurnLabel
- PlayerHP / BossHP
- OverlayUI
- HandAnchor
- BossDeckView / RevealDeckButton / DeckRow
- ClashArea / PlayerCardSlot / BossCardSlot
- PlayerArea
- ScreenEffects

### 第 6 步：创建子视图控制器
`_setup_views()` 创建：
- `MvpPlayerHandView`
- `MvpBossDeckView`
- `MvpClashAreaView`

这三个对象分别接管动态内容生成。

### 第 7 步：创建运行时日志
`_ensure_overlay_log()` 会：
- `RichTextLabel.new()`
- 加到 `OverlayUI`

### 第 8 步：开始挑战
`_start_new_challenge()` 会：
1. 清空日志和比分
2. 构造 `_player_state`
3. 构造 `_boss_state`
4. 设置双方长期状态 `BOD / SPR / REP = 3`
5. 调用 `_reset_for_current_set()`
6. 记录初始日志
7. 调用 `_refresh_ui()`

## 当前主链路出牌流程

### 第 9 步：刷新 UI
`_refresh_ui()` 做的事情：
1. 刷新 `RoundLabel / TurnLabel`
2. 刷新 `PlayerHP / BossHP`
3. 调用 `PlayerHandView.set_hand(...)`
4. 调用 `BossDeckView.set_deck(...)`
5. 调用 `BossDeckView.set_reveal_enabled(...)`
6. 刷新 overlay 日志文本

### 第 10 步：玩家点击手牌
触发链路：
1. `CardView.pressed`
2. `PlayerHandView._on_card_pressed(slot_index)`
3. `card_play_requested.emit(slot_index)`
4. `MvpMainController._on_card_play_requested(slot_index)`

### 第 11 步：Boss 自动选牌
在 `_on_card_play_requested()` 里：
1. 读取玩家卡
2. 调用 `_boss_ai.choose_slot(_boss_state, player_card)`
3. 锁输入 `_input_locked = true`
4. 调用 `_resolver.resolve_round(...)`

### 第 12 步：应用回合结果
`_apply_round_result(result)`：
1. 标记双方 slot 为已用
2. 扣双方 HP
3. 写入状态变化
4. 调用 `_clash_area_view.show_clash(...)`
5. 写日志
6. 打印调试输出
7. 判定挑战崩溃 / set 结束 / 挑战结束 / 下一回合

### 第 13 步：推进下一回合或下一局
如果当前 set 没结束：
- `Turn + 1`
- 解除输入锁
- `push_log("Turn X begins.")`
- `_refresh_ui()`

如果当前 set 结束：
- `_finish_set(set_winner)`
- 更新比分
- 如果有人先赢 2 局或打满 3 局，进入 `_finish_challenge()`
- 否则新 set 重置：
  - HP
  - used_slots
  - reveal 状态
  - 当前 turn
  - ClashArea

## 当前主链路 Reveal Deck 流程
1. `RevealDeckButton.pressed`
2. `MvpBossDeckView._on_reveal_pressed()`
3. `reveal_requested.emit()`
4. `MvpMainController._on_reveal_requested()`
5. `_boss_revealed = true`
6. `push_log("Boss deck revealed...")`
7. `_refresh_ui()`

## 当前主链路中谁决定最终显示
### 静态壳子
- `Main.tscn`

### 动态内容
- `scripts/ui/Main.gd`
- `scripts/ui/PlayerHandView.gd`
- `scripts/ui/BossDeckView.gd`
- `scripts/ui/ClashAreaView.gd`

### 战斗计算
- `scripts/game/BossAI.gd`
- `scripts/game/BattleResolver.gd`
- `scripts/game/CombatActorState.gd`

## 并行 BattleScene 链路入口

虽然不是当前主入口，但它是另一条有效调用链。

### 入口链
1. `GameRun.start_new_run()`
2. `GameRun.enter_boss()`
3. `SignalBus.emit_signal("screen_requested", SCREEN_BATTLE, {"boss": boss_def})`
4. 某个壳层切到 `scenes/battle/BattleScene.tscn`
5. `BattleScene.bind_context(run_state, boss_def)`
6. `BattleScene._setup_scene()`

### 该链路特点
- 由 `GameRun / RunState / SetState / ChallengeState / DataLoader` 驱动
- 数据来自 JSON
- BattleScene 自己绑定并刷新完整 UI
- 这条链路更接近未来正式架构，但当前不是 `project.godot` 的直接 main_scene

