# Gameplay Module Audit

## 模块范围
本文件审计两套战斗逻辑：
- 当前主链路：`scripts/game/`
- 并行数据驱动链路：`scripts/core/`、`scripts/data/`、`scripts/systems/`

目标是说明：
- 每个脚本负责什么
- 输入输出是什么
- 是否依赖 UI
- 当前主链路是否实际使用

## 当前主链路：`scripts/game/`

### 文件：`scripts/game/BattleCard.gd`
- 路径：`res://scripts/game/BattleCard.gd`
- 类名：`MvpBattleCard`
- 作用：MVP 测试卡牌定义
- 主要负责：
  - 定义玩家 5 张测试牌
  - 定义 Boss 5 张测试牌
  - 提供 `build_player_test_deck()` 和 `build_boss_test_deck()`
- 输入输出：
  - 输入：硬编码常量
  - 输出：`Array[MvpBattleCard]`
- 是否依赖 UI：否
- 当前主链路是否使用：是
- 注意事项：
  - 它不是数据驱动
  - 当前主链路仍然使用这套硬编码牌组，而不是 JSON

### 文件：`scripts/game/CombatActorState.gd`
- 路径：`res://scripts/game/CombatActorState.gd`
- 类名：`MvpCombatActorState`
- 作用：当前 MVP 玩家/Boss 状态容器
- 主要负责：
  - 保存 `hp / bod / spr / rep`
  - 保存当前 set 的 cards 和 used_slots
  - 提供 `mark_card_used()`、`modify_hp()`、`modify_status()`、`is_collapsed()`
- 输入输出：
  - 输入：测试卡牌列表和起始状态
  - 输出：可变 actor 状态
- 是否依赖 UI：否
- 当前主链路是否使用：是
- 注意事项：
  - 这是当前 MVP 的状态真源
  - UI 只是读取这个状态

### 文件：`scripts/game/BossAI.gd`
- 路径：`res://scripts/game/BossAI.gd`
- 类名：`MvpBossAI`
- 作用：当前 MVP Boss 出牌选择器
- 主要负责：
  - 根据玩家当前牌的 tag，把 Boss 剩余牌分成 `counter / neutral / wrong`
  - 以 `50 / 30 / 20` 权重选择 slot
- 输入输出：
  - 输入：`boss_state`、`player_card`
  - 输出：Boss 选中的 slot index
- 是否依赖 UI：否
- 当前主链路是否使用：是
- 注意事项：
  - 它不是随机抽牌系统
  - 它是当前 MVP 信息博弈体验的重要组成部分

### 文件：`scripts/game/BattleResolver.gd`
- 路径：`res://scripts/game/BattleResolver.gd`
- 类名：`MvpBattleResolver`
- 作用：当前 MVP 单回合结算器
- 主要负责：
  - 读取玩家牌和 Boss 牌
  - 计算克制修正
  - 应用 `SPR <= 1` 的威力减值
  - 应用 `BOD <= 1` 的额外承伤
  - 决定双方伤害和长期状态变化
  - 返回日志、summary、damage、winner
- 输入输出：
  - 输入：`player_state`、`boss_state`、双方 slot
  - 输出：一个包含伤害、卡牌、summary、status_changes 的 `Dictionary`
- 是否依赖 UI：否
- 当前主链路是否使用：是
- 注意事项：
  - 它不直接推进 set/challenge，只负责一回合结果
  - set/challenge 推进仍由 `scripts/ui/Main.gd` 决定

## 并行数据驱动链路：`scripts/core/`

### 文件：`scripts/core/GameRun.gd`
- 路径：`res://scripts/core/GameRun.gd`
- 作用：并行完整 Run 流程的全局控制器
- 主要负责：
  - 启动一局 Run
  - 进入 Boss
  - 打开商店
  - 结束总结
  - 维护 `logging_system` 和 `shop_generator`
- 是否依赖 UI：间接依赖
- 当前主链路是否使用：Autoload 存在，但不是当前 `Main.tscn` 战斗链路的直接控制器
- 注意事项：
  - 并行 BattleScene 链路会依赖它
  - 当前 smoke 也会走到它

### 文件：`scripts/core/RunState.gd`
- 作用：并行链路的总状态对象
- 主要负责：
  - 保存玩家长期状态：`pos / bod / spr / rep / life`
  - 保存 Boss 长期状态：`boss_bod / boss_spr / boss_rep`
  - 持有 `challenge_state / current_set_state`
  - 提供 `begin_challenge()`、`start_set()`、`consume_battle_card()`、`finish_set()`
- 是否依赖 UI：否
- 当前主链路是否使用：否
- 注意事项：
  - 这是并行正式链路的中心状态对象
  - 当前主 MVP 没有使用它，而是自己维护 `MvpCombatActorState`

