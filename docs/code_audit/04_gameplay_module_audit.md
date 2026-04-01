# Gameplay Module Audit

## 模块范围
本文件聚焦当前主链路战斗逻辑，即 [scripts/game/](../../scripts/game) 下的模块：

- [BattleCard.gd](../../scripts/game/BattleCard.gd)
- [CombatActorState.gd](../../scripts/game/CombatActorState.gd)
- [BossAI.gd](../../scripts/game/BossAI.gd)
- [BattleResolver.gd](../../scripts/game/BattleResolver.gd)

同时说明这些逻辑如何被 [scripts/ui/Main.gd](../../scripts/ui/Main.gd) 调用。

## 当前战斗逻辑的总体特点
当前主链路战斗逻辑已经被压缩成一套 **极简 3 类牌模型**：

- `aggression`
- `defense`
- `pressure`

克制关系固定为：

- `aggression > pressure`
- `pressure > defense`
- `defense > aggression`

这套主链路逻辑与 `scripts/core/*` 的数据驱动战斗系统是分开的。当前玩家真正启动的 `Main.tscn` 路径，使用的是这里的 `scripts/game/*`。

## 关键文件说明
### `scripts/game/BattleCard.gd`
- 路径：[scripts/game/BattleCard.gd](../../scripts/game/BattleCard.gd)
- 作用：极简牌模型与模板定义。
- 主要负责：
  - 定义三种合法类型
  - 定义玩家固定模板
  - 定义 Boss 三套固定模板
  - `display_name` 派生
  - `to_dict()` 输出给 UI 使用

### 当前玩家固定模板
- `Aggression`
- `Aggression`
- `Defense`
- `Pressure`
- `Pressure`

### 当前 Boss 三套模板
- `template_a`
  - `Aggression / Aggression / Pressure / Pressure / Defense`
- `template_b`
  - `Defense / Defense / Aggression / Pressure / Pressure`
- `template_c`
  - `Aggression / Defense / Pressure / Aggression / Defense`

### 设计特点
- 不依赖 JSON 数据
- 不存在变体卡、额外标签、基础值差异
- `to_dict()` 已缩减到最小 UI 所需字段

### `scripts/game/CombatActorState.gd`
- 路径：[scripts/game/CombatActorState.gd](../../scripts/game/CombatActorState.gd)
- 作用：主链路单个 actor 的运行时状态容器。
- 主要负责：
  - `hp / bod / spr / rep`
  - 本局 `cards`
  - 本局 `used_slots`
  - deck blueprint 持有与按局重建

### 数据层次
- **挑战级持久状态**
  - `bod / spr / rep`
  - 在 `start_new_challenge()` 时初始化为 3
  - 在 `reset_for_new_set()` 时不会自动重置
- **局级状态**
  - `hp`
  - `cards`
  - `used_slots`
  - 在 `reset_for_new_set()` 时重建

### 注意事项
- `snapshot()` 目前不包含完整 deck 组成，只包含 hp/status/used_slots。
- 这意味着外部如果要记录“这一局实际用了哪套模板”，必须在 controller 层额外保留。

### `scripts/game/BossAI.gd`
- 路径：[scripts/game/BossAI.gd](../../scripts/game/BossAI.gd)
- 作用：Boss 在主链路里的最小决策器。
- 主要负责：
  - 根据玩家当前出的牌，把 Boss 剩余可用牌分到 `counter / neutral / wrong`
  - 按 `50 / 30 / 20` 选择类别
  - 从选中类别里随机选一张剩余牌

### 决策机制
- 若 Boss 还有能克制玩家的牌，优先概率最高
- 若目标类别为空，会自动从剩余非空 bucket 回退
- 决策对象是 **剩余未使用槽位**

### 依赖
- 只依赖 `MvpCombatActorState` 和 `MvpBattleCard`
- 不依赖 Godot 场景节点

### `scripts/game/BattleResolver.gd`
- 路径：[scripts/game/BattleResolver.gd](../../scripts/game/BattleResolver.gd)
- 作用：主链路单回合结算器。
- 主要负责：
  - 根据双方牌类型计算回合结果
  - 计算 HP 伤害
  - 生成长期状态变化
  - 返回供 controller 应用和显示的结果字典

### 当前结算模型
- 统一基础强度：`BASE_SCORE = 1`
- 克制加成：
  - 克制 `+1`
  - 被克 `-1`
  - 同类 `0`
- `spr <= 1`：
  - 本回合牌有效强度额外 `-1`
- `bod <= 1`：
  - 受到伤害时额外再吃 `+1`

### 长期状态映射
- `aggression -> bod`
- `pressure -> spr`
- `defense -> rep`

### 结算输出
`resolve_round()` 返回一个结果字典，包含：
- 出牌槽位
- 双方卡牌 `to_dict()`
- 双方有效分数
- 双方本回合受伤
- 胜者
- `status_changes`
- `summary_text`
- `log_lines`

## 模块间数据流
### 出牌前
- `Main.gd` 持有 `_player_state` 与 `_boss_state`
- 玩家点击手牌后，controller 取出玩家卡
- `BossAI.choose_slot()` 读取 `_boss_state` 剩余槽位并选出 Boss 牌

### 结算时
- `BattleResolver.resolve_round(player_state, boss_state, player_slot, boss_slot)`
- 只负责算结果，不直接改 UI

### 结算后
- `Main.gd._apply_round_result()`：
  - 标记 used slot
  - 扣 HP
  - 应用 status change
  - 刷 clash area
  - 判定 set / challenge 是否结束

## 当前逻辑集中度判断
### 哪些逻辑已经下沉到 gameplay 层
- 卡牌类型和模板
- actor 运行时状态
- Boss 决策
- 回合胜负公式

### 哪些逻辑仍在 controller 层
- set / challenge 推进
- reveal 状态
- set winner 判定
- 日志输出
- 回合结果应用顺序

### 结论
当前主链路 gameplay 层已经足够支撑 MVP，但还不是完整的独立战斗域模型。  
尤其 `set` 和 `challenge` 级数据仍主要掌握在 `scripts/ui/Main.gd` 中，而不是独立状态对象中。

## 按数据生命周期划分
### 挑战级
- `_player_set_wins`
- `_boss_set_wins`
- `_challenge_over`
- actor 的 `bod / spr / rep`

### 局级
- `_current_set_index`
- `_current_boss_template_id`
- `_boss_battle_revealed`
- actor 的 `hp`
- actor 的 `cards`
- actor 的 `used_slots`

### 回合级
- `_current_turn_index`
- `resolve_round()` 产出的 `result`
- `ClashArea` 当前显示内容

## 关键判断
1. 当前主链路战斗系统已经不是旧的多标签/多变体逻辑，而是极简 3 类牌系统。
2. Boss 不是随机混合发牌，而是每局从 3 套固定模板中选 1 套。
3. `BossBattleDeckView` 的推理价值，直接来自固定模板 + reveal + used_slots。
4. 当前最容易被误判的点，是把 `scripts/game/*` 和 `scripts/core/*` 当成同一套系统。
