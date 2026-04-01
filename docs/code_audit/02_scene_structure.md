# Scene Structure

## 模块范围
本文件梳理当前场景层级与节点职责，重点以当前启动入口 [scenes/main/Main.tscn](../../scenes/main/Main.tscn) 为准。

目标是回答：

- 主场景里哪些节点是静态壳子
- 哪些节点主要承载运行时动态内容
- `BossArea / TableArea / PlayerArea / OverlayUI / ScreenEffects` 各自做什么
- `TableArea` 内部现在如何分工

## 当前主场景：`scenes/main/Main.tscn`
### 顶层结构
`Main`
- `Background`
- `ContentRoot`
  - `BossArea`
  - `TableArea`
  - `OverlayUI`
- `ScreenEffects`

### 顶层职责
#### `Background`
- 类型：`TextureRect`
- 作用：整屏背景贴图。
- 性质：静态显示层。
- 备注：`mouse_filter = IGNORE`，不参与交互。

#### `ContentRoot`
- 类型：`Control`
- 作用：主视觉与交互节点的共同父节点。
- 性质：主 UI 壳层。
- 备注：`ScreenEffects` 会把它作为 target，在运行时轻微改动 `position`。

#### `ScreenEffects`
- 类型：实例化的 `scenes/ui/ScreenEffects.tscn`
- 作用：轻微抖动、去饱和、裂痕等视觉效果。
- 性质：效果层。
- 风险：会在 `_process()` 中改动绑定目标的位置，是当前主链路里少数仍会直接改几何的系统。

## `BossArea`
### 当前结构
`BossArea`
- `BossPortrait`

### 职责
- 表现 Boss 人物存在感。
- 现在只承载 Boss 剪影/立绘，不承载 Reveal 业务信息。
- 更偏背景与压迫感层，而不是信息层。

### 运行时特征
- 主要由编辑器场景决定位置。
- `scripts/ui/Main.gd` 不负责它的主布局，只绑定并读取节点。

## `TableArea`
`TableArea` 是当前主链路最重要的功能区域。它既承担桌面视觉，也承担主要战斗信息。

### 当前结构
`TableArea`
- `TableBoard`
- `CenterInfo`
  - `RoundLabel`
  - `SpacerLabel`
  - `TurnLabel`
- `BossBattleDeckView`
  - `BattleDeckTitle`
  - `RevealBattleDeckButton`
  - `BattleDeckRow`
- `BossDeckView`
  - `BossHandCountLabel`
  - `BossHandAnimationAnchor`
  - `DeckRow`
- `BossHP`
- `BossStatusPanel`
  - `MarginContainer`
    - `VBoxContainer`
      - `BossBOD`
      - `BossSPR`
      - `BossREP`
- `ClashArea`
  - `BossCardSlot`
  - `ClashResultLabel`
  - `PlayerCardSlot`
- `BossBetArea`
  - `BetAreaTitle`
  - `BetRow`
- `PlayerHP`
- `PlayerStatusPanel`
  - `MarginContainer`
    - `VBoxContainer`
      - `PlayerBOD`
      - `PlayerSPR`
      - `PlayerREP`
- `PlayerArea`
  - `HandAnchor`

### `TableBoard`
- 类型：`TextureRect`
- 作用：桌面底图。
- 性质：纯显示层。
- 备注：不承载交互，`mouse_filter = IGNORE`。

### `CenterInfo`
- 类型：`HBoxContainer`
- 作用：显示战斗节奏信息。
- 当前内容：
  - `RoundLabel`
  - `TurnLabel`
- 性质：信息层，但不负责按钮或 reveal。

### `BossBattleDeckView`
- 类型：`Control`
- 作用：**信息层**。
- 表示 Boss 本局固定 5 张对战牌池。
- Reveal 前显示 hidden。
- Reveal 后显示真实牌。
- 已使用槽位变灰，但不删除槽位。
- 这是当前主链路里“推理信息”的主要承载区。

### `BossDeckView`
- 类型：`Control`
- 作用：**表现层**。
- 表示 Boss 手里还剩几张牌。
- `DeckRow` 只显示剩余数量对应的暗卡，不表示 reveal 后的完整牌池。
- `BossHandAnimationAnchor` 当前只是未来动画占位。

### `BossHP` / `PlayerHP`
- 类型：`Label`
- 作用：显示本局 HP。
- 性质：信息层。
- 不负责长期状态。

### `BossStatusPanel` / `PlayerStatusPanel`
- 类型：`PanelContainer`
- 作用：显示长期状态 `BOD / SPR / REP`。
- 性质：信息层。
- 与 `HP` 分开，避免把所有数值堆在一个 Label 上。

### `ClashArea`
- 类型：`Control`
- 作用：中央当前出牌展示区。
- `BossCardSlot`：显示本回合 Boss 当前牌。
- `PlayerCardSlot`：显示本回合玩家当前牌。
- `ClashResultLabel`：显示一句结算摘要。
- 性质：每回合变化的强刷新区。

### `BossBetArea`
- 类型：`Control`
- 作用：未来 Boss 加注区占位。
- 当前状态：存在但默认隐藏/弱化，不承载逻辑。

### `PlayerArea`
- 类型：`Control`
- 作用：玩家手牌区壳子。
- `HandAnchor` 是运行时动态生成玩家手牌 `CardView` 的容器。

## `OverlayUI`
- 类型：`Control`
- 作用：承载运行时创建的日志 `RichTextLabel`。
- 性质：静态壳子 + 动态内容承载点。
- 备注：主日志文本不是场景里预放的，而是 `scripts/ui/Main.gd` 运行时 `RichTextLabel.new()` 创建的。

## 哪些节点是布局节点，哪些是功能节点
### 主要布局节点
- `ContentRoot`
- `BossArea`
- `TableArea`
- `PlayerArea`
- `BossBattleDeckView`
- `BossDeckView`
- `ClashArea`
- `PlayerStatusPanel`
- `BossStatusPanel`

### 主要功能节点
- `RevealBattleDeckButton`
- `BattleDeckRow`
- `DeckRow`
- `HandAnchor`
- `BossCardSlot`
- `PlayerCardSlot`
- `ClashResultLabel`
- `RoundLabel`
- `TurnLabel`

## 哪些内容是运行时动态生成的
### 静态壳子
由 `Main.tscn` 直接提供：
- `BossBattleDeckView`
- `BossDeckView`
- `ClashArea`
- `PlayerArea`
- `OverlayUI`
- `BossStatusPanel`
- `PlayerStatusPanel`

### 动态内容
以下内容在运行时生成或重建：
- `HandAnchor` 里的玩家手牌卡片
- `BossDeckView/DeckRow` 里的 Boss 剩余手牌暗卡
- `BossBattleDeckView/BattleDeckRow` 里的 5 张信息牌
- `ClashArea/BossCardSlot` 与 `PlayerCardSlot` 里的本回合对撞卡
- `OverlayUI` 里的运行时日志 `RichTextLabel`

## 当前场景层级的关键判断
1. `Main.tscn` 现在是编辑器主布局来源，不再由 `scripts/ui/Main.gd` 统一重排主舞台区块。
2. `TableArea` 是当前玩法信息的核心舞台。
3. `BossDeckView` 与 `BossBattleDeckView` 都在 `TableArea` 中，但职责不同：一个偏表现，一个偏推理信息。
4. `PlayerArea/HandAnchor`、`BattleDeckRow`、`DeckRow`、`ClashArea` 都是“静态壳子 + 动态内容”的典型组合。
