# UI Module Audit

## 模块范围
本文件审计以下内容：
- `scripts/ui/`
- `scenes/ui/`
- 当前 UI 强相关的 `scenes/main/Main.gd`
- 并行 BattleScene 路径中与 UI 表现直接相关的 `scenes/battle/*.gd`

重点不是列文件，而是说明：
- 谁负责节点绑定
- 谁负责刷新 UI
- 谁负责动态生成卡牌
- 谁负责 BossDeck 三态
- 谁负责中央对撞区
- 谁会影响 UI 表现

## 当前主 UI 链路

### 文件：`scenes/main/Main.gd`
- 路径：`res://scenes/main/Main.gd`
- 作用：主场景脚本的薄包装
- 主要负责：
  - 在 `_ready()` 中创建 `MvpMainController`
  - 把场景控制权转交给 `scripts/ui/Main.gd`
  - 转发 `_notification()`
- 影响范围：
  - 是当前主链路的入口桥接点
  - 自身不直接负责布局和战斗结算
- 依赖：
  - `res://scripts/ui/Main.gd`
- 注意事项：
  - 这里不是业务逻辑中心
  - 真正的主 UI 控制权在 `scripts/ui/Main.gd`

### 文件：`scripts/ui/Main.gd`
- 路径：`res://scripts/ui/Main.gd`
- 类名：`MvpMainController`
- 作用：当前 MVP 主 UI 控制器
- 主要负责：
  - 绑定 `Main.tscn` 中的节点
  - 初始化玩家/Boss 状态
  - 创建并管理 `PlayerHandView / BossDeckView / ClashAreaView`
  - 刷新文本和动态内容
  - 响应 reveal、出牌、回合推进、本局结束、挑战结束
  - 输出运行时日志
- 影响范围：
  - 当前主链路里最核心的 UI 组织者
  - 改它会同时影响：
    - 玩家手牌刷新
    - Boss 牌列刷新
    - 中央结算显示
    - HP / Round / Turn 文本
    - 日志输出
- 依赖：
  - `scripts/ui/PlayerHandView.gd`
  - `scripts/ui/BossDeckView.gd`
  - `scripts/ui/ClashAreaView.gd`
  - `scripts/game/*`
  - `scenes/ui/ScreenEffects.gd`
- 注意事项：
  - 当前主布局几何已经不应由它控制
  - 它现在应只负责绑定、刷新、流程推进
  - 它仍然会动态创建 Overlay 日志 Label

### 文件：`scripts/ui/PlayerHandView.gd`
- 路径：`res://scripts/ui/PlayerHandView.gd`
- 类名：`MvpPlayerHandView`
- 作用：玩家手牌内容生成器
- 主要负责：
  - 清空 `HandAnchor`
  - 实例化 `scenes/ui/CardView.tscn`
  - 绑定玩家点击信号
  - 根据已用 slot 隐藏已打出的牌
- 影响范围：
  - 只影响玩家手牌区域内容
  - 不影响主舞台块位置
- 依赖：
  - `scripts/ui/CardView.gd`
  - `scripts/game/BattleCard.gd`
- 注意事项：
  - 它会重建整行手牌
  - 如果你想在编辑器里手摆玩家卡，运行时不会保留

### 文件：`scripts/ui/BossDeckView.gd`
- 路径：`res://scripts/ui/BossDeckView.gd`
- 类名：`MvpBossDeckView`
- 作用：BossDeck 三态显示控制器
- 主要负责：
  - 管理 `RevealDeckButton`
  - 根据 `revealed / used_slots` 刷新牌列状态
  - 动态生成 Boss 牌列卡片
- 影响范围：
  - 只影响 `BossDeckView/DeckRow` 内容
  - 不影响 `BossDeckView` 外壳位置
- 依赖：
  - `scripts/ui/CardView.gd`
- 注意事项：
  - 这是当前主链路中 Boss 信息博弈最关键的 UI 组件
  - reveal 状态是“每局一次，持续到本局结束”

### 文件：`scripts/ui/ClashAreaView.gd`
- 路径：`res://scripts/ui/ClashAreaView.gd`
- 类名：`MvpClashAreaView`
- 作用：中央对撞区显示器
- 主要负责：
  - 在 `PlayerCardSlot / BossCardSlot` 中显示本回合双方牌
  - 动态创建 `ResultLabel`
  - 覆盖显示当前回合结算文字
- 影响范围：
  - 只影响中央对撞区内容
  - 不影响 `ClashArea` 主壳子位置
- 依赖：
  - `scripts/ui/CardView.gd`
- 注意事项：
  - 它会在 slot 内部直接居中生成卡片
  - 这是局部定位，不是主舞台布局控制

### 文件：`scripts/ui/CardView.gd`
- 路径：`res://scripts/ui/CardView.gd`
- 类名：`MvpCardView`
- 作用：当前 MVP 用的可点击卡片视图
- 主要负责：
  - 显示卡名、卡图、状态遮罩
  - 区分 `normal / hidden / used`
  - 决定按钮是否可点击
- 影响范围：
  - 同时用于玩家手牌和 BossDeck 卡片
- 依赖：
  - `scenes/ui/CardView.tscn`
- 注意事项：
  - 当前主链路实际使用的是这一套 `scenes/ui/CardView.tscn + scripts/ui/CardView.gd`
  - 不要和 `scenes/battle/CardView.tscn` 混淆

