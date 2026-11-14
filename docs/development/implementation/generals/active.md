# 用牌目标与距离：跨势力技能实现与验证

本页是“用牌目标与距离”机制的主记录页：主动用牌、效果指定的额外／强制目标、目标的抵消与转移，以及距离计算修正；另含在主记录页已完整记录、此处只展开用牌侧的少量分记录。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。范围边界：以目标指定、目标转移、距离或响应限制为核心的技能；纯视为牌转换归[转化与生成用牌](conversion.md)，阶段跳过归[阶段与回合流程](phases.md)，拼点流程归[拼点](pindian.md)。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN005 | 何进 | [谋诛](#han005-1) |
| HAN008 | 伏皇后 | [求援](#han008-2) |
| HAN009 | 伏完 | [谋溃](#han009-1) |
| WEI010 | 徐晃 | [长驱](#wei010-2) |
| WEI011 | 曹仁 | [伪溃](#wei011-1) |
| WEI013 | 荀彧 | [驱虎](#wei013-1)（分记录；主记录见[拼点](pindian.md#wei013-1)） |
| WU006 | 大乔 | [流离](#wu006-2) |
| WU007 | 陆逊 | [谦逊](#wu007-1) |
| WU012 | 太史慈 | [天义](#wu012-1)（分记录；主记录见[拼点](pindian.md#wu012-1)） |
| WU016 | 丁奉 | [短兵](#wu016-1)、[奋迅](#wu016-2) |

## 技能条目

### 汉

<a id="han005-1"></a>
#### 谋诛（HAN005 何进）

- **标识与依据**：运行时 ID `hanjin__skill_han005_1`；源码 [skill_han005_1.lua](../../../../pkg/hanjin_generals/skills/skill_han005_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN005；用牌目标入口见[效果指定的用牌目标条件](../card-use-targets.md)。同将构难见[伤害、体力与死亡](damage.md#han005-2)。
- **实现与接口**：
  - 出牌阶段限一次（效果 `max_phase_use_time = 1`，自定义 `can_use` 内同时检查阶段次数）。
  - 目标只要求一名其他存活角色，不把“交牌能否执行”当作目标限制或何进消耗。交牌由被令角色选择一张手牌，再以 `moveCardTo(..., fk.ReasonGive, ...)` 交给何进；目标无手牌时交牌不执行，但继续“然后”的手牌比较与可执行效果。
  - 交牌后比较双方**当前手牌数**；仅当目标手牌数小于何进时，目标视为使用一张【杀】或【决斗】。使用入口为 `card_use_targets` 的 `askToUseVirtualCard`，目标由使用者按正常牌面目标条件选择，不添加技能指定的目标例外；虚拟牌默认 `extraUse`，不计通常次数。
  - 使用后遍历实际目标，若任一目标与何进势力相同（`compareKingdomWith`），使用者弃置一张牌；无牌则不弃。非法／过期交牌回复会在服务端按当前手牌复核，不移动不属于目标的牌。
- **验证依据**：[han005_hejin.lua](../../../../tests/han005_hejin.lua) 覆盖谋诛异势力目标（交牌后手牌数小于何进、视为使用【杀】、目标为魏不弃牌、何进得到交来的牌）与同势力目标（相邻 p2 明确为汉，p3 对 p2 使用【杀】并真实造成 1 点伤害，p3 交牌后再弃掉剩余手牌）。历史定向 3/3，见[共享验证证据](verification-evidence.md#han005_hejin)。
- **未完成与边界**：目标交牌后若没有任何合法【杀】／【决斗】目标，`askToUseVirtualCard` 返回空，后续弃牌也不发生；这是正常牌面条件的结果，不额外补问。客户端选目标／弃牌界面未人工验收。

<a id="han008-2"></a>
#### 求援（HAN008 伏皇后）

- **标识与依据**：运行时 ID `hanjin__skill_han008_2`；源码 [skill_han008_2.lua](../../../../pkg/hanjin_generals/skills/skill_han008_2.lua)。规则见[伏皇后规范](../../../../rules/generals/han008-fuhuanghou.md)、[牌的使用相关事件](../../../../rulebook/events/use-card.md)与[指定额外目标](../../../../rules/extra-targets.md)。同将惴恐见[拼点](pindian.md#han008-1)。
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

- **标识与依据**：运行时 ID `hanjin__skill_han009_1`；源码 [skill_han009_1.lua](../../../../pkg/hanjin_generals/skills/skill_han009_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN009、[牌的使用相关事件](../../../../rulebook/events/use-card.md)与[取消](../../../../rulebook/terms/resolution-terms/cancel.md)。
- **实现与接口**：
  - `TargetSpecified` 是每个目标分别生成的时机；谋溃在本次 `UseCardData` 上写入已发动标记，因此一张【杀】只发动一次，不会为每个目标重复询问。
  - 发动者在本次【杀】的目标列表中选择**一个**目标，再通过 `askToChoices` 选择一至两项：摸一张、弃置该目标一张牌。执行顺序固定为先摸后弃。
  - 双选时在 use 上记录被选目标 id 与“双选”标记；抵消监听器只在 `CardEffectCancelledOut` 的当前目标正是该目标时触发，其他目标抵消不触发。触发后由抵消者选择并弃置伏完一张手牌／装备牌。本次发动与反弃绑定改挂 `UseCardData` 字段，修复双选后抵消不触发反弃。
  - 反弃监听器是模块缓存的房间级对象，使用本次 use 已建立的标记，不依赖伏完当前是否仍有谋溃；失技／暗置后双选后续仍结算。无“挂载”式额外技能，也没有为每个目标复制一套谋溃效果。
- **验证依据**：[han009_fuwan.lua](../../../../tests/han009_fuwan.lua) 覆盖单选摸牌、单选弃牌且不触发反弃；双选后被选目标用【闪】抵消、弃置伏完一张牌；多目标【杀】中未被选中的另一目标抵消时不反弃；一张【杀】只发动一次。历史记录见[共享验证证据](verification-evidence.md#han009_fuwan)。
- **未完成与边界**：未执行真实客户端选目标、勾选一至两项、选择抵消者所弃之牌的交互；未覆盖目标在结算中死亡／失去所有牌、同一目标重复抵消、无牌可反弃、技能使用后中途失技的独立排列；未验证武将交换。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han009_fuwan.lua --timeout 120`（当时标为待基础组执行，未产生该文件单独输出，后由默认套件覆盖）。

### 魏

<a id="wei010-2"></a>
#### 长驱（WEI010 徐晃）

- **标识与依据**：运行时 ID `hanjin__skill_wei010_2`；源码 [skill_wei010_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei010_2.lua)。事实层 [wei_history.lua](../../../../pkg/hanjin_mode/rules/wei_history.lua) 与 [wei_damage_history.lua](../../../../pkg/hanjin_mode/skills/wei_damage_history.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI010。同将断粮见[转化与生成用牌](conversion.md#wei010-1)。
- **实现与接口**：
  - `targetmod.bypass_distances` 只对公开标记中“本回合未被该来源伤害过”的目标返回真，不修改距离本身；事实由模式记录器负责，技能本身不再记录。
  - 不使用私有 `room:getTag`。记录器把“目标 id 集合”写入同步玩家标记 `hanjin_wei_damage_targets`（`room:setPlayerMark`），客户端与服务端 `targetmod` 读同一公开数据，不在客户端回调里读取 server history；每回合开始清空，仅在真实伤害（`data.damage > 0`）后刷新。
  - `mode.lua` 在 `logic:start` 前安装记录器，因此与长驱武将是否已选、明置或之后换将无关。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖不授予长驱时模式记录器仍写入同步标记、距离不变、`TurnStart` 清空，以及 `ClientPlayer:getTableMark` 读取；历史 6/6。
- **未完成与边界**：真实客户端 targetmod 的 UI 距离提示未人工验证。记录器按 `mode.lua` 的 `logic:start` 安装；若其他模式复用该 logic 但不应记录，需要按模式再限定。

<a id="wei011-1"></a>
#### 伪溃（WEI011 曹仁）

- **标识与依据**：运行时 ID `hanjin__skill_wei011_1`；源码 [skill_wei011_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei011_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI011。同将励战见[辅助与牌资源](support.md#wei011-2)。
- **实现与接口**：
  - 出牌阶段限一次；失去 1 点体力→私看目标手牌；有【闪】则按公共 `explicit` 目标策略视为【杀】，距离固定只对“发动者 → 目标”单向生效（`-turn` 标记）；否则弃置其一张手牌。`can_use` 要求 `player.hp >= 1`。
  - 私看使用真实 `room:viewCards(player, { cards = hand, skill_name = ..., prompt = ... })`；`room:showCards(hand, player)` 是全体展示，不能用于私看。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖伪溃无【闪】时真实私看后弃置目标一张手牌、有【闪】时真实【杀】分支（私看收件人与牌集、恰好一次来源为发动者、目标受伤与距离标记）、失去体力；历史 6/6。测试夹具的根因与修复见[共享验证证据](verification-evidence.md#魏包白板夹具)。
- **未完成与边界**：伪溃【闪】分支已按白板夹具与官方回复队列恢复并通过；若后续改动技能内嵌使用流程，需重跑并重新核对请求消费顺序。按“你计算与其距离视为1”实现为发动者至目标的单向固定距离，该方向已有明确文本依据，不列为待裁定事项。真实客户端 targetmod 的 UI 距离提示未人工验证。

<a id="wei013-1"></a>
#### 驱虎（WEI013 荀彧，分记录）

- **标识与依据**：运行时 ID `hanjin__skill_wei013_1`；源码 [skill_wei013_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei013_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI013。拼点发起、点数与胜负判定见主记录[拼点 WEI013](pindian.md#wei013-1)；本页只展开结果后的伤害与用牌侧。
- **实现与接口**：拼点赢→对手为来源、对其攻击范围内由你选择的角色造成 1 点伤害；没赢（含平局／空结果）→对手视为对你使用【杀】（`extra = true` 不计次数、显式目标策略）。赢的伤害来源与没赢的用牌都按真实使用数据结算，不重复用牌。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖驱虎赢（伤害来源为对手；该用例以测试桩固定拼点结果，属输入夹具）与驱虎平局（双方各出一张同点数牌经官方回复队列完成拼点，随后对手视为对发动者使用【杀】，验证恰好一次真实使用、来源为拼点对手、目标为发动者、发动者受伤而对手不受伤）；历史 6/6，见[共享验证证据](verification-evidence.md#wei_active)。
- **未完成与边界**：若后续改动技能内嵌使用流程，需重跑并重新核对请求消费顺序；客户端拼点与目标选择未人工验收。

### 吴

<a id="wu006-2"></a>
#### 流离（WU006 大乔）

- **标识与依据**：运行时 ID `hanjin__skill_wu006_2`；源码 [skill_wu006_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu006_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU006。同将国色见[转化与生成用牌](conversion.md#wu006-1)。
- **实现与接口**：先完成合法弃牌与目标选择再支付费用；取消目标不弃牌。以 `inMyAttackRange` 的 `excludeIds` 预测弃武器／坐骑后的范围，排除已有目标，通过 AimData 取消当前目标并加入新目标。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖流离真实转移与取消不付费；历史 12/12。
- **未完成与边界**：复杂改目标与范围组合未穷举；客户端选牌与目标转移未人工验收。

<a id="wu007-1"></a>
#### 谦逊（WU007 陆逊）

- **标识与依据**：运行时 ID `hanjin__skill_wu007_1`；源码 [skill_wu007_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu007_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU007。同将度势见[转化与生成用牌](conversion.md#wu007-2)。
- **实现与接口**：包括自己使用的锦囊；首次成为锦囊目标时按未指定合法目标判断取消自身；不取消整张牌。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖谦逊；历史 12/12。
- **未完成与边界**：无目标锦囊等边缘牌型未逐项验证；客户端取消提示未人工验收。

<a id="wu012-1"></a>
#### 天义（WU012 太史慈，分记录）

- **标识与依据**：运行时 ID `hanjin__skill_wu012_1`；源码 [skill_wu012_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu012_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU012。拼点发起与胜负判定见主记录[拼点 WU012](pindian.md#wu012-1)；本页只展开持续用杀修正。
- **实现与接口**：赢后本回合无距离、多目标与额外出杀由静态模式技能读取公开中性标记；没赢包括平局，本回合禁用【杀】。已确定的增益／禁用不因失去天义提前结束，次数增益按锁定杀接口的 `HistoryPhase` 查询。天义可用性使用客户端安全房间访问。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖真实拼点、平局、失技持续与真实 `ClientPlayer`；历史 22/22，见[共享验证证据](verification-evidence.md#wu_damage)。
- **未完成与边界**：客户端拼点与用杀次数提示未人工验收；复杂多目标／改目标组合未穷举。

<a id="wu016-1"></a>
#### 短兵（WU016 丁奉）

- **标识与依据**：运行时 ID `hanjin__skill_wu016_1`；源码 [skill_wu016_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu016_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU016。同将奋迅见[本页](#wu016-2)。
- **实现与接口**：可选增加距离一目标；对距离一目标增加闪数的第二效果为必然效果，显式 `on_cost = Util.TrueFunc`，通过 `AimData:setResponseTimes` 接到真实响应流程。遗漏此项曾使引擎默认询问，导致未回复时双闪不生效；真实一闪不足抵消回归已修复。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖短兵扩目标及一闪不足抵消；历史 12/12。
- **未完成与边界**：客户端双闪响应与目标扩展未人工验收。

<a id="wu016-2"></a>
#### 奋迅（WU016 丁奉）

- **标识与依据**：运行时 ID `hanjin__skill_wu016_2`；源码 [skill_wu016_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu016_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU016。
- **实现与接口**：使用中性 `hanjin_wu_fenxun_target-turn` 标记与[模式距离技能](../../../../pkg/hanjin_mode/skills/wu_distance_effects.lua)；失去来源技能不提前终止，也不随来源前缀被交换机制迁移。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖奋迅失技后持续；历史 12/12。
- **未完成与边界**：客户端距离提示未人工验收。
