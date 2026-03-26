# Risk Points and Dev Notes

## 模块范围
本文件总结当前项目最容易继续踩坑的点，并给出只作为建议的后续开发方向。

本文件不改代码，只归纳风险。

## 风险 1：两套战斗/UI 链路并存

### 现象
当前项目同时存在：
- 当前主链路：
  - `scenes/main/Main.tscn`
  - `scripts/ui/*`
  - `scripts/game/*`
- 并行链路：
  - `scenes/battle/BattleScene.tscn`
  - `scripts/core/*`
  - `scripts/data/*`
  - `scripts/systems/*`

### 风险
- 很容易改错路径
- 很容易把一个问题在两套系统里各修一遍
- 很容易以为“代码没生效”，其实只是改到了未被当前主入口使用的那一套

### 建议
- 每次改动前先确认目标是：
  - 当前主入口 MVP 路径
  - 还是并行 BattleScene 数据驱动路径

## 风险 2：主链路和数据驱动链路的数据来源不一致

### 现象
- 当前主链路卡牌来自 `scripts/game/BattleCard.gd` 的硬编码测试数据
- 并行链路卡牌来自 `DataLoader` 读取的 JSON

### 风险
- 改 JSON 后，当前主入口看起来“没变化”
- 改 `BattleCard.gd` 后，并行 BattleScene 看起来“没变化”

### 建议
- 在文档和开发任务里始终写清楚“改的是硬编码 MVP 数据，还是改 JSON 数据驱动数据”

## 风险 3：动态 UI 生成会覆盖编辑器对子内容的手工修改

### 现象
- 玩家手牌、BossDeck、ClashArea 卡片都在运行时实例化
- Overlay 日志也在运行时创建

### 风险
- 在编辑器里直接调整这些动态子节点通常不会反映到运行结果
- 排查 UI 问题时容易把“容器壳子”和“运行时内容”混淆

### 建议
- 改布局时先判断自己改的是：
  - 静态壳子节点
  - 还是运行时生成的内容模板/脚本

## 风险 4：ScreenEffects 仍会在运行时偏移整体内容

### 现象
- `scenes/ui/ScreenEffects.gd` 会对 bind 的目标写 `position`

### 风险
- 容易误判为布局漂移
- 做截图对比时可能觉得节点位置“不稳定”

### 建议
- 如果排查布局问题，先临时关掉或忽略 `ScreenEffects` 的偏移影响
- 它当前属于视觉层，不应被当作主布局控制器

## 风险 5：并行 BattleScene 仍包含运行时主布局控制

### 现象
- `scenes/battle/BattleScene.gd` 仍然有 `_apply_stage_layout()` 和 `_pin_rect()`

### 风险
- 如果有人去改 `BattleScene.tscn` 的主几何，再运行 BattleScene，很可能发现编辑器位置被脚本覆盖
- 当前主入口已经解决了“编辑器布局优先”的问题，但并行 BattleScene 还没有

### 建议
- 对 BattleScene 做布局修改前，先明确那套运行时布局逻辑还在
- 不要把主入口 `Main.tscn` 的经验直接套用到并行 BattleScene

## 风险 6：测试脚本会同时触发两套链路

### 现象
- `tests/smoke_runner.gd` 既测试 `Main.tscn`
- 也测试 `BattleScene.tscn`

### 风险
- 你可能只改了当前主入口，但 smoke 仍然因为并行链路失败
- 也可能你只修了并行链路，但当前主入口体验仍有问题

### 建议
- 测试失败时先看失败断言落在哪一段
- 不要默认所有失败都来自当前主入口

## 风险 7：当前主链路控制器职责较多

### 现象
`scripts/ui/Main.gd` 同时负责：
- 节点绑定
- 初始化
- 流程推进
- UI 刷新
- 日志维护
- 局/挑战推进

### 风险
- 任何改动都可能影响多个方面
- 继续堆功能会让它越来越像“总管脚本”

### 建议
- 继续开发时尽量维持当前边界：
  - `Main.gd` 负责 orchestration
  - 子视图负责内容生成
  - 逻辑脚本负责纯计算
- 不要再把更多视觉布局控制塞回 `scripts/ui/Main.gd`

## 风险 8：命名相似文件很多，容易误判

### 典型冲突
- `scripts/ui/CardView.gd` vs `scenes/battle/CardView.gd`
- `scripts/ui/BossDeckView.gd` vs `scenes/battle/BossDeckView.gd`
- `scripts/game/BattleResolver.gd` vs `scripts/core/BattleResolver.gd`
- `scripts/game/BossAI.gd` vs `scripts/core/BossAI.gd`

### 风险
- 开发时打开错文件
- 修了但主链路不生效

### 建议
- 每次开工先用“当前主链路 / 并行链路”来分类文件，而不是只看文件名

## 后续开发建议

## 建议 1：先固定“哪条链路继续主开发”
- 如果短期目标是继续做可玩 MVP：
  - 优先沿当前 `Main.tscn + scripts/ui + scripts/game` 走
- 如果短期目标是恢复数据驱动和正式流程：
  - 优先沿 `BattleScene + scripts/core/data/systems` 走

## 建议 2：动态生成问题排查优先看 `05_runtime_generation_and_refresh.md`
- 这是最容易踩坑的现实问题
- 先确认自己改的是壳子还是内容

## 建议 3：保留当前“编辑器布局优先”的控制权
- 当前主入口已经不应再由 `scripts/ui/Main.gd` 重写主舞台几何
- 后续不要把旧的 runtime layout 逻辑又塞回来

## 建议 4：如果继续走双链路并存，必须显式标注“当前主用”
- 文档、任务、PR、提交信息都应写清楚目标链路

