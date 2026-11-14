# 翼从专属技能：跨势力实现与验证

本页是七名汉、魏、吴翼从专属技能的主记录页，采用与武将技能相同的四字段与来源顺序。统领能力与翼从效果的取得、失去、来源及生效范围，统一见[统领与翼从](../commander-retinue.md)与[规则](../../../../rules/commander-retinue.md)；本页不重写这些概念与规则，只记录翼从专属技能本身，不替代规则条文。翼从按其统领所属势力排序，同势力按来源武将编号；并州狼骑有多名来源，交叉只在本页注明一次。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 翼从 | 技能 |
| --- | --- | --- |
| HAN | 穆顺 | [穆顺](#mushun) |
| HAN | 西园军 | [西园军](#xiyuanjun) |
| WEI | 并州狼骑 | [并州狼骑](#bingzhou-langqi) |
| WEI | 虎卫军 | [虎卫军](#huweijun) |
| WEI | 牛金 | [牛金](#niujin) |
| WU | 锦帆军 | [锦帆军](#jinfanjun) |
| WU | 曲阿小将 | [曲阿小将](#quaxiaojiang) |

## 技能条目

### 汉

<a id="mushun"></a>
#### 穆顺

- **标识与依据**：翼从 ID `hanjin__retinue_mushun`，技能 ID `hanjin__retinue_skill_mushun`；源码 [retinue_skill_mushun.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_mushun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从穆顺、[移动事件](../../../../rulebook/events/move-card.md)、[弃置](../../../../rulebook/terms/card-op-terms/discard.md)。
- **实现与接口**：
  - 监听真实 `fk.AfterCardsMove`：只认 `moveReason == fk.ReasonDiscard` 且目标为弃牌堆的移动；重铸、给牌等不计。
  - 分别按真实移动数据判断：`move.proposer == 穆顺` 为自己弃置任意角色的牌（含自己主动弃自己的牌）；`move.from == 穆顺` 且 `proposer` 为其他角色为被其他角色弃置。不按技能名或猜测的弃牌者判断。
  - 结算时重新检查候选牌仍在弃牌堆，才允许选择；用 `askToCards` 的 `expand_pile` 展示弃牌堆候选，取得后才写本回合限制标记。
  - 取得成功后才建立 `-turn` 的“下一次同条件弃牌失 1 点体力”标记；罚效果由房间级延迟监听器读取角色标记，不要求穆顺当前仍有技能。罚监听只判断“是否发生了符合条件的弃置”，不要求牌仍在弃牌堆：即使该次弃置的牌已被同优先级技能取走，仍失血。取得事件本身用事件标识抑制同一事件刚建立的罚效果，避免重复扣血。
  - 取得次数标记以技能名开头，随翼从武将迁移；罚标记附在角色身上、不带技能前缀，避免误迁。每回合取得一次由 `-turn` 标记限制。
- **验证依据**：[han_retinues.lua](../../../../tests/han_retinues.lua) 夹具直接授予正式翼从技能、只验证技能本身，覆盖穆顺取得与下一次失血（弃置他人牌后取回一张；同回合下一次弃牌不再取得，失去 1 点体力）。历史记录见[共享验证证据](verification-evidence.md#han_retinues)。
- **未完成与边界**：翼从取得／失去技能由统领公共流程覆盖，本测试直接授予技能，不替代该流程验收；真实客户端弃牌与取牌交互未人工验收。

<a id="xiyuanjun"></a>
#### 西园军

- **标识与依据**：翼从 ID `hanjin__retinue_xiyuanjun`，技能 ID `hanjin__retinue_skill_xiyuanjun`；源码 [retinue_skill_xiyuanjun.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_xiyuanjun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从西园军、[阶段事件](../../../../rulebook/events/phase.md)、[展示](../../../../rulebook/terms/card-op-terms/showCards.md)。
- **实现与接口**：
  - `fk.EventPhaseStart` 以普通 `global + can_trigger + on_cost + on_use` 处理：触发条件是与西园军同势力的角色出牌阶段开始；当前阶段角色可以没有手牌。
  - 被选牌角色是“一名角色”，候选为全场有手牌的合法角色，不限制与西园军同势力（可选敌方，也可选当前空手的阶段角色以外的角色）。先选角色，再用 `askToChooseCard(flag="h")` 由引擎隐藏选牌；返回值用 `Card:getIdList` 规范化为单个 id，兼容 Card/ID/数组。
  - 每个西园军 owner 各自独立处理同一事件，不使用单一 `__done` 互相阻止。
  - 选中牌打两个标记：`hanjin_retinue_xiyuanjun_visible-turn`（`visibility.card_visible` 对全部角色公开，回合末清理）与 `hanjin_retinue_xiyuanjun_lock-turn-inhand`（`prohibit_use`／`prohibit_response` 禁止持有者使用或打出；名字同时含 `-turn` 与 `-inhand`，牌离开手牌立即清理，回合末也清理，避免后续持有者继承错误禁用）。禁止判断会展开虚拟／转化牌的实体子牌，不只看虚拟牌自身 mark。
  - `fk.Damaged` 监听带标记牌的角色：有伤害来源时由来源经 `obtainCard` 获得该牌并清标记；无来源不获得。弃置、给予等其他操作不受用牌／打出限制影响。
- **验证依据**：[han_retinues.lua](../../../../tests/han_retinues.lua) 覆盖当前阶段角色空手、所选敌方角色有手牌也可选；选中手牌对其他角色可见、持有者不能使用（含该子牌的虚拟牌也不能使用）；受伤后伤害来源获得该牌、标记清理。历史记录见[共享验证证据](verification-evidence.md#han_retinues)。
- **未完成与边界**：“公开”使用现有 `VisibilitySkill` 公共接口，无客户端补丁；若客户端未按该接口刷新手牌可见性，需基础组回报最小公共接线，而不是伪造可见数据。伤害来源为空的场合已跳过；多张同时带标记的异常输入只取一张，正常流程一次只建立一张。翼从取得／失去技能由统领公共流程覆盖。

### 魏

<a id="bingzhou-langqi"></a>
#### 并州狼骑

- **标识与依据**：翼从 ID `hanjin__retinue_bingzhou_langqi`，技能 ID `hanjin__retinue_skill_bingzhou_langqi`；源码 [retinue_skill_bingzhou_langqi.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_bingzhou_langqi.lua)，距离状态技 [retinue_skill_bingzhou_distance.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_bingzhou_distance.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从并州狼骑与[统领与翼从](../../../../rules/commander-retinue.md)。**多来源**：并州狼骑可由张辽、吕布等不同统领取得，本页只在此条交叉注明一次，其他机制页不再重复。
- **实现与接口**：
  - 出牌阶段限一次，令一名其他角色视为对你使用【决斗】，本回合你与其距离视为 1。主动技不依赖骨架次数限制：active `can_use` 用 `usedSkillTimes(..., Player.HistoryPhase)` 限制每阶段一次，`on_use` 不再次拒绝已记录的本次发动（引擎在进入 `on_use` 前已记次，二次检查会吞掉本次发动）。
  - 距离关系改为双方 `@[hanjin_bingzhou_pairs]` 表标记，支持多来源／多持有者；距离状态技为随包加载的独立骨架（服务端／客户端同一对象），回合末由房间级清理监听移除状态技并清标记。关系不因失去翼从技能消失。
- **验证依据**：[wei_retinues.lua](../../../../tests/wei_retinues.lua) 覆盖真实【决斗】使用者／目标、双向距离、每阶段一次；历史 3/3，见[共享验证证据](verification-evidence.md#wei_retinues)。
- **未完成与边界**：距离状态技双方挂载／回合末移除、以及客户端距离显示需要实际运行与客户端验证；真实客户端【决斗】与距离提示未人工验收。

<a id="huweijun"></a>
#### 虎卫军

- **标识与依据**：翼从 ID `hanjin__retinue_huweijun`，技能 ID `hanjin__retinue_skill_huweijun`；源码 [retinue_skill_huweijun.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_huweijun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从虎卫军与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为典韦／许褚。
- **实现与接口**：
  - `fk.TurnEnd` 为全局触发，不限于自己回合；每回合结束时，若持有者本回合共计造成和受到过的伤害数大于 1，可以移动场上一张牌。
  - 用 `logic:getActualDamageEvents` 读取实际伤害（排除被防止），`data.from == player` 与 `data.to == player` 分别累加，自己对自己的伤害计两份。满足后复用阶段组 `wei_phases.moveCardInBoard`。
- **验证依据**：[wei_retinues.lua](../../../../tests/wei_retinues.lua) 覆盖真实回合内伤害后移动场上一张牌；历史 3/3。
- **未完成与边界**：真实客户端移牌面板未人工验收；测试在真实 `GameEvent.Turn` 内制造伤害，避免伪造回合历史。

<a id="niujin"></a>
#### 牛金

- **标识与依据**：翼从 ID `hanjin__retinue_niujin`，技能 ID `hanjin__retinue_skill_niujin`；源码 [retinue_skill_niujin.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_niujin.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从牛金与 [rules/general-principles.md](../../../../rules/general-principles.md)。
- **实现与接口**：
  - `fk.TurnEnd` 全局触发，目标为同势力角色（含自己）；同势力角色回合结束时，可使用基本／锦囊／装备每类别至多各一张牌；以此法杀死角色后摸三张牌。
  - 不设固定类别顺序，每次由玩家选择未用类别或结束，逐次调用 `room:askToUseCard`，每项可取消。效果内用牌 `bypass_times = true`、`extraUse = true`，正常禁止与目标条件照常。
  - 来源写入本次 `use.extra_data`；房间级奖励监听在 `fk.Death` 中向上追溯 `GameEvent.UseCard` 的 `extra_data`，仅在本次窗口用牌击杀时摸三张，不依赖持有者之后是否仍有技能。
- **验证依据**：[wei_retinues.lua](../../../../tests/wei_retinues.lua) 覆盖真实用【杀】击杀不同势力角色，牛金奖励恰好一次 3 张，另加标准国战击杀奖励 1 张，总手牌 4；断言技能／同势力／实际用牌后再断言击杀奖励。历史 3/3。此前 `expected 3 actual 25` 的根因与修复见[共享验证证据](verification-evidence.md#牛金奖励根因)。
- **未完成与边界**：每类别用牌的真实客户端面板未人工验收；若后续改用牌流程，需复核 `extra_data` 来源追溯仍只奖励一次。

### 吴

<a id="jinfanjun"></a>
#### 锦帆军

- **标识与依据**：翼从 ID `hanjin__retinue_jinfanjun`，技能 ID `hanjin__retinue_skill_jinfanjun`；源码 [retinue_skill_jinfanjun.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_jinfanjun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从锦帆军与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为甘宁（WU002）。
- **实现与接口**：依据真实 `ReasonDiscard` 操作者与弃牌颜色；每回合每颜色限一次，支付同色可弃牌后摸二；技能自身支付颜色牌的第二次弃置不再触发。颜色次数用 `-turn` 标记，每种颜色各自一次。统领能力与翼从效果沿用[公共规范](../../../../rules/commander-retinue.md)，不在专属技能中重写。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖锦帆军真实弃牌；历史 22/22。
- **未完成与边界**：同回合红黑组合、复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。

<a id="quaxiaojiang"></a>
#### 曲阿小将

- **标识与依据**：翼从 ID `hanjin__retinue_quaxiaojiang`，技能 ID `hanjin__retinue_skill_quaxiaojiang`；源码 [retinue_skill_quaxiaojiang.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_quaxiaojiang.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从曲阿小将与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为太史慈（WU012）。
- **实现与接口**：读取服务器真实 `GameEvent.UseCard` 历史，按事件顺序取得当前使用前的上一张牌，包含同回合获得技能前的使用；不以结算完成顺序误认嵌套用牌。两次目标不完全相同时，可对重合存活目标各造成一点伤害，每回合限一次。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖曲阿小将完整两次用牌及重合目标伤害；历史 22/22。
- **未完成与边界**：复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。
