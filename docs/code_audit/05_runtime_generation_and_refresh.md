# Runtime Generation and Refresh

## 模块范围
本文件专门整理当前主链路中“运行时生成、刷新、重建、重置”的代码路径。

重点回答：

- 哪些节点只是静态壳子
- 哪些内容是运行时生成
- 哪些刷新发生在初始化、每局、每回合
- Reveal、used 灰掉、Boss 剩余手牌数、ClashArea 等是怎么刷新的
- 当前是否存在状态残留或重复生成风险

## 静态壳子 vs 动态内容
### 静态壳子
由 `Main.tscn` 直接提供：
- `PlayerArea/HandAnchor`
- `BossDeckView/DeckRow`
- `BossBattleDeckView/BattleDeckRow`
- `ClashArea/BossCardSlot`
- `ClashArea/PlayerCardSlot`
- `OverlayUI`

### 动态内容
在运行时创建：
- 玩家手牌 `CardView`
- Boss 剩余手牌暗卡
- BossBattleDeck 的 5 张槽位卡
- ClashArea 双方当前牌
- 运行时日志 `RichTextLabel`

## 初始化时会发生什么
### 入口
- `scenes/main/Main.gd._ready()`
- 创建 `MvpMainController`
- 调用 `controller.ready()`

### `MvpMainController.ready()`
会依次执行：
1. `_bind_nodes()`
2. `_configure_mouse_filters()`
3. `_setup_views()`
4. `_sync_reveal_battle_deck_layout()`
5. `_ensure_overlay_log()`
6. `ScreenEffects.bind_target(_content_root)`
7. `_start_new_challenge()`

### 初始化时动态生成的内容
- `OverlayUI` 下的 `RuntimeLogLabel`
- 玩家初始 5 张手牌
- Boss 剩余手牌 5 张 hidden 卡
- BossBattleDeck 5 张 hidden 信息牌
- 初始 clash 文案

## 每局重置时会发生什么
### 入口
- `MvpMainController._reset_for_current_set()`

### 每局重置的内容
- 玩家 deck blueprint 重置为固定 `2-1-2`
- Boss 随机选取一套固定模板
- 玩家和 Boss 的 `hp` 重置为 `SET_HP`
- 玩家和 Boss 的 `cards` 按 blueprint 重建
- `used_slots` 清空
- `_boss_battle_revealed = false`
- `_current_turn_index = 1`
- `_input_locked = false`
- `ClashArea.clear_clash()`

### 每局不重置的内容
- `_player_set_wins`
- `_boss_set_wins`
- 玩家 `bod / spr / rep`
- Boss `bod / spr / rep`

这说明当前主链路里的长期状态是 **跨 set 持续** 的。

## 每回合刷新时会发生什么
### 出牌流程后刷新
玩家点击手牌后，controller 顺序是：
1. `BossAI.choose_slot()`
2. `BattleResolver.resolve_round()`
3. `_apply_round_result(result)`
4. 标记双方 used slot
5. 应用 HP 变化
6. 应用状态变化
7. `ClashArea.show_clash(...)`
8. 判定 collapse / set finish / challenge finish
9. 若本局未结束，`_current_turn_index += 1`
10. `_refresh_ui()`

### `_refresh_ui()` 当前会刷新什么
- 回合标签
- HP 标签
- 状态标签
- `BossBattleDeckView` 标题和按钮状态
- 玩家手牌视图
- BossDeckView 剩余手牌视图
- BossBattleDeckView 五槽位状态
- overlay 日志

## 具体到各个视图的重建机制
### `PlayerHandView`
- `set_hand(cards, used_slots, interactive)`
- 先 `_clear_cards()`
- 再为每个未使用槽位重新 `instantiate()` 一张 `CardView`
- 风险：
  - 每次刷新都会全量重建
  - 好处是逻辑简单，不容易残留旧卡

### `BossDeckView`
- `set_hand(cards, used_slots)`
- 按剩余数量重建 `DeckRow`
- 不保留旧 children
- 只显示剩余数量对应的 hidden 卡

### `BossBattleDeckView`
- `set_deck(cards, revealed, used_slots)`
- 每次写入内部状态后 `_rebuild_cards()`
- 永远重建完整 5 槽位
- 通过 `used_slots` 控制灰掉
- 通过 `revealed` 控制 hidden/normal
- 不删除槽位

### `ClashAreaView`
- `show_clash(player_card, boss_card, summary_text)`
- 每次都清空旧 slot 内容，再创建当前回合卡牌
- `clear_clash()` 会在新局开始时清空并恢复默认文案

### Overlay 日志
- `RichTextLabel` 只创建一次
- 之后通过 `_refresh_overlay_log()` 改 `.text`
- 不是每次重建控件

## Reveal 的刷新链
### 触发
- `RevealBattleDeckButton.pressed`
- `BossBattleDeckView._on_reveal_pressed()`
- `reveal_requested.emit()`
- `Main._on_reveal_requested()`

### 写回
- `_boss_battle_revealed = true`

### 刷新
- `_refresh_ui()`
- `BossBattleDeckView.set_deck(cards, true, used_slots)`
- 5 张牌从 hidden 变成 normal / used

### 重置
- `_reset_for_current_set()` 中把 `_boss_battle_revealed` 设回 `false`

## Boss 剩余手牌数的刷新链
### 数据源
- `_boss_state.used_slots`

### 刷新方式
- `_refresh_ui()`
- `BossDeckView.set_hand(_boss_state.cards, _boss_state.used_slots)`
- `remaining_cards = cards.size - used_slots.size`
- `DeckRow` 重建为对应数量的 hidden 卡

## 已使用灰掉的刷新链
### 数据源
- `_boss_state.used_slots`

### 刷新方式
- `_refresh_ui()`
- `BossBattleDeckView.set_deck(cards, revealed, used_slots)`
- `_state_for_slot(slot_index)` 返回：
  - `used`
  - `normal`
  - `hidden`

## 当前刷新机制的优点
- 单点入口清晰，基本都从 `_refresh_ui()` 收敛。
- 通过重建而不是复杂 diff，降低了状态残留概率。
- Reveal、剩余手牌数、中央对撞区这几个 MVP 核心信息流都容易追踪。

## 当前刷新机制的风险
### 1. 重建多于更新
玩家手牌、BossDeck、BossBattleDeck、ClashArea 都倾向于全清再建。  
当前数据量小问题不大，但以后若引入更多状态和动画，会成为约束。

### 2. Controller 刷新责任偏重
`Main.gd` 不只是调视图，还决定 reveal、set 重置、turn 推进、日志写入和布局同步调用。  
这会让“是状态问题还是视图问题”变得不那么容易分离。

### 3. 仍存在局部运行时布局同步
`_sync_reveal_battle_deck_layout()` 仍会调用 `BossBattleDeckView.update_layout()`。  
它当前只调 `BattleDeckRow`，但这是少数仍在运行时参与几何的路径。

### 4. `ScreenEffects` 会改 `ContentRoot.position`
这不是重建问题，但会让“为什么运行时位置和编辑器不同”这类排查变复杂。

## 结论
当前主链路刷新机制整体是清楚的：  
**初始化建壳子，运行时按 set 和 turn 重建局部内容，主控制器统一刷新。**

它的最大优点是简单、可验证；最大风险是 controller 过重和重建式刷新会越来越难承载复杂表现。