## 通用 UI 场景与脚本

### 文件：`scenes/ui/ScreenEffects.gd`
- 路径：`res://scenes/ui/ScreenEffects.gd`
- 作用：全局特效层
- 主要负责：
  - 绑定目标节点
  - 根据 effect profile 做轻微抖动、下沉、去饱和、裂痕显示
- 影响范围：
  - 会对被绑定目标写 `position`
  - 会影响整屏视觉感觉
- 依赖：
  - `SignalBus`
- 注意事项：
  - 它不是主布局系统
  - 但因为会在运行时偏移绑定目标，排查“为什么整体在晃”时必须看它

### 文件：`scenes/ui/TooltipPanel.gd`
- 路径：`res://scenes/ui/TooltipPanel.gd`
- 作用：通用 Tooltip
- 主要负责：
  - 监听 `SignalBus.tooltip_requested`
  - 跟随鼠标更新 `global_position`
- 影响范围：
  - 只影响 Tooltip
  - 不影响主舞台布局
- 注意事项：
  - 它属于典型“运行时位置驱动 UI”

## 并行 BattleScene UI 链路

### 文件：`scenes/battle/BattleScene.gd`
- 路径：`res://scenes/battle/BattleScene.gd`
- 作用：并行 BattleScene 的总控制器
- 当前主链路是否使用：否，当前不是 main_scene
- 主要负责：
  - 绑定 `BattleScene.tscn` 的所有节点
  - 刷新状态、BossPanel、BossDeckView、ClashArea、AddonPanel
  - 响应出牌、窥牌、加注、结果弹窗
  - 运行时布局 `_apply_stage_layout()`
- 影响范围：
  - 影响整个并行战斗界面
- 注意事项：
  - 这是并行链路里最复杂的 UI 文件
  - 它仍然包含主舞台运行时几何控制

### 文件：`scenes/battle/BossPanel.gd`
- 作用：Boss 摘要、状态、查看牌池按钮
- 当前主链路是否使用：否
- 影响范围：
  - 只影响并行 BattleScene 的 Boss 信息面板

### 文件：`scenes/battle/BossDeckView.gd`
- 作用：并行 BattleScene 中的 Boss 牌列展示
- 当前主链路是否使用：否
- 主要负责：
  - 根据 `boss_revealed` 和 `boss_used_cards` 动态生成对手牌列
  - 使用真实 frame/back/overlay 贴图
- 影响范围：
  - 并行 BattleScene 的对手牌列

### 文件：`scenes/battle/ClashAreaView.gd`
- 作用：并行 BattleScene 的中央结算区
- 当前主链路是否使用：否
- 主要负责：
  - 显示上一回合双方卡牌摘要和伤害结果

### 文件：`scenes/battle/StatusPanel.gd`
- 作用：挑战比分、POS、临时状态摘要
- 当前主链路是否使用：否

### 文件：`scenes/battle/AddonPanel.gd`
- 作用：加注牌区
- 当前主链路是否使用：否
- 主要负责：
  - 运行时重建加注列表行

### 文件：`scenes/battle/ResultPopup.gd`
- 作用：并行 BattleScene 的回合/局/挑战结果弹窗
- 当前主链路是否使用：否

## UI 模块的当前职责边界
## 负责节点绑定
- 当前主链路：`scripts/ui/Main.gd`
- 并行链路：`scenes/battle/BattleScene.gd`

## 负责刷新 UI
- 当前主链路：`scripts/ui/Main.gd`
- 并行链路：`scenes/battle/BattleScene.gd`

## 负责动态生成卡牌
- 当前主链路：
  - `scripts/ui/PlayerHandView.gd`
  - `scripts/ui/BossDeckView.gd`
  - `scripts/ui/ClashAreaView.gd`
- 并行链路：
  - `scenes/battle/BattleScene.gd`
  - `scenes/battle/BossDeckView.gd`

## 负责 BossDeck 三态
- 当前主链路：`scripts/ui/BossDeckView.gd`
- 并行链路：`scenes/battle/BossDeckView.gd`

## 负责中央对撞区
- 当前主链路：`scripts/ui/ClashAreaView.gd`
- 并行链路：`scenes/battle/ClashAreaView.gd`

## 负责日志 / Tooltip / ScreenEffects
- 当前主链路日志：`scripts/ui/Main.gd` 动态创建的 `RuntimeLogLabel`
- 并行链路日志：`scenes/battle/BattleScene.gd` 内部 LogPanel / RichTextLabel
- Tooltip：`scenes/ui/TooltipPanel.gd`
- ScreenEffects：`scenes/ui/ScreenEffects.gd`

## 风险与注意事项
- 当前项目里存在两套卡牌 UI：
  - `scenes/ui/CardView.tscn` 对应 MVP 主链路
  - `scenes/battle/CardView.tscn` 对应并行 BattleScene 链路
- 当前项目里存在两套 BossDeckView：
  - `scripts/ui/BossDeckView.gd`
  - `scenes/battle/BossDeckView.gd`
- 当前项目里存在两套 BattleResolver / BossAI：
  - `scripts/game/*`
  - `scripts/core/*`
- 继续开发前，必须先确认要改的是哪套 UI

