# UI Module Audit

## 模块范围
本文件审查当前主链路相关 UI 脚本与 UI 场景，重点覆盖：

- [scripts/ui/Main.gd](../../scripts/ui/Main.gd)
- [scripts/ui/PlayerHandView.gd](../../scripts/ui/PlayerHandView.gd)
- [scripts/ui/BossDeckView.gd](../../scripts/ui/BossDeckView.gd)
- [scripts/ui/BossBattleDeckView.gd](../../scripts/ui/BossBattleDeckView.gd)
- [scripts/ui/ClashAreaView.gd](../../scripts/ui/ClashAreaView.gd)
- [scripts/ui/CardView.gd](../../scripts/ui/CardView.gd)
- [scenes/ui/ScreenEffects.gd](../../scenes/ui/ScreenEffects.gd)

## UI 模块总体职责划分
当前主链路 UI 不是纯视图层。它有明显的三层结构：

1. **主场景壳子**
   - `Main.tscn`
   - 负责节点存在、编辑器布局、静态层级

2. **主控制器**
   - `scripts/ui/Main.gd`
   - 负责绑定节点、驱动战斗流程、调度各视图刷新

3. **子视图**
   - `PlayerHandView`
   - `BossDeckView`
   - `BossBattleDeckView`
   - `ClashAreaView`
   - `CardView`

这种结构的好处是 MVP 推进快，问题也很明显：主控制器承担了较多 UI 编排责任。

## 核心文件说明
### `scripts/ui/Main.gd`
- 路径：[scripts/ui/Main.gd](../../scripts/ui/Main.gd)
- 作用：当前主链路的实际 UI 控制器和主流程 orchestrator。
- 主要负责：
  - `_bind_nodes()`：读取 `Main.tscn` 所有关键节点
  - `_configure_mouse_filters()`：设置被动显示节点不拦截点击
  - `_setup_views()`：实例化各个视图 helper
  - `_start_new_challenge()` / `_reset_for_current_set()`：初始化战斗与每局重置
  - `_refresh_ui()`：统一刷新标签、牌列、clash、日志
  - `_on_reveal_requested()`：处理 reveal 状态写回
  - `_on_card_play_requested()`：玩家点牌后的主流程入口
  - `_apply_round_result()` / `_finish_set()` / `_finish_challenge()`：推进回合、局和挑战
- 影响范围：
  - 几乎所有主链路 UI 都由它刷新
  - 战斗流程也由它驱动
- 依赖：
  - `scripts/game/*`
  - `scripts/ui/*`
  - `ScreenEffects`
- 注意事项：
  - 这是当前主链路里最容易被误改的文件。
  - 它已经同时承担 UI orchestration 和部分 game flow，职责偏重。

### `scripts/ui/PlayerHandView.gd`
- 路径：[scripts/ui/PlayerHandView.gd](../../scripts/ui/PlayerHandView.gd)
- 作用：玩家手牌视图生成器。
- 主要负责：
  - 根据 `cards + used_slots` 重建 `HandAnchor`
  - 为每张未使用牌创建 `CardView`
  - 向上发 `card_play_requested(slot_index)`
- 影响范围：
  - 只影响玩家手牌区
- 依赖：
  - `CardView`
  - `MvpBattleCard.to_dict()`
- 注意事项：
  - 每次 `set_hand()` 都会全清再重建，不是局部更新。
  - 这是 MVP 阶段可接受的实现，但会增加刷新频率下的重建成本。

### `scripts/ui/BossDeckView.gd`
- 路径：[scripts/ui/BossDeckView.gd](../../scripts/ui/BossDeckView.gd)
- 作用：Boss 剩余手牌表现层。
- 主要负责：
  - `Boss Hand xN` 文案
  - `DeckRow` 里显示剩余数量对应的 hidden 卡背
- 不负责：
  - reveal
  - 本局固定 5 张信息牌池
  - 已使用灰掉的固定槽位逻辑
- 影响范围：
  - Boss 剩余手牌表现
- 注意事项：
  - 它当前职责已经和 `BossBattleDeckView` 明确分开，后续不要再混回去。

