# 用牌目标与距离：跨势力技能实现与验证

本页是“用牌目标与距离”机制的主记录页：主动用牌、效果指定的额外／强制目标、目标的抵消与转移，以及距离计算修正；另含在主记录页已完整记录、此处只展开用牌侧的少量分记录。不替代规则条文，规则冲突时以 `docs/rules/` 与 `rulebook/` 为准。范围边界：以目标指定、目标转移、距离或响应限制为核心的技能；纯视为牌转换归[转化与生成用牌](conversion.md)，阶段跳过归[阶段与回合流程](phases.md)，拼点流程归[拼点](pindian.md)。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN005 | 何进 | [谋诛](#han005-1) |
| HAN008 | 伏皇后 | [求援](#han008-2) |
| HAN009 | 伏完 | [谋溃](#han009-1) |
| WEI010 | 徐晃 | [长驱](#wei010-2) |
| WEI011 | 曹仁 | [伪溃](#wei011-1) |
| WEI013 | 荀彧 | [驱虎](#wei013-1)（分记录；主记录见[拼点](pindian.md#wei013-1)） |
| SHU003 | 张飞 | [咆哮](#shu003-1) |
| SHU004 | 诸葛亮 | [空城](#shu004-2) |
| SHU005 | 赵云 | [突阵](#shu005-2) |
| SHU006 | 马超 | [马术](#shu006-1) |
| SHU006 | 马超 | [铁骑](#shu006-2) |
| SHU008 | 黄忠 | [烈勇](#shu008-1) |
| SHU013 | 刘禅 | [享乐](#shu013-1) |
| WU006 | 大乔 | [流离](#wu006-2) |
| WU007 | 陆逊 | [谦逊](#wu007-1) |
| WU012 | 太史慈 | [天义](#wu012-1)（分记录；主记录见[拼点](pindian.md#wu012-1)） |
| WU016 | 丁奉 | [短兵](#wu016-1)、[奋迅](#wu016-2) |
| QUN002 | 吕布 | [无双](#qun002-1)、[虓猛](#qun002-2) |
| QUN003 | 貂蝉 | [离间](#qun003-1) |
| QUN007 | 贾诩 | [乱武](#qun007-2)、[帷幕](#qun007-3) |
| QUN008 | 庞德 | [马术](#shu006-1)、[猛撼](#qun008-2) |
| QUN013 | 马腾 | [马术](#shu006-1) |
| QUN018 | 邹氏 | [祸水](#qun018-1) |
| QUN027 | 韩遂 | [马术](#shu006-1) |
| JIN003 | 司马昭 | [挟征](#jin003-2) |
| JIN012 | 羊徽瑜 | [慈威](#jin012-1) |
| JIN013 | 王濬 | [克清](#jin013-2) |
| JIN015 | 石苞 | [前驱](#jin015-1) |

## 相关包别条目

[摧破](zhen-skills.md#han014-1) · [虎翼](zhen-skills.md#han014-2) · [鹤翼](zhen-skills.md#wei018-2) · [挑衅](zhen-skills.md#shu012-1) · [天覆](zhen-skills.md#shu012-2) · [潜袭](shi-skills.md#shu019-2) · [鸟翔](zhen-skills.md#wu017-2) · [破军](zhen-skills.md#wu020-2) · [千幻](zhen-skills.md#qun011-1) · [穿心](shi-skills.md#qun024-1) · [龙飞](shi-skills.md#qun024-2) · [锋械](zhen-skills.md#jin023-1) · [总戎](shi-skills.md#jin017-1) · [烈戎](shi-skills.md#jin022b-1) · [转蓬](em-han001.md#em-han001-2)

## 技能条目

### 汉

<a id="han005-1"></a>
#### 谋诛（HAN005 何进）

- **标识与依据**：运行时 ID `qiao__skill_han005_1`；源码 [skill_han005_1.lua](../../../../pkg/qiao_generals/skills/skill_han005_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN005；用牌目标入口见[效果指定的用牌目标条件](../card-use-targets.md)。同将构难见[伤害、体力与死亡](damage.md#han005-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L565)。

> 出牌阶段限一次，你可以令一名其他角色交给你一张手牌，然后若其手牌数小于你，其视为使用一张【杀】或【决斗】，若此牌目标与你势力相同，其弃置一张牌。

- **实现与接口**：
  - 出牌阶段限一次（效果 `max_phase_use_time = 1`，自定义 `can_use` 内同时检查阶段次数）。
  - 发动时只选一名其他存活角色，不选择牌，也不把“交牌能否执行”当作目标限制或何进消耗。交牌由被令角色选择一张手牌，再以 `moveCardTo(..., fk.ReasonGive, ...)` 交给何进；目标无手牌时交牌不执行，但继续“然后”的手牌比较与可执行效果。
  - 交牌后比较双方**当前手牌数**，仅当目标手牌数小于何进时，以 `selectVirtualCard` 按正常牌面条件选牌和目标。给返回的用牌数据附上本次何进来源，再执行一次 `room:useCard`。虚拟牌默认 `extraUse`。
  - `fk.CardUsing` 消费本次来源并检查当时的目标。若有与何进同势力的目标，使用者弃置一张牌，见[何进裁定](../../../rules/generals/han005-hejin.md#谋诛)。
- **验证依据**：[han005_hejin.lua](../../../../tests/han005_hejin.lua) 验证异势力目标无需弃牌，以及同势力场景在 `fk.TargetSpecifying` 已观察到牌位于弃牌堆，随后【杀】照常结算。
- **未完成与边界**：没有合法【杀】或【决斗】目标时选牌返回空。客户端选目标及弃牌界面待人工验收。

<a id="han008-2"></a>
#### 求援（HAN008 伏皇后）

- **标识与依据**：运行时 ID `qiao__skill_han008_2`；源码 [skill_han008_2.lua](../../../../pkg/qiao_generals/skills/skill_han008_2.lua)。规则见[伏皇后规范](../../../rules/generals/han008-fuhuanghou.md)、[牌的使用相关事件](../../../../rulebook/events/use-card.md)与[指定额外目标](../../../rules/extra-targets.md)。同将惴恐见[拼点](pindian.md#han008-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L619)。

> 当你成为其他角色使用【杀】的目标时，你可以令另一名其他角色也成为目标且优先结算，此【杀】被抵消后对其余目标无效。

- **实现与接口**：
  - `TargetConfirming` 触发，只在伏皇后成为其他角色【杀】的目标时提供一次；同一名伏皇后对同一次 use 不会重复求援。
  - 候选使用公共 `ExtraTargets` 显式条件 `other_roles = true`：不按普通攻击距离阻挡，但仍排除已禁止、已在本次目标列表中的角色。
  - 通过 AimData 的目标加入接口增加目标，新增目标仍会生成 `TargetSpecified`／`TargetConfirmed` 等正常目标事件。
  - 新增目标 id 记录在本次 `UseCardData` 上；效果顺序只在 `BeforeCardUseEffect` 调整为新增目标优先，不在目标阶段排序、不提前事件。该字段避免 `extra_data` 在目标事件结束时被 AimData 旧值覆盖。
  - 任意目标抵消后，复用方天画戟的 use 级 `nullifiedTargets` 登记，使其余目标无效；监听器按 use 上已建立的记录执行，不依赖伏皇后当前是否仍有求援。
- **验证依据**：[han008_fuhuanghou.lua](../../../../tests/han008_fuhuanghou.lua) 覆盖求援新增目标保留目标事件、效果顺序优先，且被【闪】抵消后原目标不再受此【杀】影响。历史记录见[共享验证证据](verification-evidence.md#han008_fuhuanghou)。
- **未完成与边界**：未执行真实客户端选目标、拼点及新增目标响应交互；未覆盖多个伏皇后同时求援、目标中途死亡／失技、无合法新增目标等排列；未验证手工强制取消或伪造目标数据，依赖公共目标／用牌复核。

<a id="han009-1"></a>
#### 谋溃（HAN009 伏完）

- **标识与依据**：运行时 ID `qiao__skill_han009_1`；源码 [skill_han009_1.lua](../../../../pkg/qiao_generals/skills/skill_han009_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN009、[牌的使用相关事件](../../../../rulebook/events/use-card.md)与[取消](../../../../rulebook/terms/resolution-terms/cancel.md)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L642)。

> 当你使用【杀】指定目标后，你可以选择一个目标并选择一至两项：1.摸一张牌；2.弃置其一张牌。若你选择了两项，当其抵消此【杀】时，其弃置你一张牌。

- **实现与接口**：
  - `TargetSpecified` 是每个目标分别生成的时机；谋溃在本次 `UseCardData` 上写入已发动标记，因此一张【杀】只发动一次，不会为每个目标重复询问。
  - 只有一个合法目标时直接采用该目标；有多个合法目标时，发动者选择其中一个。再通过 `askToChoices` 选择一至两项：摸一张、弃置该目标一张牌。执行顺序固定为先摸后弃。
  - 双选时在 use 上记录被选目标 id 与“双选”标记；抵消监听器只在 `CardEffectCancelledOut` 的当前目标正是该目标时触发，其他目标抵消不触发。触发后由抵消者选择并弃置伏完一张手牌／装备牌。本次发动与反弃绑定改挂 `UseCardData` 字段，修复双选后抵消不触发反弃。
  - 反弃监听器是模块缓存的房间级对象，使用本次 use 已建立的标记，不依赖伏完当前是否仍有谋溃；失技／暗置后双选后续仍结算。无“挂载”式额外技能，也没有为每个目标复制一套谋溃效果。
- **验证依据**：[han009_fuwan.lua](../../../../tests/han009_fuwan.lua) 覆盖单选摸牌、单选弃牌且不触发反弃；双选后被选目标用【闪】抵消、弃置伏完一张牌；多目标【杀】中未被选中的另一目标抵消时不反弃；一张【杀】只发动一次。历史记录见[共享验证证据](verification-evidence.md#han009_fuwan)。
- **未完成与边界**：未执行真实客户端选目标、勾选一至两项、选择抵消者所弃之牌的交互；未覆盖目标在结算中死亡／失去所有牌、同一目标重复抵消、无牌可反弃、技能使用后中途失技的独立排列；未验证武将交换。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han009_fuwan.lua --timeout 120`（当时标为待基础组执行，未产生该文件单独输出，后由默认套件覆盖）。

### 魏

<a id="wei010-2"></a>
#### 长驱（WEI010 徐晃）

- **标识与依据**：运行时 ID `qiao__skill_wei010_2`；源码 [skill_wei010_2.lua](../../../../pkg/qiao_generals/skills/skill_wei010_2.lua)。事实层 [wei_history.lua](../../../../pkg/qiao_mode/rules/wei_history.lua) 与 [wei_damage_history.lua](../../../../pkg/qiao_mode/skills/wei_damage_history.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI010。同将断粮见[转化与生成用牌](conversion.md#wei010-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L4988)。

> 锁定技，你对本回合未受到过你伤害的角色使用牌无距离限制。

- **实现与接口**：
  - `targetmod.bypass_distances` 只对公开标记中“本回合未被该来源伤害过”的目标返回真，不修改距离本身；事实由模式记录器负责，技能本身不再记录。
  - 不使用私有 `room:getTag`。记录器把“目标 id 集合”写入同步玩家标记 `qiao_wei_damage_targets`（`room:setPlayerMark`），客户端与服务端 `targetmod` 读同一公开数据，不在客户端回调里读取 server history；每回合开始清空，仅在真实伤害（`data.damage > 0`）后刷新。
  - `mode.lua` 在 `logic:start` 前安装记录器，因此与长驱武将是否已选、明置或之后换将无关。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖不授予长驱时模式记录器仍写入同步标记、距离不变、`TurnStart` 清空，以及 `ClientPlayer:getTableMark` 读取。
- **未完成与边界**：真实客户端 targetmod 的 UI 距离提示未人工验证。记录器按 `mode.lua` 的 `logic:start` 安装；若其他模式复用该 logic 但不应记录，需要按模式再限定。

<a id="wei011-1"></a>
#### 伪溃（WEI011 曹仁）

- **标识与依据**：运行时 ID `qiao__skill_wei011_1`；源码 [skill_wei011_1.lua](../../../../pkg/qiao_generals/skills/skill_wei011_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI011。同将励战见[辅助与牌资源](support.md#wei011-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L5009)。

> 出牌阶段限一次，你可以失去1点体力并观看一名其他角色的手牌。若其中有【闪】，则你视为对其使用一张【杀】，且本回合你计算与其距离视为1；否则你弃置其中一张牌。

- **实现与接口**：
  - 出牌阶段限一次；失去 1 点体力→私看目标手牌；有【闪】则按公共 `explicit` 目标策略视为【杀】，距离固定只对“发动者 → 目标”单向生效（`-turn` 标记）；否则弃置其一张手牌。`can_use` 要求 `player.hp >= 1`。
  - 有【闪】时使用私密 `viewCards`，随后结算【杀】。无【闪】且有多张合法弃牌时，使用 [同一私密面板](../skill-ui.md#私看手牌并操作其中的牌) 正面显示目标手牌并选定弃牌。只有一张合法牌时，观看后自动弃置。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖伪溃无【闪】时真实私看后弃置目标一张手牌、有【闪】时真实【杀】分支（私看收件人与牌集、恰好一次来源为发动者、目标受伤与距离标记）、失去体力。测试夹具的根因与修复见[共享验证证据](verification-evidence.md#魏包白板夹具)。
- **未完成与边界**：伪溃【闪】分支已按白板夹具与官方回复队列恢复并通过；若后续改动技能内嵌使用流程，需重跑并重新核对请求消费顺序。按“你计算与其距离视为1”实现为发动者至目标的单向固定距离，该方向已有明确文本依据，不列为待裁定事项。真实客户端 targetmod 的 UI 距离提示未人工验证。

<a id="wei013-1"></a>
#### 驱虎（WEI013 荀彧，分记录）

- **标识与依据**：运行时 ID `qiao__skill_wei013_1`；源码 [skill_wei013_1.lua](../../../../pkg/qiao_generals/skills/skill_wei013_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI013。拼点发起、点数与胜负判定见主记录[拼点 WEI013](pindian.md#wei013-1)；本页只展开结果后的伤害与用牌侧。
- **实现与接口**：拼点赢→对手为来源、对其攻击范围内由你选择的角色造成 1 点伤害；没赢（含平局／空结果）→对手视为对你使用【杀】（`extra = true` 不计次数、显式目标策略）。赢的伤害来源与没赢的用牌都按真实使用数据结算，不重复用牌。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖驱虎赢（伤害来源为对手；该用例以测试桩固定拼点结果，属输入夹具）与驱虎平局（双方各出一张同点数牌经官方回复队列完成拼点，随后对手视为对发动者使用【杀】，验证恰好一次真实使用、来源为拼点对手、目标为发动者、发动者受伤而对手不受伤），见[共享验证证据](verification-evidence.md#wei_active)。
- **未完成与边界**：若后续改动技能内嵌使用流程，需重跑并重新核对请求消费顺序；客户端拼点与目标选择未人工验收。

### 蜀

<a id="shu003-1"></a>
#### 咆哮（SHU003 张飞）

- **标识与依据**：`qiao__skill_shu003_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu003_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU003。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L3712)。

> 锁定技，你使用【杀】无次数限制；你于一回合内使用第二张【杀】时，你摸一张牌。

- **实现与接口**：targetmod 提供状态型次数上限豁免；服务端真实 UseCard 事件历史统计整回合第二张杀，包含得技前和不计次数的使用。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu004-2"></a>
#### 空城（SHU004 诸葛亮）

- **标识与依据**：`qiao__skill_shu004_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu004_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU004。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L3734)。

> 主将技（☯️-1），当你失去手牌后，若你没有手牌，你可以令【杀】和【决斗】对你无效，直到你下次摸牌。

- **实现与接口**：主将技配将贡献减一。失去手牌后空手可建立公开的「空城」状态，模式级将【杀】或【决斗】对其设为无效，到下次摸牌前清理。普通获得牌不结束状态，仍可成为目标。
- **验证依据**：[shu_phases.lua](../../../../tests/shu_phases.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu005-2"></a>
#### 突阵（SHU005 赵云）

- **标识与依据**：`qiao__skill_shu005_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu005_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU005。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L3763)。

> 当你对其他角色使用的红色牌被其抵消后，你可以对另一名其他角色造成1点伤害。

- **实现与接口**：CardEffectCancelledOut 关联真实响应 UseCard 确认抵消者；只在目标本人抵消红色牌时选择另一名其他角色造成伤害，不按响应牌当前持有者判断。
- **验证依据**：[shu_effects.lua](../../../../tests/shu_effects.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。目标自己无懈的代表路径尚未专项验证。

<a id="shu006-1"></a>
#### 马术（SHU006 马超）

- **标识与依据**：`qiao__skill_shu006_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu006_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU006。同一技能来源另含 QUN008 庞德、QUN013 马腾、QUN027 韩遂；逐将链接复用本锚点。 此运行时 ID 对应 SHU006 马超、QUN008 庞德、QUN013 马腾、QUN027 韩遂、SHU019 马岱 的同文技能。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2687)。

> 锁定技，你计算与其他角色的距离-1。

- **实现与接口**：distance 修正持有者至其他角色的距离减一，不修改反方向距离。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu006-2"></a>
#### 铁骑（SHU006 马超）

- **标识与依据**：`qiao__skill_shu006_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu006_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU006。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L3789)。

> 当你使用【杀】指定一个目标后，你可以令其一张武将牌本回合非锁定技失效，你判定，除非其展示手牌并弃置结果花色的所有牌，否则其不能响应此【杀】。

- **实现与接口**：指定杀目标后按主副位置失效非锁定将牌技能，暗将仅展示位置；模式级 invalidity 动态按所选位置判断，回合末自动清理；先失效后判定，目标展示手牌并弃结果花色全部手牌才可响应。
- **验证依据**：[shu_tieqi.lua](../../../../tests/shu_tieqi.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu008-1"></a>
#### 烈勇（SHU008 黄忠）

- **标识与依据**：`qiao__skill_shu008_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu008_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU008。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L3827)。

> 锁定技，你的攻击范围+X（X为你已损失体力值，至少为1）；当你使用【杀】指定手牌数小于等于你或体力值大于等于你的目标后，你令此【杀】不能被其响应或对其伤害+1。

- **实现与接口**：攻击范围加 max(已损失体力,1)；逐目标任选不可响应或加伤；加伤记录在本次使用中，由模式 shu_lieyong_bonus 持续处理，不因失技或一次结算而消失。
- **验证依据**：[shu_effects.lua](../../../../tests/shu_effects.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu013-1"></a>
#### 享乐（SHU013 刘禅）

- **标识与依据**：`qiao__skill_shu013_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu013_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU013。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L3938)。

> 锁定技，当你成为【杀】的目标后，你令使用者选择一项：1.弃置一张基本牌；2.此【杀】对你无效。

- **实现与接口**：TargetConfirmed 由杀使用者选择自行弃一张基本牌或此杀对刘禅无效，弃牌操作者保留为使用者，只影响当前目标。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

### 吴

<a id="wu006-2"></a>
#### 流离（WU006 大乔）

- **标识与依据**：运行时 ID `qiao__skill_wu006_2`；源码 [skill_wu006_2.lua](../../../../pkg/qiao_generals/skills/skill_wu006_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU006。同将国色见[转化与生成用牌](conversion.md#wu006-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L6128)。

> 当你成为其他角色使用【杀】的目标时，你可以弃置一张牌并将此【杀】转移给攻击范围内的另一名其他角色。

- **实现与接口**：先完成合法弃牌与目标选择再支付费用；取消目标不弃牌。以 `inMyAttackRange` 的 `excludeIds` 预测弃武器／坐骑后的范围，排除已有目标，通过 AimData 取消当前目标并加入新目标。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖流离真实转移与取消不付费。
- **未完成与边界**：复杂改目标与范围组合未穷举；客户端选牌与目标转移未人工验收。

<a id="wu007-1"></a>
#### 谦逊（WU007 陆逊）

- **标识与依据**：运行时 ID `qiao__skill_wu007_1`；源码 [skill_wu007_1.lua](../../../../pkg/qiao_generals/skills/skill_wu007_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU007。同将度势见[转化与生成用牌](conversion.md#wu007-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L6146)。

> 锁定技，你每回合首次成为锦囊牌的目标时，若此牌有未指定的合法目标，取消之。

- **实现与接口**：包括自己使用的锦囊。首次成为锦囊目标时，存在未指定的合法目标才进入技能发动并取消自身；没有此类目标时由刷新监听记录首次，不发出技能提示或战报。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖谦逊。
- **未完成与边界**：无目标锦囊等边缘牌型未逐项验证；客户端取消提示未人工验收。

<a id="wu012-1"></a>
#### 天义（WU012 太史慈，分记录）

- **标识与依据**：运行时 ID `qiao__skill_wu012_1`；源码 [skill_wu012_1.lua](../../../../pkg/qiao_generals/skills/skill_wu012_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU012。拼点发起与胜负判定见主记录[拼点 WU012](pindian.md#wu012-1)；本页只展开持续用杀修正。
- **实现与接口**：赢后本回合无距离、多目标与额外出杀由静态模式技能读取公开中性标记；没赢包括平局，本回合禁用【杀】。已确定的增益／禁用不因失去天义提前结束，次数增益按锁定杀接口的 `HistoryPhase` 查询。天义可用性使用客户端安全房间访问。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖真实拼点、平局、失技持续与真实 `ClientPlayer`，见[共享验证证据](verification-evidence.md#wu_damage)。
- **未完成与边界**：客户端拼点与用杀次数提示未人工验收；复杂多目标／改目标组合未穷举。

<a id="wu016-1"></a>
#### 短兵（WU016 丁奉）

- **标识与依据**：运行时 ID `qiao__skill_wu016_1`；源码 [skill_wu016_1.lua](../../../../pkg/qiao_generals/skills/skill_wu016_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU016。同将奋迅见[本页](#wu016-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L6359)。

> 你使用【杀】可以多指定一名距离1的角色为目标。当你使用【杀】指定距离1的角色为目标后，此牌需多一张【闪】才能被其抵消。

- **实现与接口**：追加目标通过 `ExtraTargets.candidates` 按距离一及其他角色筛选，回复后用相同条件复核。对距离一目标增加闪数的第二效果为必然效果，通过 `AimData:setResponseTimes` 接到真实响应流程。
- **验证依据**：[qun_cards.lua](../../../../tests/qun_cards.lua) 检查距离一但在攻击范围外时的额外目标；[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖短兵扩目标及一闪不足抵消。
- **未完成与边界**：客户端双闪响应与目标扩展未人工验收。

<a id="wu016-2"></a>
#### 奋迅（WU016 丁奉）

- **标识与依据**：运行时 ID `qiao__skill_wu016_2`；源码 [skill_wu016_2.lua](../../../../pkg/qiao_generals/skills/skill_wu016_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU016。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L6360)。

> 出牌阶段限一次，你可以弃置一张牌并指定一名其他角色，你与该角色本回合的距离视为1。

- **实现与接口**：使用中性 `qiao_wu_fenxun_target-turn` 标记与[模式距离技能](../../../../pkg/qiao_mode/skills/wu_distance_effects.lua)；失去来源技能不提前终止，也不随来源前缀被交换机制迁移。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖奋迅失技后持续。
- **未完成与边界**：客户端距离提示未人工验收。

### 群

<a id="qun002-1"></a>
#### 无双（QUN002 吕布）

- **标识与依据**：运行时 ID `qiao__skill_qun002_1`；源码 [skill_qun002_1.lua](../../../../pkg/qiao_generals/skills/skill_qun002_1.lua)。规则见[吕布规范](../../../rules/generals/qun002-lvbu.md)。同将虓猛见[本页](#qun002-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2565)。

> 锁定技，你使用【杀】指定目标后，此牌需多一张【闪】才能抵消；你指定或成为【决斗】的目标后，对方每次需打出多一张【杀】。

- **实现与接口**：`fk.TargetSpecified` 分别接【杀】与【决斗】；【杀】目标在当前 `AimData:getResponseTimes` 上累加一张【闪】，【决斗】对方每次多打出一张【杀】。按增量累加，不写死为 2；与短兵等增量叠加。
- **验证依据**：已执行 [qun_cards.lua](../../../../tests/qun_cards.lua) 的 `testWushuangStacksWithDuanbing`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：已写入响应数在暗置／失技后的持续只由公共 AimData 语义保证；客户端响应提示未人工验收。

<a id="qun002-2"></a>
#### 虓猛（QUN002 吕布）

- **标识与依据**：运行时 ID `qiao__skill_qun002_2`；源码 [skill_qun002_2.lua](../../../../pkg/qiao_generals/skills/skill_qun002_2.lua)。规则见[吕布规范](../../../rules/generals/qun002-lvbu.md)与[指定额外目标](../extra-targets.md)。同将无双见[本页](#qun002-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2566)。

> 每回合限一次，当你使用【决斗】时，当前回合角色可以为此牌多指定至多两个与你势力不同的目标。

- **实现与接口**：`fk.AfterCardTargetDeclared` 后由当前回合角色为本次【决斗】追加至多两名“与吕布势力不同”的其他角色。候选与回复复核均走 `ExtraTargets.candidates`，以明确的势力条件替换该牌的默认目标条件。每回合限一次。
- **验证依据**：[qun_cards.lua](../../../../tests/qun_cards.lua) 覆盖实体手牌【决斗】的选人请求，以及转化【决斗】由非吕布的当前回合角色增目标。
- **未完成与边界**：原反馈对局的势力与发动记录未知，客户端原场景待复测。

<a id="qun003-1"></a>
#### 离间（QUN003 貂蝉）

- **标识与依据**：运行时 ID `qiao__skill_qun003_1`；源码 [skill_qun003_1.lua](../../../../pkg/qiao_generals/skills/skill_qun003_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN003。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2585)。

> 出牌阶段限一次，你可以弃置一张牌并选择两名其他男性角色，令其中一名角色视为对其中另一名角色使用一张【决斗】（不可被抵消）。

- **实现与接口**：主动技弃置一张自己的牌并选两名其他男性；由后选者视为对先选者使用正式【决斗】，使用者不是貂蝉。目标按 `card_use_targets` 显式策略声明；“不可被抵消”使用 `AimData:setUnoffsetable`／`UseCardData.unoffsetableList` 排除【无懈可击】响应，不把决斗内打出【杀】也改成不可响应。
- **验证依据**：已执行 [qun_basic.lua](../../../../tests/qun_basic.lua) 的 `testLijianFormalDuelUsedBySelectedMale`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：客户端选人／无懈窗口未人工验收；决斗内复杂响应组合未专项覆盖。

<a id="qun007-2"></a>
#### 乱武（QUN007 贾诩）

- **标识与依据**：运行时 ID `qiao__skill_qun007_2`；源码 [skill_qun007_2.lua](../../../../pkg/qiao_generals/skills/skill_qun007_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN007。同将完杀见[伤害、体力与死亡](damage.md#qun007-1)，帷幕见[本页](#qun007-3)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2666)。

> 限定技，出牌阶段，你可以令所有其他角色各选择一项：1.使用一张【杀】（须指定其距离最近的另一名角色为目标）；2.失去1点体力。

- **实现与接口**：限定技，出牌阶段从当前回合角色起逆时针逐人处理其他角色；先按全体其他角色算最近距离，再用 `card_use_targets` 的显式策略要求所选【杀】目标至少包含一名最近且合法角色，最后按通常【杀】流程真实使用一张【杀】，不能改选较远目标，也不是“视为使用”。
- **验证依据**：已执行 [qun_cards.lua](../../../../tests/qun_cards.lua) 的 `testLuanwuRealSlashIncludesNearest`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：无合法【杀】目标、最近目标死亡／失技、多目标上限等排列未逐项覆盖；客户端选目标未人工验收。

<a id="qun007-3"></a>
#### 帷幕（QUN007 贾诩）

- **标识与依据**：运行时 ID `qiao__skill_qun007_3`；源码 [skill_qun007_3.lua](../../../../pkg/qiao_generals/skills/skill_qun007_3.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN007。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2667)。

> 锁定技，你成为黑色锦囊牌的目标时，取消之。

- **实现与接口**：锁定技，`fk.TargetConfirming` 时若目标为贾诩、牌为黑色锦囊，则 `data:cancelTarget(player)` 取消该目标；不改成禁止选取，也不额外用 `BeforeCardsMove` 拦截黑色延时锦囊移入判定区。
- **验证依据**：已执行 [qun_judgement.lua](../../../../tests/qun_judgement.lua) 的 `testWeimuCancelsOnlyBlackTrickTarget`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：多目标黑色锦囊、其他角色同时改目标等组合未专项覆盖；客户端提示未人工验收。

<a id="qun008-2"></a>
#### 猛撼（QUN008 庞德）

- **标识与依据**：运行时 ID `qiao__skill_qun008_2`；源码 [skill_qun008_2.lua](../../../../pkg/qiao_generals/skills/skill_qun008_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN008。同将马术见[本页马术条目](#shu006-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2688)。

> 当你使用【杀】指定一个目标后，你可以弃置其一张牌，若为基本牌，则其获得此【杀】，否则此【杀】不能被其响应。

- **实现与接口**：`fk.TargetSpecified` 后弃目标一张手牌或装备；弃到基本牌时只把本次【杀】可获得的实体牌交给目标，不终止已声明的用牌；非基本牌时仅该目标 `AimData:setDisresponsive`，不影响其他目标。
- **验证依据**：已执行 [qun_basic.lua](../../../../tests/qun_basic.lua) 的 `testMenghanBasicObtainsSlashAndUseContinues`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：转化【杀】、无实体牌及多目标后续结算未逐项覆盖；客户端交互未人工验收。

<a id="qun018-1"></a>
#### 祸水（QUN018 邹氏）

- **标识与依据**：运行时 ID `qiao__skill_qun018_1`；源码 [skill_qun018_1.lua](../../../../pkg/qiao_generals/skills/skill_qun018_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN018。同将倾城见[辅助与牌资源](support.md#qun018-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2860)。

> 你的回合内，其他角色不能明置其武将牌；出牌阶段，你可以弃置一张黑色牌并暗置一名武将牌均明置的其他角色一张武将牌，然后其交给你一张牌。

- **实现与接口**：主动段未写限一次，每阶段可反复发动；弃一张自己的黑色牌，选一名双将均明置的其他角色暗置其一张武将牌，再令其交给自己一张牌。暗置复用公共 `doHideGeneral` 的主副将选择与来源迁移。被动“回合内其他角色不能明置”不在技能本体重复实现，由 [qun_control_rule](../../../../pkg/qiao_mode/skills/qun_control_rule.lua) 与 [util/qun_control](../../../../pkg/qiao_generals/util/qun_control.lua) 按持有者＋技能来源维护，失技／暗置只撤销本条来源。
- **验证依据**：已执行 [qun_control.lua](../../../../tests/qun_control.lua) 的 `testHuoshuiRevealProhibitionFollowsItsOwnSource`、`testHuoshuiActiveHidesGeneralAndTakesCardTwice`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：死亡翻面不按明置拦截、其他禁明置来源并存、双将明暗组合未穷举；客户端交互未人工验收。

### 晋

<a id="jin012-1"></a>
#### 慈威（JIN012 羊徽瑜）

- **标识与依据**：运行时 ID `qiao__skill_jin012_1`；源码 [skill_jin012_1.lua](../../../../pkg/qiao_generals/skills/skill_jin012_1.lua)。规则见[羊徽瑜规范](../../../rules/generals/jin012-yanghuiyu.md)。同将弘训见[辅助与牌资源](support.md#jin012-2)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L1748)。

> 其他角色于其回合内使用第二张牌时，你可以弃置一张牌，若其使用牌为基本牌或普通锦囊牌，则令此牌对任意个目标无效，否则其横置。

- **实现与接口**：全局监听 `fk.AfterCardUseDeclared`，只在该事件使用者就是当前回合角色、且其为其他角色时检查。第二张牌按本回合 `GameEvent.UseCard` 事件计数，包含响应中的实际使用和装备使用；纯“打出”只生成 `RespondCard`，不计入。发动消耗为弃置自己一张手牌或装备牌（`askToDiscard(skip)`＋`throwCard`）。若此牌为基本牌或普通锦囊，允许选择任意个当前目标（含零个），写入 `UseCardData.nullifiedTargets`，由引擎按目标跳过响应与效果，不 `removeTarget`、不取消整张牌；装备牌或延时锦囊则对使用者调用 `setChainState(true)`，不翻面、不重置。锁定上游 `hegemony/pkg/jin_zqdl/skills/ciwei.lua` 的慈威是旧版“取消整张牌所有目标”，效果不同且未复用；本实装采用引擎目标级 `nullifiedTargets` 字段。
- **验证依据**：[jin_basic.lua](../../../../tests/jin_basic.lua) 以真实 `Turn`／`useCard`／`responseCard` 验证：第一张装备后纯打出【闪】不计，第二张【杀】的目标无效且不受伤；普通锦囊【决斗】目标无效；第二张装备与延时锦囊均横置使用者且延时牌正常进入判定区；每例弃置一张牌。本批 `jin_basic` 套件合计 19/19。
- **未完成与边界**：未应用开发适配的本体人工交互验收尚未执行；在“使用时”之后由其他技能追加的目标不进入本次无效名单，客户端多目标选择未人工验收。

<a id="jin003-2"></a>
#### 挟征（JIN003 司马昭）

- **标识与依据**：运行时 ID `qiao__skill_jin003_2`；源码 [skill_jin003_2.lua](../../../../pkg/qiao_generals/skills/skill_jin003_2.lua)。规则见[司马昭规范](../../../rules/generals/jin003-simazhao.md)。同将昭然见[辅助与牌资源](support.md#jin003-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L1527)。

> 限定技，出牌阶段，你可以令一名角色需将一张基本牌当【杀】对你指定的角色使用，否则你获得其所有手牌，交给其等同其体力值的牌。

- **实现与接口**：限定技，`active` 选两名不同角色：第一名被要求将一张基本牌当【杀】对第二名实际使用，第二名由效果显式指定；走 `card_use_targets` 的 `C.useVirtualCard`＋`C.explicit({ other_roles = true })`，移除默认攻击距离并把实际目标固定为第二名角色。被要求者在可取消的 `askToCards` 请求中选一张基本手牌或拒绝；拒绝、无基本手牌或无法合法用出时，司马昭一次获得其所有手牌，再交给其等于其当前体力值张自己的牌。用出后即使被闪也不进入惩罚。
- 罚则交牌时收牌人已确定。`askToCards` 仅要求选足手牌或装备，不再要求选自己。回归从客户端选择牌、确认和服务端实际移交验证。
- **验证依据**：[jin_reactive.lua](../../../../tests/jin_reactive.lua) 覆盖基本牌当杀与拒绝惩罚，并含远距离反制/原来源/非原来源分支；6/6（1.379s）通过，见[共享验证证据](verification-evidence.md#jin-reactive)。
- **未完成与边界**：目标死亡、无牌可给、转化基本牌、客户端两次选人未人工验收。

<a id="jin013-2"></a>
#### 克清（JIN013 王濬）

- **标识与依据**：运行时 ID `qiao__skill_jin013_2`；源码 [skill_jin013_2.lua](../../../../pkg/qiao_generals/skills/skill_jin013_2.lua)。规则见[王濬规范](../../../rules/generals/jin013-wangjun.md)。同将乘流见[伤害、体力与死亡](damage.md#jin013-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L1770)。

> 出牌阶段限一次，你可以选择一名已横置的其他角色，直到你再次发动该技能或死亡：当其使用或打出牌时，若其横置，其弃置一张牌。

- **实现与接口**：出牌阶段限一次，`active` 选一名已横置其他角色。目标身上以表标记记录来源 id；首次发动时按需安装房间级延迟监听器 `#qiao__skill_jin013_2_effect`，分别监听 `fk.CardUsing` 与 `fk.CardResponding`：目标横置且来源仍存活时，由目标自己 `askToDiscard`（已执行弃牌）一张手牌/装备，不双计、不每回合限一次。失去克清不撤销监听器；再次发动替换旧目标；来源死亡由 `fk.Death` 清理，监听器亦在下次触发时惰性清理已死来源。
- **验证依据**：[jin_chain.lua](../../../../tests/jin_chain.lua) 覆盖发动、首次弃牌、失技后继续触发、来源不再存活后不触发；定向 6/6，见[共享验证证据](verification-evidence.md#jin-chain)。真实 `killPlayer` 因测试夹具先游戏结束，死亡用例改用真实 `dead` 状态后继续真实用牌，`fk.Death` 清理链路待独立夹具。
- **未完成与边界**：真实死亡事件、跨重连监听器、多个来源/目标、客户端弃牌交互未人工验收。

<a id="jin015-1"></a>
#### 前驱（JIN015 石苞）

- **标识与依据**：运行时 ID `qiao__skill_jin015_1`；源码 [skill_jin015_1.lua](../../../../pkg/qiao_generals/skills/skill_jin015_1.lua)。规则见[石苞规范](../../../rules/generals/jin015-shibao.md)与[应变规范](../../../rules/adaptation.md)。同将无其他已实装技能。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L1811)。

> 与你势力相同的角色准备阶段，你可以使用一张无距离限制的【杀】<助战→弃置目标角色装备区里的一张牌>，然后若此【杀】造成伤害，当前回合角色获得此【杀】并摸一张牌。

- **实现与接口**：全局监听同势力角色（含自己）准备阶段，石苞可用 `card_use_targets` 的 `askToUseCard` 选择一张【杀】的真实使用数据（允许合法转化，不凭空生成杀）；`C.bypassDistance` 只取消距离限制，`extra_data.bypass_times/extraUse` 不占通常出杀次数，随后 `C.useCard` 真实执行。本次使用附加〈助战→弃置目标角色装备区里的一张牌〉条目。`fk.CardUseFinished` 仅在此杀实际造成伤害时，由当前回合角色获得仍在处理区的实体材料并摸一张牌；无材料时不单方面摸牌。
- **验证依据**：[jin_adaptation.lua](../../../../tests/jin_adaptation.lua) 覆盖无距离真实用杀、助战弃目标装备、造成伤害后当前回合角色获得此杀并摸牌；应变定向 5/5；公共应变 25/25、`ignore_times` 14/14 属公共机制历史结果，不挪作本技能覆盖，见[共享验证证据](verification-evidence.md#jin-adaptation)。
- **未完成与边界**：未应用开发适配的本体交互未验；转化杀无实体材料、被闪、目标死亡与多来源同势力未单独覆盖。
