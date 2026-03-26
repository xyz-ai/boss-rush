# Scene Structure

## 模块范围
本文件描述项目当前主要场景结构，重点回答：
- 当前主场景长什么样
- 哪些节点是编辑器静态节点
- 哪些 UI 内容是运行时动态生成
- 并行的 BattleScene 路径长什么样

## 当前主场景：`scenes/main/Main.tscn`

## 场景职责
- 这是当前项目实际运行的主场景
- 它提供主舞台壳子和主要 UI 区域
- 战斗数据和动态卡牌内容不直接写死在场景里，而是由 `scripts/ui/Main.gd` 驱动子视图生成

## 当前主场景树
### `Main`
- 类型：`Control`
- 作用：整个 MVP 界面的根节点

### `Background`
- 类型：`TextureRect`
- 作用：全屏背景贴图
- 控制方式：编辑器静态节点

### `ContentRoot`
- 类型：`Control`
- 作用：主 UI 壳子
- 控制方式：编辑器静态节点

### `ContentRoot/BossArea`
- 作用：Boss 区域外壳
- 子节点：`BossPortrait`
- 控制方式：编辑器静态节点

### `ContentRoot/TableArea`
- 作用：桌面主舞台
- 关键子节点：
  - `TableBoard`
  - `CenterInfo`
  - `PlayerHP`
  - `BossHP`
  - `ClashArea`
  - `BossDeckView`
  - `PlayerArea`
- 控制方式：编辑器静态节点

### `ContentRoot/TableArea/CenterInfo`
- 作用：显示回合/轮次文本
- 子节点：
  - `RoundLabel`
  - `TurnLabel`
- 控制方式：编辑器静态节点，文本由脚本刷新

### `ContentRoot/TableArea/ClashArea`
- 作用：中央对撞区壳子
- 子节点：
  - `PlayerCardSlot`
  - `BossCardSlot`
- 控制方式：
  - Slot 本身由编辑器布局控制
  - Slot 内显示的卡牌由 `ClashAreaView.gd` 动态生成

### `ContentRoot/TableArea/BossDeckView`
- 作用：Boss 牌列壳子
- 子节点：
  - `RevealDeckButton`
  - `DeckRow`
- 控制方式：
  - 外壳和按钮位置由编辑器控制
  - `DeckRow` 里的牌由 `BossDeckView.gd` 动态生成

### `ContentRoot/TableArea/PlayerArea`
- 作用：玩家手牌区壳子
- 子节点：
  - `HandAnchor`
- 控制方式：
  - 玩家手牌区位置由编辑器控制
  - `HandAnchor` 里的牌由 `PlayerHandView.gd` 动态生成

### `ContentRoot/OverlayUI`
- 作用：运行时日志覆盖层容器
- 控制方式：
  - 容器本身由编辑器控制
  - 具体的 `RuntimeLogLabel` 在运行时由 `scripts/ui/Main.gd` 动态创建

### `ScreenEffects`
- 作用：全屏崩坏/抖动/去饱和表现
- 控制方式：
  - 节点本身是静态实例
  - 效果偏移由 `scenes/ui/ScreenEffects.gd` 在运行时驱动

## 当前主场景中“编辑器静态节点”与“运行时动态内容”的边界
## 编辑器静态节点
这些节点是布局壳子，位置和大小应优先由编辑器控制：
- `Background`
- `ContentRoot`
- `BossArea`
- `BossPortrait`
- `TableArea`
- `TableBoard`
- `CenterInfo`
- `RoundLabel`
- `TurnLabel`
- `PlayerHP`
- `BossHP`
- `ClashArea`
- `PlayerCardSlot`
- `BossCardSlot`
- `BossDeckView`
- `RevealDeckButton`
- `DeckRow`
- `PlayerArea`
- `HandAnchor`
- `OverlayUI`
- `ScreenEffects`

## 运行时动态生成的内容
这些不是编辑器里固定摆好的内容：
- 玩家手牌卡片：挂到 `HandAnchor`
- Boss 牌列卡片：挂到 `DeckRow`
- 中央对撞区卡片：挂到 `PlayerCardSlot / BossCardSlot`
- 覆盖层日志 `RuntimeLogLabel`：挂到 `OverlayUI`

## 当前主场景的职责划分
### 场景壳子负责
- 空间分区
- 静态贴图和容器
- Label/Button/Slot 的基础存在

### `scripts/ui/Main.gd` 负责
- 找到这些节点
- 初始化手牌、Boss 牌列、中央对撞区控制器
- 刷新文本和动态内容
- 推进回合/局/挑战

### 子视图负责
- `PlayerHandView.gd`：玩家手牌内容
- `BossDeckView.gd`：Boss 牌列内容
- `ClashAreaView.gd`：中央对撞内容

## 并行场景：`scenes/battle/BattleScene.tscn`

## 当前使用状态
- 当前不是 `project.godot` 的主场景
- 但测试脚本会实例化它
- 它仍然是项目中一条有效但并行的链路

## 场景职责
- 更完整、更数据驱动的战斗表现层
- 含 Boss 区、桌面主舞台、左右抽屉、玩家手牌区、结果弹窗、Tooltip
- 与 `scripts/core/`、`scripts/data/`、`scripts/systems/` 联动

## 关键结构
### 背景层
- `BackgroundLayer`
- `BgOffice`
- `DeskTable`
- `VignetteOverlay`
- `DustOrCrackOverlay`

### 主舞台
- `SafeArea/StageRoot`
- `BossStage`
- `TableCore`
- `PlayerHandStage`
- `LeftStatusStage`
- `RightDrawer`

### 关键子场景
- `StatusPanel`
- `BossPanel`
- `BossDeckView`
- `ClashAreaView`
- `AddonPanel`
- `ResultPopup`
- `TooltipPanel`

## 这个并行场景的特点
- 它自身的静态壳子更复杂
- 同时还包含大量运行时几何控制和动态内容生成
- 不适合作为“当前主场景布局控制”的文档主线，但必须记录为并行路径

## 其他与场景相关的 UI
### `scenes/ui/ScreenEffects.tscn`
- 当前主链路和并行 BattleScene 链路都可能用到
- 重点是全局特效，不是主业务 UI

### `scenes/ui/TooltipPanel.tscn`
- 通用 Tooltip 场景
- 通过 `SignalBus` 驱动
- 运行时跟随鼠标位置，不是静态布局元素

### `scenes/shop/ShopScene.tscn`
- 当前不在主战斗场景里直接使用
- 属于并行的完整流程链路一部分

