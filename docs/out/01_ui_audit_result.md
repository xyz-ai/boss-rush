# UI 审计结果

## 当前 UI 结构优点
- 主场景壳层次已经稳定：`Main.tscn` 中 `PlayerArea`、`BossArea`、`ClashArea`、`TurnResultPopup`、`EndTurn` 的职责比旧版更清楚。
- 新 UI 主体结构有效：
  - `PlayerArea/CardViewport` 承载玩家 Battle/Bet/Summary
  - `BossArea/BossCardViewport` 承载 Boss Battle/Bet/Summary
  - `ClashArea` 承载中央对撞卡牌与中心提示
  - `TurnResultPopup` 承载结算播报
- 结果播报与中心提示已经完成一轮职责拆分：
  - `TurnResultPopup` 负责瞬时播报
  - `ClashResultLabel` 负责中心常驻引导
  - `BetPhaseHint` / `BetResultHint` 负责 bet 状态提示
  - runtime summary panel 负责长期信息
- `scripts/ui/Main.gd:507` 起的运行时 popup 子节点、`_ensure_summary_labels()` 生成的 runtime summary panel，说明项目已经接受“少量运行时 UI 节点补充”的模式，这对后续微调是有利的。

## 当前 UI 结构风险

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_bind_nodes():261`，`_setup_views():738`，`_refresh_ui():1040`
- 风险等级：高
- 问题说明：
  同一个脚本同时承担节点绑定、运行时子节点创建、显示模式切换、结果弹层配置和刷新调度。
- 影响范围：
  几乎所有主战斗 UI。
- 最小修复建议：
  先在 `Main.gd` 内部按职责切成更小 helper，再考虑进一步下沉。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_bind_nodes():293-349`
- 风险等级：中
- 问题说明：
  仍保留旧 UI 路径兼容，如 `PlayerBetArea`、`BossBetArea`、`BossDeckView`、`PeekBossBetButton`。
- 影响范围：
  节点绑定、场景重命名、UI 改版后的清理工作。
- 最小修复建议：
  明确“当前正式结构”和“过渡兼容结构”的淘汰节点清单，减少旧路径继续扩散。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_bind_nodes():368-403`
- 风险等级：高
- 问题说明：
  `_bind_nodes()` 的 required 集合仍然偏大，很多显示层节点一旦缺失就会直接 assert。
- 影响范围：
  UI 改版协作、场景编辑器调整。
- 最小修复建议：
  下轮先按“主流程必须 / 可选显示 / 兼容残留”三类重新划分。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_current_center_guidance_text():848`，`show_turn_result_popup():867`，`_refresh_bet_ui():1070`，`_refresh_summary_texts():606`
- 风险等级：中
- 问题说明：
  Popup、CenterInfo、Bet hints、Summary 的职责虽然分开了，但规则仍靠主控手工协调，没有一个更小的 UI policy 层。
- 影响范围：
  文字显示冲突、Result Mode 回归、后续 UI 微调。
- 最小修复建议：
  抽出统一的文本 ownership helper，减少多个入口分别改 label 的机会。

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_ensure_turn_result_popup_nodes():507`
- 风险等级：中
- 问题说明：
  Result Mode 的 `RuntimeResultBackdrop` 和 `RuntimeResultHeadlineLabel` 是运行时创建的，场景编辑器中不可见。
- 影响范围：
  UI 设计协作、场景编辑时的误判。
- 最小修复建议：
  至少在文档中明确这些运行时节点存在；若后续 UI 稳定，再决定是否回写到场景。

## 节点绑定问题

### 高风险热点
- `scripts/ui/Main.gd:296-301`
  玩家 Bet 面板仍兼容旧路径 `ContentRoot/TableArea/PlayerBetArea`
- `scripts/ui/Main.gd:327-337`
  Boss Bet 面板与旧 `PeekBossBetButton` 仍残留兼容
- `scripts/ui/Main.gd:346-349`
  `BossDeckView` 兼容路径仍在，说明旧剩余手牌视图尚未完全退场
- `scripts/ui/Main.gd:368-403`
  主场景大量节点为硬依赖 assert

### 判断
- 当前节点绑定已经比旧版稳，但还没完全切到“新 UI 单一真相源”。
- 下一轮不建议继续扩大候选路径数组；应该开始缩。

## 信息显示职责冲突

### 当前已经解决的部分
- `TurnResultPopup` 与 `ClashResultLabel` 已经不再写同一份详细战报。
- Result Mode 期间中心提示、Bet 提示会让位给 popup。
- Summary 已经与 popup 分开，不再复用同一块中央文本。

### 仍需记录的风险

### 问题标题
- 文件：`scripts/ui/Main.gd`
- 位置：`_refresh_ui():1040`，`_refresh_bet_ui():1070`，`_refresh_summary_texts():606`
- 风险等级：中
- 问题说明：
  文本职责虽然拆开，但所有刷新仍由 `_refresh_ui()` 串行驱动，后续新需求很容易再次把不同文本写回同一层。
- 影响范围：
  结果播报、中心引导、Bet 提示、Summary。
- 最小修复建议：
  把“结果播报”“中心引导”“bet 提示”“summary”明确定义为 4 条独立刷新路径，并在文档中固定约束。

## 后续 UI 层建议
1. 先把 `Main.gd` 内的 UI policy 进一步分段，不急着拆成新系统。
2. 收敛旧路径兼容，不要再让新改动继续依赖历史节点名。
3. 缩小 `_bind_nodes()` 的硬依赖集合，避免 UI 小改动直接阻断运行。
4. 对 runtime UI 节点补一份显式说明，避免场景编辑误判“节点不存在”。
5. 在 smoke 中继续保留“popup / 中心提示 / Result Mode”相关断言，因为这是最容易回归的显示层。