### 文件：`scripts/core/ChallengeState.gd`
- 作用：记录挑战级状态
- 主要负责：
  - `current_set_index`
  - `player_set_wins / boss_set_wins`
  - `remaining_addons`
  - `equipped_battle_loadout`
- 当前主链路是否使用：否

### 文件：`scripts/core/SetState.gd`
- 作用：记录局内状态
- 主要负责：
  - `round_index`
  - `player_hp / boss_hp`
  - `remaining_player_battle_cards`
  - `remaining_boss_battle_cards`
  - `boss_deck / boss_used_cards / boss_revealed`
  - `next_bonus / next_penalty / cover`
- 当前主链路是否使用：否
- 注意事项：
  - 它已经包含 BossDeck 三态所需的正式状态字段

### 文件：`scripts/core/BossAI.gd`
- 作用：并行链路的 Boss 选牌器
- 主要负责：
  - 使用 `DataLoader` 和 `MatchupRules`
  - 从剩余 Boss 牌中按 `counter / neutral / wrong` 选牌
- 当前主链路是否使用：否

### 文件：`scripts/core/BattleResolver.gd`
- 作用：并行链路的正式回合结算器
- 主要负责：
  - 读取 JSON 卡牌定义
  - 处理长期状态成本
  - 处理 `Next / Cover / Addon / POS`
  - 推进 set 和 challenge
  - 生成完整 result snapshot
- 当前主链路是否使用：否
- 注意事项：
  - 它比 `scripts/game/BattleResolver.gd` 更完整
  - 但当前 main_scene 并未接这套 resolver

### 文件：`scripts/core/MatchupRules.gd`
- 作用：封装 family 克制关系
- 当前主链路是否使用：仅并行链路和测试使用

### 文件：`scripts/core/ShopGenerator.gd`
- 作用：生成并应用商店 offer
- 当前主链路是否使用：否

### 文件：`scripts/core/SaveManager.gd`
- 作用：存档接口占位
- 当前主链路是否使用：否，当前是辅助/预留文件

## 数据加载层：`scripts/data/`

### 文件：`scripts/data/DataLoader.gd`
- 作用：JSON 数据总加载器，Autoload
- 主要负责：
  - 读取 battle/addon/boss cards
  - 读取 boss 定义
  - 读取 matchup/ui thresholds/starting values/challenge rules/loadouts/shop pool
  - 向其他系统提供查询接口
- 当前主链路是否使用：
  - 当前 `Main.tscn` 战斗主链路不依赖它作为卡牌来源
  - 并行 BattleScene 和 `GameRun` 强依赖
- 注意事项：
  - 当前项目存在“主链路硬编码卡牌”和“并行链路 JSON 数据驱动”并存的情况

### 文件：`CardDatabase.gd / BossDatabase.gd / AddonDatabase.gd`
- 作用：数据库查询包装
- 当前主链路是否使用：否
- 当前并行链路是否使用：是

## 系统层：`scripts/systems/`

### 文件：`scripts/systems/PeekSystem.gd`
- 作用：处理“查看 Boss 卡池”
- 主要负责：
  - 读取 `run_state.current_set_state`
  - 扣 SPR
  - 设置 `boss_revealed = true`
- 当前主链路是否使用：否
- 并行 BattleScene 是否使用：是

### 文件：`scripts/systems/AddonSystem.gd`
- 作用：处理加注牌消耗和回合上下文
- 当前主链路是否使用：否
- 并行 BattleScene 是否使用：是

### 文件：`scripts/systems/CollapseEffects.gd`
- 作用：把 `BOD / SPR / REP` 映射到视觉 profile
- 当前主链路是否使用：间接，`ScreenEffects` 可接 profile
- 并行 BattleScene 是否使用：是

### 文件：`scripts/systems/LoggingSystem.gd`
- 作用：日志存储器
- 当前主链路是否使用：当前主 MVP 主要直接用 controller 内部 `_logs`
- 并行 BattleScene 是否使用：是，通过 `GameRun.logging_system`

## 当前战斗逻辑与 UI 的耦合情况
## 当前主链路
- `scripts/game/*` 不直接依赖 Godot UI 节点
- `scripts/ui/Main.gd` 持有这些逻辑对象并驱动 UI
- 这是当前主链路比较清晰的一面

## 并行链路
- `scripts/core/*` 和 `scripts/systems/*` 同样不直接依赖具体 UI 节点
- 但由 `scenes/battle/BattleScene.gd` 统一桥接，耦合面更广

## 当前最重要的判断
- 如果你要改“当前可玩的 MVP 战斗闭环”，优先看 `scripts/game/* + scripts/ui/*`
- 如果你要改“未来更正式的数据驱动挑战流程”，优先看 `scripts/core/* + scripts/data/* + scripts/systems/* + scenes/battle/*`

