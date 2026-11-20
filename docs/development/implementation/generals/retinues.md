# 翼从专属技能：跨势力实现与验证

本页是汉、魏、蜀、吴、群、晋翼从专属技能的主记录页，采用与武将技能相同的四字段与来源顺序。统领能力与翼从效果的取得、失去、来源及生效范围，统一见[统领与翼从](../commander-retinue.md)与[规则](../../../rules/commander-retinue.md)；本页不重写这些概念与规则，只记录翼从专属技能本身，不替代规则条文。翼从按其统领所属势力排序，同势力按来源武将编号；并州狼骑有多名来源，交叉只在本页注明一次。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 翼从 | 技能 |
| --- | --- | --- |
| HAN | 穆顺 | [穆顺](#mushun) |
| HAN | 西园军 | [西园军](#xiyuanjun) |
| WEI | 并州狼骑 | [并州狼骑](#bingzhou-langqi) |
| WEI | 虎卫军 | [虎卫军](#huweijun) |
| WEI | 牛金 | [牛金](#niujin) |
| SHU | 周仓 | [周仓](#zhoucang) |
| SHU | 白马义从 | [白马义从](#baima-yicong) |
| SHU | 西凉精骑 | [西凉精骑](#xiliang-jingqi) |
| SHU | 象兵 | [象兵](#xiangbing) |
| WU | 锦帆军 | [锦帆军](#jinfanjun) |
| WU | 曲阿小将 | [曲阿小将](#quaxiaojiang) |
| QUN | 黄巾雷使 | [黄巾雷使](#huangjin-leishi) |
| JIN | 腹心死士 | [腹心死士](#fuxin-sishi) |
| JIN | 文虎 | [文虎](#wenhu) |

## 技能条目

### 汉

<a id="mushun"></a>
#### 穆顺

- **标识与依据**：翼从 ID `qiao_heg__retinue_mushun`，技能 ID `qiao__retinue_skill_mushun`；源码 [retinue_skill_mushun.lua](../../../../pkg/qiao_generals/skills/retinue_skill_mushun.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从穆顺、[移动事件](../../../../rulebook/events/move-card.md)、[弃置](../../../../rulebook/terms/card-op-terms/discard.md)。
- **实现与接口**：
  - 监听真实 `fk.AfterCardsMove`：只认 `moveReason == fk.ReasonDiscard` 且目标为弃牌堆的移动；重铸、给牌等不计。
  - 分别按真实移动数据判断：`move.proposer == 穆顺` 为自己弃置任意角色的牌（含自己主动弃自己的牌）；`move.from == 穆顺` 且 `proposer` 为其他角色为被其他角色弃置。不按技能名或猜测的弃牌者判断。
  - 结算时通过 `askToChooseCards` 的独立牌组展示本次仍在弃牌堆的候选，允许取消。确认后再核对牌仍在弃牌堆，取得后写本回合限制标记。
  - 取得成功后才建立 `-turn` 的“下一次同条件弃牌失 1 点体力”标记；罚效果由房间级延迟监听器读取角色标记，不要求穆顺当前仍有技能。罚监听只判断“是否发生了符合条件的弃置”，不要求牌仍在弃牌堆：即使该次弃置的牌已被同优先级技能取走，仍失血。取得事件本身用事件标识抑制同一事件刚建立的罚效果，避免重复扣血。
  - 取得次数标记以技能名开头，随翼从武将迁移；罚标记附在角色身上、不带技能前缀，避免误迁。每回合取得一次由 `-turn` 标记限制。
- **验证依据**：[han_retinues.lua](../../../../tests/han_retinues.lua) 夹具直接授予正式翼从技能、只验证技能本身，覆盖穆顺取得与下一次失血（弃置他人牌后取回一张；同回合下一次弃牌不再取得，失去 1 点体力）。历史记录见[共享验证证据](verification-evidence.md#han_retinues)。
- **未完成与边界**：翼从取得／失去技能由统领公共流程覆盖，本测试直接授予技能，不替代该流程验收；真实客户端弃牌与取牌交互未人工验收。

<a id="xiyuanjun"></a>
#### 西园军

- **标识与依据**：翼从 ID `qiao_heg__retinue_xiyuanjun`，技能 ID `qiao__retinue_skill_xiyuanjun`；源码 [retinue_skill_xiyuanjun.lua](../../../../pkg/qiao_generals/skills/retinue_skill_xiyuanjun.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从西园军、[阶段事件](../../../../rulebook/events/phase.md)、[展示](../../../../rulebook/terms/card-op-terms/showCards.md)。
- **实现与接口**：
  - `fk.EventPhaseStart` 以普通 `global + can_trigger + on_cost + on_use` 处理：触发条件是与西园军同势力的角色出牌阶段开始；当前阶段角色可以没有手牌。
  - 被选牌角色是“一名角色”，候选为全场有手牌的合法角色，不限制与西园军同势力（可选敌方，也可选当前空手的阶段角色以外的角色）。先选角色，再用 `askToChooseCard(flag="h")` 由引擎隐藏选牌；返回值用 `Card:getIdList` 规范化为单个 id，兼容 Card/ID/数组。
  - 每个西园军 owner 各自独立处理同一事件，不使用单一 `__done` 互相阻止。
  - 选中牌打两个标记：`qiao_retinue_xiyuanjun_visible-turn`（`visibility.card_visible` 对全部角色公开，回合末清理）与 `qiao_retinue_xiyuanjun_lock-turn-inhand`（`prohibit_use`／`prohibit_response` 禁止持有者使用或打出；名字同时含 `-turn` 与 `-inhand`，牌离开手牌立即清理，回合末也清理，避免后续持有者继承错误禁用）。禁止判断会展开虚拟／转化牌的实体子牌，不只看虚拟牌自身 mark。
  - `visibility.card_visible` 命中公开标记时返回 `true`，未命中时交回引擎判断。回归检查持有者自己的未标记手牌依然可见、其他人的未标记手牌依然隐藏。
  - `fk.Damaged` 监听带标记牌的角色：有伤害来源时由来源经 `obtainCard` 获得该牌并清标记；无来源不获得。弃置、给予等其他操作不受用牌／打出限制影响。
- **验证依据**：[han_retinues.lua](../../../../tests/han_retinues.lua) 覆盖当前阶段角色空手、所选敌方角色有手牌也可选；选中手牌对其他角色可见、持有者不能使用（含该子牌的虚拟牌也不能使用）；受伤后伤害来源获得该牌、标记清理。历史记录见[共享验证证据](verification-evidence.md#han_retinues)。
- **未完成与边界**：“公开”使用现有 `VisibilitySkill` 公共接口，无客户端补丁；若客户端未按该接口刷新手牌可见性，需基础组回报最小公共接线，而不是伪造可见数据。伤害来源为空的场合已跳过；多张同时带标记的异常输入只取一张，正常流程一次只建立一张。翼从取得／失去技能由统领公共流程覆盖。

### 魏

<a id="bingzhou-langqi"></a>
#### 并州狼骑

- **标识与依据**：翼从 ID `qiao_heg__retinue_bingzhou_langqi`，技能 ID `qiao__retinue_skill_bingzhou_langqi`；源码 [retinue_skill_bingzhou_langqi.lua](../../../../pkg/qiao_generals/skills/retinue_skill_bingzhou_langqi.lua)，距离状态技 [retinue_skill_bingzhou_distance.lua](../../../../pkg/qiao_generals/skills/retinue_skill_bingzhou_distance.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从并州狼骑与[统领与翼从](../../../rules/commander-retinue.md)。**多来源**：并州狼骑可由张辽、吕布等不同统领取得，本页只在此条交叉注明一次，其他机制页不再重复。
- **实现与接口**：
  - 出牌阶段限一次，令一名其他角色视为对你使用【决斗】，本回合你与其距离视为 1。主动技不依赖骨架次数限制：active `can_use` 用 `usedSkillTimes(..., Player.HistoryPhase)` 限制每阶段一次，`on_use` 不再次拒绝已记录的本次发动（引擎在进入 `on_use` 前已记次，二次检查会吞掉本次发动）。
  - 距离关系改为双方 `@[qiao_bingzhou_pairs]` 表标记，支持多来源／多持有者；距离状态技为随包加载的独立骨架（服务端／客户端同一对象），回合末由房间级清理监听移除状态技并清标记。关系不因失去翼从技能消失。
- **验证依据**：[wei_retinues.lua](../../../../tests/wei_retinues.lua) 覆盖真实【决斗】使用者／目标、双向距离、每阶段一次；历史 3/3，见[共享验证证据](verification-evidence.md#wei_retinues)。
- **未完成与边界**：距离状态技双方挂载／回合末移除、以及客户端距离显示需要实际运行与客户端验证；真实客户端【决斗】与距离提示未人工验收。

<a id="huweijun"></a>
#### 虎卫军

- **标识与依据**：翼从 ID `qiao_heg__retinue_huweijun`，技能 ID `qiao__retinue_skill_huweijun`；源码 [retinue_skill_huweijun.lua](../../../../pkg/qiao_generals/skills/retinue_skill_huweijun.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从虎卫军与[统领与翼从](../../../rules/commander-retinue.md)。来源武将为典韦／许褚。
- **实现与接口**：
  - `fk.TurnEnd` 为全局触发，不限于自己回合；每回合结束时，若持有者本回合共计造成和受到过的伤害数大于 1，可以移动场上一张牌。
  - 用 `logic:getActualDamageEvents` 读取实际伤害（排除被防止），`data.from == player` 与 `data.to == player` 分别累加，自己对自己的伤害计两份。满足后复用阶段组 `wei_phases.moveCardInBoard`。
  - 魏、吴调用者共用选人和移牌逻辑。选人请求只开放可移出或接收的候选，选牌请求按角色列出可移动的装备与判定牌并允许取消。确认后重新校验牌区和目标。
- **验证依据**：[wei_retinues.lua](../../../../tests/wei_retinues.lua) 覆盖真实回合内伤害、客户端选人、合法牌组、实际移动、取消及无合法组合时关闭询问。
- **未完成与边界**：真实客户端移牌面板未人工验收；测试在真实 `GameEvent.Turn` 内制造伤害，避免伪造回合历史。

<a id="niujin"></a>
#### 牛金

- **标识与依据**：翼从 ID `qiao_heg__retinue_niujin`，技能 ID `qiao__retinue_skill_niujin`；源码 [retinue_skill_niujin.lua](../../../../pkg/qiao_generals/skills/retinue_skill_niujin.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从牛金与 [docs/rules/general-principles.md](../../../rules/general-principles.md)。
- **实现与接口**：
  - `fk.TurnEnd` 全局触发，目标为同势力角色（含自己）；同势力角色回合结束时，可使用基本／锦囊／装备每类别至多各一张牌；以此法杀死角色后摸三张牌。
  - 发动时直接进入自由用牌请求。每次用牌后按实际用牌类别缩减下一次请求的候选和提示，取消或用完三类即结束。公共入口允许武圣、血海魔王樽等需要用牌时可用的技能，排除【闪】等被动牌并复核禁止和目标。合法用牌设置 `bypass_times` 和 `extraUse`。
  - 来源写入本次 `use.extra_data`；房间级奖励监听在 `fk.Death` 中向上追溯 `GameEvent.UseCard` 的 `extra_data`，仅在本次窗口用牌击杀时摸三张，不依赖持有者之后是否仍有技能。
- **验证依据**：[wei_retinues.lua](../../../../tests/wei_retinues.lua) 覆盖真实用【杀】击杀不同势力角色，牛金奖励恰好一次 3 张，另加标准国战击杀奖励 1 张，总手牌 4；断言技能／同势力／实际用牌后再断言击杀奖励。历史 3/3。此前 `expected 3 actual 25` 的根因与修复见[共享验证证据](verification-evidence.md#牛金奖励根因)。
- **未完成与边界**：每类别用牌的真实客户端面板未人工验收；若后续改用牌流程，需复核 `extra_data` 来源追溯仍只奖励一次。

### 蜀关联翼从

<a id="zhoucang"></a>
#### 周仓

- **标识与依据**：`qiao__retinue_skill_zhoucang`；[源码](../../../../pkg/qiao_generals/skills/retinue_skill_zhoucang.lua)；[标准翼从表](../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../rules/commander-retinue.md)。
- **实现与接口**：杀后从仍可取得的本次杀或目标闪实体牌中选牌给第三人；红牌受赠者以实际手牌／转化使用杀，显式目标条件读取周仓攻击范围，选择及执行沿用同一策略，绕过通常次数且不计次。
- **验证依据**：[shu_retinues.lua](../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。

<a id="baima-yicong"></a>
#### 白马义从

- **标识与依据**：`qiao__retinue_skill_baima_yicong`；[源码](../../../../pkg/qiao_generals/skills/retinue_skill_baima_yicong.lua)；[标准翼从表](../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../rules/commander-retinue.md)。
- **实现与接口**：CardUsing／CardResponding 两入口定位 responseToEvent.from，在使用／打出闪时获得对方一张手牌或装备；包含虚拟闪，不按响应牌当前持有者猜对方。
- **验证依据**：[shu_retinues.lua](../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。

<a id="xiliang-jingqi"></a>
#### 西凉精骑

- **标识与依据**：`qiao__retinue_skill_xiliang_jingqi`；[源码](../../../../pkg/qiao_generals/skills/retinue_skill_xiliang_jingqi.lua)；[标准翼从表](../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../rules/commander-retinue.md)。
- **实现与接口**：结束阶段选择实际手牌／转化杀，正确传递四种杀名、pattern、bypass_times 与 extraUse，恰执行一次；目标攻击范围内无持有者时，可令目标自行强制弃一张牌。
- **验证依据**：[shu_retinues.lua](../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。

<a id="xiangbing"></a>
#### 象兵

- **标识与依据**：`qiao__retinue_skill_xiangbing`；[源码](../../../../pkg/qiao_generals/skills/retinue_skill_xiangbing.lua)；[标准翼从表](../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../rules/commander-retinue.md)。
- **实现与接口**：杀后按实际伤害记录与该杀目标集合的交集，一次生成南蛮；火伤后按座次相邻且去重的集合，一次生成杀；显式目标数量等于选定集合。火伤生成的杀造成伤害后仍正常触发杀后南蛮，不添加无依据豁免。
- **验证依据**：[shu_retinues.lua](../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。

### 吴

<a id="jinfanjun"></a>
#### 锦帆军

- **标识与依据**：翼从 ID `qiao_heg__retinue_jinfanjun`，技能 ID `qiao__retinue_skill_jinfanjun`；源码 [retinue_skill_jinfanjun.lua](../../../../pkg/qiao_generals/skills/retinue_skill_jinfanjun.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从锦帆军与[统领与翼从](../../../rules/commander-retinue.md)。来源武将为甘宁（WU002）。
- **实现与接口**：依据真实 `ReasonDiscard` 操作者与弃牌颜色；每回合每颜色限一次，支付同色可弃牌后摸二；技能自身支付颜色牌的第二次弃置不再触发。颜色次数用 `-turn` 标记，每种颜色各自一次。统领能力与翼从效果沿用[公共规范](../../../rules/commander-retinue.md)，不在专属技能中重写。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖锦帆军真实弃牌；历史 22/22。
- **未完成与边界**：同回合红黑组合、复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。

<a id="quaxiaojiang"></a>
#### 曲阿小将

- **标识与依据**：翼从 ID `qiao_heg__retinue_quaxiaojiang`，技能 ID `qiao__retinue_skill_quaxiaojiang`；源码 [retinue_skill_quaxiaojiang.lua](../../../../pkg/qiao_generals/skills/retinue_skill_quaxiaojiang.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从曲阿小将与[统领与翼从](../../../rules/commander-retinue.md)。来源武将为太史慈（WU012）。
- **实现与接口**：读取服务器真实 `GameEvent.UseCard` 历史，按事件顺序取得当前使用前的上一张牌，包含同回合获得技能前的使用；不以结算完成顺序误认嵌套用牌。两次目标不完全相同时，可对重合存活目标各造成一点伤害，每回合限一次。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖曲阿小将完整两次用牌及重合目标伤害；历史 22/22。
- **未完成与边界**：复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。

### 群

<a id="huangjin-leishi"></a>
#### 黄巾雷使

- **标识与依据**：翼从 ID `qiao_heg__retinue_huangjin_leishi`，技能 ID `qiao__retinue_skill_huangjin_leishi`；源码 [retinue_skill_huangjin_leishi.lua](../../../../pkg/qiao_generals/skills/retinue_skill_huangjin_leishi.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从黄巾雷使与[统领与翼从](../../../rules/commander-retinue.md)。来源武将为张角（QUN010）。
- **实现与接口**：模式级常驻记录器 [qun_damage_history](../../../../pkg/qiao_mode/skills/qun_damage_history.lua) 在开局安装，记录本回合第一个“不因使用手牌而造成伤害”的 `fk.DamageCaused` 时机；黄巾雷使只在该时机开放一次选择，未发动／无手牌／放弃都消耗本回合机会。记录器按真实 `DamageData` 的 `chain/parent` 与 `UseCardData:isUsingHandcard` 判断直接渠道，翼从本体不重复判断。
- **验证依据**：已执行 [qun_judgement.lua](../../../../tests/qun_judgement.lua) 的 `testHuangjinBlackIncreasesFirstNonHandcardDamage`、`testHuangjinRedGivesJudgeCardToSource`、`testHuangjinLateAcquisitionDoesNotReopenFirstChance`、`testHuangjinIgnoresHandcardSlashDamage`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：转化牌、无实体牌、铁索传导组合未穷举；客户端判定与增伤提示未人工验收。

### 晋

<a id="fuxin-sishi"></a>
#### 腹心死士

- **标识与依据**：翼从 ID `qiao_heg__retinue_fuxin_sishi`，技能 ID `qiao__retinue_skill_fuxin_sishi`；源码 [retinue_skill_fuxin_sishi.lua](../../../../pkg/qiao_generals/skills/retinue_skill_fuxin_sishi.lua)。规则见[标准武将表](../../../rules/standard-generals.md)翼从腹心死士与[统领与翼从](../../../rules/commander-retinue.md)。来源武将为司马师（JIN002）与司马懿（JIN009）。
- **实现与接口**：同势力角色回合结束时，由 [jin_resources.lua](../../../../pkg/qiao_generals/util/jin_resources.lua) 的 `hasUnusedLimitedSkill`／`limitedUsedThisTurn` 按真实限定技标签与发动历史分别检查两项，可都执行。条件一：其仍有未发动限定技时，翼从持有者摸一张，然后交给其一张自己的牌；目标就是持有者时只摸不交。条件二：其本回合发动过限定技时，可视为使用一张【杀】，目标范围按当前回合角色（`target`）的攻击范围计算，不是翼从持有者；接入 `C.explicit` 的 `in_attack_range_of` 与 `room:useCard`。统领取得、限一与翼从来源由公共规则处理，本技能不重写。
- **验证依据**：[jin_resources.lua](../../../../tests/jin_resources.lua) 覆盖未用限定技给牌、自己为目标只摸不交、已用限定技时用当前回合角色攻击范围使用【杀】；定向 15/15（3.686s），见[共享验证证据](verification-evidence.md#jin-resources)。
- **未完成与边界**：暗置来源、多个限定技、目标死亡、无合法【杀】目标与客户端交互未人工验收。

<a id="wenhu"></a>
#### 文虎

- **标识与依据**：翼从 ID `qiao_heg__retinue_wenhu`，技能 ID `qiao__retinue_skill_wenhu`；源码 [retinue_skill_wenhu.lua](../../../../pkg/qiao_generals/skills/retinue_skill_wenhu.lua)。规则见[文鸯规范](../../../rules/generals/jin014-wenyang.md)与[统领与翼从](../../../rules/commander-retinue.md)。来源武将为文鸯（JIN014），限一；同一武将的冰杀统领能力另见公共统领记录。
- **实现与接口**：出牌阶段限一次，`askToChoices` 让玩家勾选手牌/装备/判定三区中任意个非空且全部可弃置的区域；选定后先固定所有选中区的原始牌，再用**一次** `throwCard` 同时弃置，避免逐区重新读取把弃牌触发技新增的牌一并收走。X 按选择时固定牌的完整选中区计算，不按牌数或装备栏数。随后以 `card_use_targets` 的 `C.askToUseVirtualCard` 使用正式 `qiao__duel`，`C.default` 只把 `max_targets` 改为 X，保留原牌其他目标条件，不放宽距离。
- **验证依据**：[jin_chain.lua](../../../../tests/jin_chain.lua) 覆盖完整弃置手牌区+装备区（X=2）、判定区保留、决斗有 2 名目标；定向 6/6，见[共享验证证据](verification-evidence.md#jin-chain)。
- **未完成与边界**：仅弃判定区、区域含禁弃牌、空区/部分弃置、目标上限大于可指定人数、客户端多选与联网未人工验收。
