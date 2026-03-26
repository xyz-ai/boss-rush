# Runtime Generation and Refresh

## 模块范围
本文件只整理一类问题：
- 哪些内容是运行时动态生成
- 谁触发生成
- 是否会清空重建
- 哪些节点只是编辑器静态壳子

这份文档是后续排查“为什么编辑器里改了，运行却不是这样”的关键索引。

## 当前主链路：`Main.tscn + scripts/ui/*`

## 静态壳子
这些节点存在于 `Main.tscn`，作为运行时内容的容器：
- `ContentRoot`
- `BossArea`
- `TableArea`
- `CenterInfo`
- `ClashArea`
- `PlayerCardSlot`
- `BossCardSlot`
- `BossDeckView`
- `DeckRow`
- `PlayerArea`
- `HandAnchor`
- `OverlayUI`

这些节点本身由编辑器定义，不是运行时创建的。

## 动态生成：玩家手牌
### 文件
- `res://scripts/ui/PlayerHandView.gd`

### 触发入口
- `MvpMainController._refresh_ui()`
- 调用：`_player_hand_view.set_hand(...)`

### 生成过程
1. `set_hand()` 调用 `_clear_cards()`
2. `_clear_cards()` 遍历 `HandAnchor` 现有子节点
3. 对每个子节点执行 `queue_free()`
4. 再次遍历当前可用手牌
5. `instantiate()` `scenes/ui/CardView.tscn`
6. `add_child()` 到 `HandAnchor`

### 结论
- `HandAnchor` 是静态壳子
- 玩家手牌卡本体是运行时内容
- 编辑器里手工摆在 `HandAnchor` 里的卡不会是最终运行结果

## 动态生成：Boss 牌列
### 文件
- `res://scripts/ui/BossDeckView.gd`

### 触发入口
- `MvpMainController._refresh_ui()`
- 调用：`_boss_deck_view.set_deck(...)`

### 生成过程
1. `set_deck()` 保存 cards/revealed/used_slots
2. `_rebuild_cards()` 遍历 `DeckRow` 子节点
3. 对每个子节点执行 `queue_free()`
4. 按 slot 数量 `instantiate()` `CardView`
5. 根据 slot 状态配置为 `hidden / normal / used`
6. `add_child()` 到 `DeckRow`

### 结论
- `BossDeckView` 和 `DeckRow` 是静态壳子
- 牌列中的每一张 Boss 卡是运行时重建
- 编辑器里直接手改 `DeckRow` 里动态卡的内容没有意义

## 动态生成：中央 ClashArea
### 文件
- `res://scripts/ui/ClashAreaView.gd`

### 触发入口
- `MvpMainController._apply_round_result()`
- 调用：`_clash_area_view.show_clash(...)`

### 生成过程
1. `_place_card()` 先清空目标 slot
2. `_clear_slot()` 遍历 slot 子节点并 `queue_free()`
3. `instantiate()` `CardView`
4. `add_child()` 到 `PlayerCardSlot` 或 `BossCardSlot`
5. 直接设置该卡在 slot 内的 anchor/offset，使其居中

### 额外动态节点
- `ClashAreaView._init()` 中还会 `Label.new()` 创建 `ResultLabel`

### 结论
- `ClashArea`、`PlayerCardSlot`、`BossCardSlot` 是静态壳子
- slot 内卡片和结果 Label 是运行时内容
- 它仍会对子卡做局部定位，但不负责主舞台区块布局

## 动态生成：Overlay 日志
### 文件
- `res://scripts/ui/Main.gd`

### 触发入口
- `ready() -> _ensure_overlay_log()`

### 生成过程
1. `RichTextLabel.new()`
2. 设置 anchor/offset/full rect
3. `add_child()` 到 `OverlayUI`

### 结论
- `OverlayUI` 是静态壳子
- `RuntimeLogLabel` 是运行时动态创建

## 当前主链路中“运行时刷新”而不是“运行时生成”的部分
- `RoundLabel.text`
- `TurnLabel.text`
- `PlayerHP.text`
- `BossHP.text`
- `RevealDeckButton.text / disabled`
- ScreenEffects profile

这些不会重建节点，但会反复改节点内容。

## 当前主链路中仍然会改位置的地方
### 局部，不影响主舞台块
- `scripts/ui/ClashAreaView.gd`
  - 对动态生成的 clash 卡片设置 anchor/offset
  - 作用域只在 slot 内部

### 全局视觉特效，不作为主布局系统
- `scenes/ui/ScreenEffects.gd`
  - 在 `_process()` 中把绑定目标写成 `_base_position + offset`
  - 会造成抖动或下沉

### Tooltip 局部位置
- `scenes/ui/TooltipPanel.gd`
  - 运行时写 `global_position`

## 并行 BattleScene 链路中的运行时生成

这套链路当前不是主入口，但测试仍会实例化它。

### `scenes/battle/BattleScene.gd`
- `_build_player_cards()`：
  - 清空 `CardRow`
  - `instantiate()` `scenes/battle/CardView.tscn`
  - `add_child()` 到 `CardRow`
- `_refresh_chip_stacks()`：
  - 清空 `PlayerChipStacks / BossChipStacks`
  - 运行时构建筹码控件
- `_build_chip_metric()`：
  - `Control.new() / Label.new() / PanelContainer.new()` 等多层运行时构建

### `scenes/battle/BossDeckView.gd`
- 每次 `refresh_from_state()` 会清空并重建整行对手牌列
- 使用 `Control.new()`、`TextureRect.new()`、`Label.new()` 拼出每张卡

### `scenes/battle/AddonPanel.gd`
- `_rebuild()` 会重建每条加注项 UI
- 使用 `PanelContainer.new()`、`MarginContainer.new()`、`VBoxContainer.new()`、`Button.new()` 等

### `scenes/shop/ShopScene.gd`
- `_rebuild_items()` 会清空 `ItemRow` 后实例化 `ShopItemView`

## 谁触发重建
## 当前主链路
- `Main.gd -> MvpMainController._refresh_ui()`

## 并行 BattleScene 链路
- `BattleScene.gd._refresh_ui()`
- 某些场合还会由结果弹窗继续、下一局开始、窥牌、加注再次触发

## 调试结论
如果某个 UI 改动在编辑器里有效、运行时却“不见了”，先判断它属于哪一类：

### 如果它是静态壳子
看是否被脚本改了 geometry 或文本。

### 如果它是动态内容
看生成脚本：
- `PlayerHandView.gd`
- `BossDeckView.gd`
- `ClashAreaView.gd`
- 并行链路中的 `BattleScene.gd` / `AddonPanel.gd` / `BossDeckView.gd`

动态内容在运行时会清空重建，编辑器里直接手改动态子节点通常不会保留。

