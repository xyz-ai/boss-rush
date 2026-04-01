# Risk Points and Dev Notes

## 模块范围
本文件只记录 **当前代码最值得警惕的结构问题、技术债和开发建议**。

目标不是列所有可优化点，而是帮助后续开发者判断：

- 哪些地方最容易误改
- 哪些地方最容易出现 UI 与逻辑不同步
- 哪些看起来能优化，但在 MVP 阶段不该先动

## 当前最主要的风险点
### 1. 主链路与并行链路并存，极易误判
当前仓库至少有两条可运行的战斗路径：

- 主链路：`Main.tscn + scripts/ui + scripts/game`
- 并行链路：`BattleScene + scripts/core + scripts/data + scripts/systems`

风险：
- 改了并行链路，不一定会影响当前玩家启动看到的内容
- 改了主链路，也不一定能让所有 smoke 通过，因为 smoke 还会实例化并行 BattleScene

建议：
- 开始改动前先判断自己在改哪条链
- 先看 [08_parallel_paths_and_usage_status.md](./08_parallel_paths_and_usage_status.md)

### 2. `scripts/ui/Main.gd` 过重
当前 `MvpMainController` 同时承担：
- 节点绑定
- 视图刷新
- set / challenge 初始化
- 玩家出牌入口
- Boss 选牌调用
- 结算结果应用
- set / challenge 推进
- 日志写入

风险：
- 这个文件改动范围大，容易引入回归
- UI 问题和战斗问题会混在一起

建议：
- 当前阶段不要盲目拆分，只在功能明确时做局部整理
- 任何改动都应先看 `_refresh_ui()`、`_on_card_play_requested()`、`_apply_round_result()`、`_reset_for_current_set()`

### 3. `BossDeckView` 与 `BossBattleDeckView` 很容易被混淆
当前两者职责已经不同：

- `BossDeckView`
  - 表现层
  - 显示 Boss 手里还剩几张
  - 出一张少一张
- `BossBattleDeckView`
  - 信息层
  - 显示固定 5 张本局对战牌池
  - reveal 后看真实牌
  - 已使用槽位灰掉但不删除

风险：
- 如果把 reveal 或 fixed 5-slot 逻辑再塞回 `BossDeckView`，会直接破坏当前玩法表达

建议：
- 任何涉及 Boss 牌区的修改，先明确自己在改表现层还是信息层

### 4. `ScreenEffects` 仍会直接改 `ContentRoot.position`
[ScreenEffects.gd](../../scenes/ui/ScreenEffects.gd) 不是纯视觉 overlay，它会在 `_process()` 中持续写 `_target.position`。

风险：
- 运行时 UI 位置偏移时，容易误以为是主布局坏了
- 也会影响“编辑器改了位置为什么运行时不完全一样”的判断

建议：
- 排查 UI 几何问题时先暂时考虑 `ScreenEffects` 的影响
- 但在当前 MVP 阶段，不建议优先重写它

### 5. 主场景布局主要交给编辑器，但局部仍有运行时布局逻辑
当前主链路已经不再由 `scripts/ui/Main.gd` 全面控制大布局，但仍存在局部几何逻辑：

- `BossBattleDeckView.update_layout()` 会调整 `BattleDeckRow`
- `ClashAreaView` 会把动态卡牌居中到 slot
- `ScreenEffects` 会偏移 `ContentRoot`

风险：
- 很容易再次回到“编辑器改了，运行时又被局部覆盖”的状态

建议：
- 当前阶段继续坚持“主场景几何由编辑器控制，局部内容由 view 摆放”
- 不要重新把整套主布局搬回 controller

### 6. 主链路牌系统已经极简化，容易被旧文档或旧思路误导
当前主链路牌系统已经只有 3 类：

- Aggression
- Defense
- Pressure

风险：
- 如果按照旧 `tag / base_power / 变体名 / JSON 数据牌库` 理解主链路，会看错代码

建议：
- 主链路开发时优先看 `scripts/game/BattleCard.gd`
- 只有在明确要切回正式数据驱动方向时，才去看 `scripts/core + DataLoader`

### 7. 测试覆盖了两套系统，定位失败原因时容易跑偏
[tests/smoke_runner.gd](../../tests/smoke_runner.gd) 会同时：
- 测主链路 `Main.tscn`
- 测并行链路 `BattleScene.tscn`
- 测 core/data/systems 逻辑

风险：
- smoke fail 不代表当前玩家可见主链路一定坏了
- 也不代表只修主链路就能让 smoke 通过

建议：
- 看失败点时先分清是 `Main.tscn` 断言还是 `BattleScene/core` 断言

## 当前最容易误改的文件
### 首位
- [scripts/ui/Main.gd](../../scripts/ui/Main.gd)

### 第二层
- [scripts/game/BattleResolver.gd](../../scripts/game/BattleResolver.gd)
- [scripts/game/BossAI.gd](../../scripts/game/BossAI.gd)
- [scripts/ui/BossBattleDeckView.gd](../../scripts/ui/BossBattleDeckView.gd)
- [scripts/ui/CardView.gd](../../scripts/ui/CardView.gd)

### 容易被低估但会影响很多的文件
- [scenes/main/Main.tscn](../../scenes/main/Main.tscn)
- [scenes/ui/ScreenEffects.gd](../../scenes/ui/ScreenEffects.gd)

## 哪些地方以后适合重构，但当前阶段不应先动
### 适合以后重构
- 把 set / challenge 状态从 `MvpMainController` 中继续拆出去
- 减少 `_refresh_ui()` 的全量重建
- 把主链路牌模板切到数据层
- 统一主链路与并行链路，避免双系统长期并存

### 当前阶段不应先动
- 不要先把主链路强行切回 `scripts/core/*`
- 不要为了“更优雅”把 `Main.gd` 大拆分
- 不要先引入更复杂的卡牌数值和额外标签
- 不要先重做 `Main.tscn` 的整体 UI 结构

## 对当前 MVP 目标最有帮助的开发建议
1. 继续围绕主链路验证信息推理价值，不要急着扩内容。
2. 所有新需求都先判断是“表现层”还是“信息层”。
3. 遇到 UI 不一致问题，先看刷新链和运行时生成，而不是先怀疑场景资源坏了。
4. 遇到测试失败，先区分主链路失败还是并行链路失败。
5. 在当前阶段，优先保证：
   - reveal 可用
   - fixed 5-slot 信息牌池可读
   - Boss 剩余手牌数和 clash 结果联动正确

## 当前阶段建议保持不动的事实
- `BossDeckView` 与 `BossBattleDeckView` 双系统职责分离
- 3 类牌模型
- `Main.tscn` 作为当前主入口
- `scripts/ui/Main.gd` 作为当前 MVP 总调度器

这些都不是最优终局结构，但对于当前验证目标是有效且可工作的。