### `scripts/ui/BossBattleDeckView.gd`
- 路径：[scripts/ui/BossBattleDeckView.gd](../../scripts/ui/BossBattleDeckView.gd)
- 作用：Boss 本局 5 张对战牌池的信息层视图。
- 主要负责：
  - `RevealBattleDeckButton` 信号出口
  - `BattleDeckRow` 的 5 槽位重建
  - hidden / normal / used 三态展示
  - reveal 按钮禁用/文案状态
- 不负责：
  - reveal 状态最终归属
  - 挑战级或 set 级战斗状态持有
- 影响范围：
  - Boss 信息推理区
- 注意事项：
  - reveal 真正的状态源不在这个 view 内，而在 `MvpMainController._boss_battle_revealed`。
  - 这个 view 目前还带有 `update_layout()`，虽然只处理 `BattleDeckRow` 局部布局，但依然是局部几何控制点。

### `scripts/ui/ClashAreaView.gd`
- 路径：[scripts/ui/ClashAreaView.gd](../../scripts/ui/ClashAreaView.gd)
- 作用：中央当前出牌和结果展示区。
- 主要负责：
  - 在 `BossCardSlot` 和 `PlayerCardSlot` 中创建并居中显示当前牌
  - 更新 `ClashResultLabel`
  - 新回合或新局时清空 clash
- 影响范围：
  - 中央对撞区
- 注意事项：
  - 它不保存任何战斗状态，只展示最新结果。
  - slot 内卡牌是运行时创建的，不是编辑器静态节点。

### `scripts/ui/CardView.gd`
- 路径：[scripts/ui/CardView.gd](../../scripts/ui/CardView.gd)
- 作用：主链路通用卡牌显示控件。
- 主要负责：
  - 正常态、hidden、used 三态显示
  - 3 类牌的标题、颜色和贴图映射
  - 可点击控制
- 当前卡牌显示模型：
  - 只认 `type`
  - 标题只显示 `Aggression / Defense / Pressure`
  - 不再读取旧 `tag / base_power / 变体名`
- 影响范围：
  - 玩家手牌
  - BossDeckView 卡背
  - BossBattleDeckView 五槽位
  - ClashArea 当前牌

### `scenes/ui/ScreenEffects.gd`
- 路径：[scenes/ui/ScreenEffects.gd](../../scenes/ui/ScreenEffects.gd)
- 作用：轻量视觉效果层。
- 主要负责：
  - 绑定 `ContentRoot`
  - 根据 profile 对目标做轻微位移
  - 更新去饱和与裂痕 overlay
- 影响范围：
  - 会影响整个主 UI 的视觉位置
- 注意事项：
  - 它虽然是“效果层”，但会写 `_target.position`，这意味着它不是纯视觉不侵入。

## 信息层与表现层的区分
### 表现层
- `BossDeckView`
- `BossPortrait`
- `ScreenEffects`
- `Background / TableBoard`

### 信息层
- `BossBattleDeckView`
- `CenterInfo`
- `PlayerHP / BossHP`
- `PlayerStatusPanel / BossStatusPanel`
- `ClashArea`
- `OverlayUI` 运行时日志

## 当前 UI 刷新方式
### 优点
- 入口清晰：几乎所有刷新都收敛到 `MvpMainController._refresh_ui()`
- 每个子视图职责相对单一
- Reveal、已使用灰掉、剩余手牌数这些效果都能从单点状态推导出来

### 隐患
- `_refresh_ui()` 集中刷新过多内容，未来容易继续膨胀
- 一些视图采用“全清空重建”的方式，简单但不够细粒度
- `ScreenEffects` 仍会直接改 `ContentRoot.position`
- `BossBattleDeckView.update_layout()` 仍保留局部几何控制，后续若场景改布局要注意同步

## 是否存在 UI 层吞业务逻辑过多的问题
存在，但目前可控。

### 已经明显集中在 UI 控制器里的业务
- 挑战初始化
- set 重置
- reveal 状态持有
- 玩家出牌后 Boss 选牌
- 结算结果应用到 actor state
- set / challenge 的结束判定与推进

### 仍然保留在 gameplay 层的逻辑
- 牌模板定义
- actor 状态容器
- Boss 选牌决策
- 回合结算公式

### 结论
当前 `scripts/ui/Main.gd` 不是纯 UI 控制器，而是 **MVP 的总调度器**。这对当前阶段是快的，但未来如果继续扩功能，它会成为最先变重的文件。
