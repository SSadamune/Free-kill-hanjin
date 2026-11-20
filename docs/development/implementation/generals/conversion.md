# 转化与生成用牌：跨势力技能实现与验证

本页是“转化与生成用牌”机制的主记录页：视为牌／view-as 转换、以转化结果使用或打出、以及由技能生成并真实使用一张牌的技能。不替代规则条文，规则冲突时以 `docs/rules/` 与 `rulebook/` 为准。范围边界：技能须以“把某些牌当作另一张牌使用／打出”或“生成一张虚拟牌并真实使用”为核心；仅是阶段时机触发的技能归[阶段与回合流程](phases.md)，仅影响目标与距离的归[用牌目标与距离](active.md)。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN004 | 张让 | [滔乱](#han004-1) |
| HAN006 | 王允 | [定著](#han006-2) |
| HAN012 | 蔡邕 | [博通](#han012-2) |
| HAN016A | 刘宠 | [劲弩](#han016a-1) |
| WEI007 | 甄姬 | [倾国](#wei007-1) |
| WEI010 | 徐晃 | [断粮](#wei010-1) |
| SHU001 | 刘备 | [仁德](#shu001-1) |
| SHU002 | 关羽 | [武圣](#shu002-1) |
| SHU005 | 赵云 | [龙胆](#shu005-1) |
| SHU010 | 庞统 | [连环](#shu010-1) |
| SHU011 | 诸葛亮 | [八阵](#shu011-1) |
| SHU011 | 诸葛亮 | [火计](#shu011-2) |
| SHU011 | 诸葛亮 | [看破](#shu011-3) |
| WU002 | 甘宁 | [奇袭](#wu002-1) |
| WU006 | 大乔 | [国色](#wu006-1) |
| WU007 | 陆逊 | [度势](#wu007-2) |
| QUN004 | 袁绍 | [乱击](#qun004-1) |
| QUN005 | 颜良&文丑 | [双雄](#qun005-1) |
| QUN015 | 纪灵 | [双刃](#qun015-1) |
| QUN017 | 潘凤 | [狂斧](#qun017-1) |
| QUN027 | 韩遂 | [骁逆](#qun027-2) |
| JIN001 | 司马炎 | [兴图](#jin001-2) |
| JIN005 | 羊祜 | [柔克](#jin005-1) |
| JIN009 | 司马懿 | [骤霆](#jin009-2) |
| JIN010 | 张春华 | [伤逝](#jin010-1) |

## 技能条目

### 汉

<a id="han004-1"></a>
#### 滔乱（HAN004 张让）

- **标识与依据**：运行时 ID `qiao__skill_han004_1`；源码 [skill_han004_1.lua](../../../../pkg/qiao_generals/skills/skill_han004_1.lua)。规则见[滔乱专项裁定](../../../rules/generals/han004-zhangrang.md)与[标准武将表](../../../rules/standard-generals.md)汉区 HAN004。同一回合多次发动只结算一次的语义按用户 2026-11-13 确认的裁定，本页只记录实现与验证。
- **实现与接口**：
  - 统一使用 ViewAs：正常出牌阶段与合法「使用」窗口共用同一入口，无实体子牌，按正常牌面条件选择目标；正常出牌不绕过普通【杀】次数。
  - `view_as` 是客户端纯函数：只读取自身可见武将／本局公开标记，不调用 `player.room`，也不做服务端查询；克隆牌后把来源编号（1 主将／2 副将）写到 `card.qiaoTaoluanSource`。
  - 响应窗口只放行 `ReqUseCard` 的「使用」窗口（含回合外使用【闪】／【无懈】）；`enabled_at_response` 在 `cardResponsing = true` 的纯打出请求下固定返回 false。
  - 只有承载本技能的武将牌暗置且 `prohibitReveal` 允许时才可发动；已明置后 `hiddenSource` 返回 nil，不再发动。
  - `room:useSkill` 在 `before_use` 之前按技能名自动明置来源武将（`revealBySkillName`），因此 `before_use` 不能要求来源仍暗置；它只消费 `qiaoTaoluanSource`，核对编号对应武将已明置且确实承载本技能，不合法时返回技能名取消本次使用，避免伪造亮将发动。
  - 候选牌名按 `qiao_cards/data/reuse.lua` 的 `status == "reused"` 过滤，只取已实装、非衍生、非空壳的基本牌／普通锦囊，排除延时锦囊与装备。
  - 记录与结算在首次发动时安装为房间级延迟技能，不依附张让当前技能对象；明置导致技能替换后仍能收牌。以真实 `fk.TargetSpecified` 记录“本回合以此法使用牌指定过的其他角色”到 `-turn` 表标记，只由该牌的 `data.from` 一个 owner 处理，重复指定同一角色由 `addTableMarkIfNeed` 去重；每次真实宣告成功（`fk.AfterCardUseDeclared`）给发动者增加一次 `-turn` 发动计数，单次使用只计一次。
  - `fk.TurnEnd` 使用 refresh 而非询问发动的 trigger：结算必须自动发生，且房间级延迟技能无需再注册触发器名；房间 tag 防止重入，同一角色同一回合无论发动几次都只调用一次 `settle`，清空待结算计数后按玩家逐个处理。候选取本回合累计记录的指定目标并集；每名角色至多结算一次。`-turn` 标记由引擎 `clearHistory(Player.HistoryTurn)` 在回合末结算后清理。
  - 每次结算：选择至多三名候选（逆时针排序），依次询问每名仍有手牌者展示并交一张手牌；按实际得到牌的有效颜色统计红／黑，红多于黑时暗置自己一张可暗置武将（两张均明置时询问）；未得到的牌不额外补抽，无手牌角色跳过。
- **验证依据**：[han004_zhangrang.lua](../../../../tests/han004_zhangrang.lua) 覆盖暗置发动与回合末、回合外使用【闪】、已明置不可再发动、同回合两次发动只结算一次；历史定向 4/4，且默认全量 567/567 含该回归。命令与日期见[共享验证证据](verification-evidence.md#han004_zhangrang)。
- **未完成与边界**：发动资格不变——承载武将仍须暗置才能发动，首次发动后即明置；同回合两次发动只由测试专用效果制造暗置来覆盖结算语义，不代表正式对局中的额外发动途径。明置源、限一次暗置等边界未做完整场景映射；客户端选牌名、选目标、暗置选择未人工界面验证。

<a id="han006-2"></a>
#### 定著（HAN006 王允）

- **标识与依据**：运行时 ID `qiao__skill_han006_2`；源码 [skill_han006_2.lua](../../../../pkg/qiao_generals/skills/skill_han006_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN006；用牌目标策略见[效果指定的用牌目标条件](../card-use-targets.md)。同将连计见[伤害、体力与死亡](damage.md#han006-1)。
- **实现与接口**：
  - `Skill.DeputyPlace` 副将技；主将位不会获得该技能，界面与触发均不提供。
  - 记录的是本回合“得到过牌”的角色，不是当前手牌非空；得到后立即用掉／弃掉仍满足条件。共用[han_history.lua](../../../../pkg/qiao_generals/util/han_history.lua) 查询本回合实际发生的 `GameEvent.MoveCards`，按进入手牌区的牌张累计，装备区与当前手牌数不参与；不安装记录器，因此暗置、晚获得技能或技能失效不会漏掉此前得牌。
  - 出牌阶段结束时先询问发动；发动询问、得到过牌角色与另一名目标角色都在 `on_cost` 中选定并保存，随后才进入 SkillEffect 的明置／技能效果结算，避免先明置再选目标。
  - 由得到过牌的角色视为对指定角色使用【决斗】。目标条件使用汉晋公共显式目标策略，先校验再执行一次真实用牌，不重复结算。
- **验证依据**：[han_standard_pindian.lua](../../../../tests/han_standard_pindian.lua) 覆盖得到过牌后随即失去仍可作候选、仅有手牌但本回合未得牌不作候选、主将位不可用而副将位可用、真实【决斗】使用。历史记录见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：`han_history` 的 `clear` 仅作测试夹具查询下界，正式游戏不调用；未覆盖明置瞬间完整服务端复核与武将交换前后连续操作。客户端选牌／选目标未人工验收。

<a id="han012-2"></a>
#### 博通（HAN012 蔡邕）

- **标识与依据**：运行时 ID `qiao__skill_han012_2`；源码 [skill_han012_2.lua](../../../../pkg/qiao_generals/skills/skill_han012_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN012。同将铸典见[辅助与牌资源](support.md#han012-1)。
- **实现与接口**：
  - `viewas` 转化任意基本牌；`fk.CardUseFinished` 时可将仍在处理区的全部子牌交给一名其他角色。
  - 选牌范围为手牌区或装备区（`include_equip = true`）；合法组合仅两种：4 张且四种花色各一张，或 3 张且基本牌／锦囊牌／装备牌各一张。
  - `card_filter` 以“补选后仍可能形成上述任一组合”防止选牌死路；`feasible` 做最终校验。多子牌颜色／点数由引擎 `Card:addSubcards` 按普通多子牌规则确定，不手算。
  - 牌名交互用 `UI.CardNameBox`，候选由公开的 `Player:getViewAsCardNames` 过滤；转化结果只允许「使用」，`enabled_at_response = false`。
  - 使用结算结束时 `fk.CardUseFinished` 先于处理区子牌置入弃牌堆触发；该效果标记 `is_delay_effect = true`，属于本次转化使用的后续效果，不作为新技能发动，也不因中途失去博通而消失。“这些牌”是本次以博通转化使用的实体子牌。交牌询问只提供接收者，多名候选时选择一名，只有一名候选时直接询问是否交给其。确认后复核接收者，并一次移动本次使用仍在处理区的所有子牌；拒绝时由引擎照常清理。
- **验证依据**：[han012_caiyong.lua](../../../../tests/han012_caiyong.lua) 覆盖博通四花色（4 张四花色当【杀】使用，结算后 4 张子牌全部交给 p2，额外手牌留在原位，选择窗口无可选牌）与博通三类别（基本／锦囊／装备各一张成功使用，拒绝交出时三张正常进弃牌堆）。历史记录见[共享验证证据](verification-evidence.md#han012_caiyong)。
- **未完成与边界**：基本牌名表目前列汉晋已登记的基本牌（含属性【杀】），卡表新增基本牌时应同步扩充。

<a id="han016a-1"></a>
#### 劲弩（HAN016A 刘宠）

- **标识与依据**：运行时 ID `qiao__skill_han016_1`；源码 [skill_han016_1.lua](../../../../pkg/qiao_generals/skills/skill_han016_1.lua)。规则见[刘宠规范](../../../rules/generals/han016a-liuchong.md)与[标准武将表](../../../rules/standard-generals.md)。牌面编号保留 `A`，运行时仍为 `qiao_heg__han016`；同将威屯见[阶段与回合流程](phases.md#han016a-2)。
- **实现与接口**：
  - 出牌阶段结束时触发执行一次；零用牌不满足任何分支。
  - 直接查询本阶段真实发生的 `GameEvent.UseCard` 事件，按事件 id 排序，因此技能在非空闲时点使用的牌也进入完整牌序；不依赖引擎聚合用牌次数。纯“打出”的 `GameEvent.RespondCard` 不是“使用”，不进入本条件。
  - 两个分支：至少使用过一张牌且全部为【杀】；或至少使用过两张牌且最后两张均不为【杀】。
  - 满足时在 `on_cost` 选定目标，再使用显式目标策略的 `bypass_distance` 虚拟【杀】：保留通常目标规则但不计算距离，真实使用一次，避免重复结算；实际使用也带 `bypass_times`，修复本阶段已出过【杀】时目标组合校验误挡技能视为使用的【杀】。
- **验证依据**：[han016_liuchong.lua](../../../../tests/han016_liuchong.lua) 覆盖劲弩零用牌不触发、全部为【杀】触发一次无距离【杀】、最后两张均非【杀】触发、不逐项拆分排列。历史记录见[共享验证证据](verification-evidence.md#han016_liuchong)。
- **未完成与边界**：未执行真实客户端出牌与目标选择交互；未覆盖阶段内响应／非空闲窗口的复杂牌序边界、技能造成目标死亡后的目标复核、禁止使用／禁止指定的具体来源；未验证武将交换与跨回合清理。资源编号迁移不在本轮范围。

### 魏

<a id="wei007-1"></a>
#### 倾国（WEI007 甄姬）

- **标识与依据**：运行时 ID `qiao__skill_wei007_1`；源码 [skill_wei007_1.lua](../../../../pkg/qiao_generals/skills/skill_wei007_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI007。同将洛神见[判定与花色](retrial.md#wei007-2)。
- **实现与接口**：黑色手牌当【闪】使用或打出，响应表达式用引擎牌名 `jink`，生成的正式牌为 `qiao__jink`。使用与打出共用转换入口。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 走实际客户端【闪】请求，核对按钮、黑色手牌、红色手牌和装备区牌的可选性，再验证确认回包生成正式【闪】。
- **未完成与边界**：客户端转化提示未人工验收。

<a id="wei010-1"></a>
#### 断粮（WEI010 徐晃）

- **标识与依据**：运行时 ID `qiao__skill_wei010_1`；源码 [skill_wei010_1.lua](../../../../pkg/qiao_generals/skills/skill_wei010_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI010。同将长驱见[用牌目标与距离](active.md#wei010-2)。
- **实现与接口**：转换按黑色与 `basic,equip` 同时筛选。引擎牌表达式的区域和完整牌名字段用 `.` 表示不限，留空会被解析成空匹配集合。底牌区域按视为技权限处理，其他角色跳过摸牌阶段后仍可令一名角色摸一张牌。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖他人跳过摸牌阶段后的摸牌，以及临时授技后的按钮、黑色基本牌及装备材料、红牌及黑色锦囊拒绝、合法选人与确认。本轮专项 17/17。
- **未完成与边界**：装备区素材的真实客户端选取尚未人工验收，不将“仅手牌”增写为规则限制。

### 蜀

<a id="shu001-1"></a>
#### 仁德（SHU001 刘备）

- **标识与依据**：`qiao__skill_shu001_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu001_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU001。
- **实现与接口**：主动给牌按接收者记录阶段次数，累计跨过第二张时提供一次基本牌选择。汉晋客户端刷新虚拟用牌候选时也读取当前请求的 `extra_data`；选择后经公共目标策略使用一次，传递 `bypass_times` 和 `extraUse`，取消结束此次选择。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu002-1"></a>
#### 武圣（SHU002 关羽）

- **标识与依据**：`qiao__skill_shu002_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu002_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU002。
- **实现与接口**：红色牌当杀；方片用牌绕过距离；红桃牌对唯一目标造成伤害后通过公共目标接口使用正式水淹七军。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu005-1"></a>
#### 龙胆（SHU005 赵云）

- **标识与依据**：`qiao__skill_shu005_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu005_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU005。
- **实现与接口**：ViewAs 提供杀闪、桃酒四组互转，并分别按当前使用或打出请求筛选；实体桃仍可用于龙胆转换。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu010-1"></a>
#### 连环（SHU010 庞统）

- **标识与依据**：`qiao__skill_shu010_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu010_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU010。
- **实现与接口**：梅花手牌通过 ViewAs 当正式铁索连环；辅助重铸入口受主技能有效性约束，重铸走 recastCard。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu011-1"></a>
#### 八阵（SHU011 诸葛亮）

- **标识与依据**：`qiao__skill_shu011_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu011_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU011。
- **实现与接口**：无防具时复用正式八卦阵技能；处理来源明暗置及移除，暗将通过需要闪的请求明置发动，预亮接线由模式 shu_hidden_prelight 提供。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu011-2"></a>
#### 火计（SHU011 诸葛亮）

- **标识与依据**：`qiao__skill_shu011_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu011_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU011。
- **实现与接口**：ViewAs 将红色手牌转换为正式火攻，素材不含装备区。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu011-3"></a>
#### 看破（SHU011 诸葛亮）

- **标识与依据**：`qiao__skill_shu011_3`；[源码](../../../../pkg/qiao_generals/skills/skill_shu011_3.lua)；[标准武将表](../../../rules/standard-generals.md) SHU011。
- **实现与接口**：黑色手牌当无懈仅开放使用；按成功抵消事件确认实际抵消者，包含闪抵消杀及非看破无懈。回合末仅对其他当前回合角色发起私看询问，自己的手牌由原手牌区展示。
- **验证依据**：[shu_effects.lua](../../../../tests/shu_effects.lua) 覆盖抵消后可私看其他角色手牌及本人回合末免询问；[共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

### 吴

<a id="wu002-1"></a>
#### 奇袭（WU002 甘宁）

- **标识与依据**：运行时 ID `qiao__skill_wu002_1`；源码 [skill_wu002_1.lua](../../../../pkg/qiao_generals/skills/skill_wu002_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU002。
- **实现与接口**：独立转换为汉晋【过河拆桥】，沿用公共用牌流程；不使用上游同名旧实现。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖奇袭转换；历史 15/15。
- **未完成与边界**：客户端转化与目标选择未人工验收。

<a id="wu006-1"></a>
#### 国色（WU006 大乔）

- **标识与依据**：运行时 ID `qiao__skill_wu006_1`；源码 [skill_wu006_1.lua](../../../../pkg/qiao_generals/skills/skill_wu006_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU006。同将流离见[用牌目标与距离](active.md#wu006-2)；弃置分支的费用与限次见[辅助与牌资源 WU006](support.md#wu006-1)。
- **实现与接口**：主动技用 `UI.ComboBox` 提供当前可执行的分支，选择分支后仍可选牌、选人及确认。使用分支把所选方片装入虚拟【乐不思蜀】，用相同材料查询牌的使用及目标合法性；弃置分支沿用批量移动，见[辅助与牌资源 WU006](support.md#wu006-1)。共用的虚拟牌目标复核与客户端同样接受引擎判定的真值。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖客户端进入国色、两分支选牌选人、确认回包以及独立限次。
- **未完成与边界**：客户端两分支选择未人工验收。

<a id="wu007-2"></a>
#### 度势（WU007 陆逊）

- **标识与依据**：运行时 ID `qiao__skill_wu007_2`；源码 [skill_wu007_2.lua](../../../../pkg/qiao_generals/skills/skill_wu007_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU007。同将谦逊见[用牌目标与距离](active.md#wu007-1)。
- **实现与接口**：按本回合未进弃牌堆花色筛转化牌，完成【以逸待劳】后检查四花色，按实际队列目标数选择红牌真实使用【火烧连营】。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖度势 ClientPlayer 与真实后续用牌；历史 12/12。
- **未完成与边界**：客户端筛选与后续用牌交互未人工验收。

### 群

<a id="qun004-1"></a>
#### 乱击（QUN004 袁绍）

- **标识与依据**：运行时 ID `qiao__skill_qun004_1`；源码 [skill_qun004_1.lua](../../../../pkg/qiao_generals/skills/skill_qun004_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN004。
- **实现与接口**：`viewas` 将两张手牌转为正式【万箭齐发】，不要求两素材同花色；只排除本回合此前发动乱击已选过的花色，记录随提供技能的武将牌迁移。响应摸牌由 [qun_cards_rule](../../../../pkg/qiao_mode/skills/qun_cards_rule.lua) 在牌效果建立后处理：实际打出【闪】的同势力角色选择摸一张，不依赖袁绍仍持有乱击。
- **验证依据**：已执行 [qun_cards.lua](../../../../tests/qun_cards.lua) 的 `testLuanjiDrawRuleUsesResponseFromWithoutSkill`、`testLuanjiSuitMarkClearsAfterSkillLost`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：同回合多次乱击的花色组合、无懈与复杂响应未穷举；客户端转化选择未人工验收。

<a id="qun005-1"></a>
#### 双雄（QUN005 颜良&文丑）

- **标识与依据**：运行时 ID `qiao__skill_qun005_1`；源码 [skill_qun005_1.lua](../../../../pkg/qiao_generals/skills/skill_qun005_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN005。
- **实现与接口**：摸牌阶段结束时弃一张自己的手牌或装备，记录其颜色；本回合可将一张异色牌当【决斗】使用，权限由独立状态骨架 `qiao__qun_cards_state` 提供，范围不缩为手牌，失去双雄后已建立权限仍可执行。结束阶段独立检查本回合实际造成过伤害且仍在弃牌堆的实体牌，不以前半段是否发动为条件，也不收回已被移走的牌。
- **验证依据**：已执行 [qun_cards.lua](../../../../tests/qun_cards.lua)，覆盖异色转决斗及结束阶段收回伤害牌；本轮定向通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：异色装备牌、伤害牌被移走等边界未穷举；客户端转化未人工验收。

<a id="qun015-1"></a>
#### 双刃（QUN015 纪灵）

- **标识与依据**：运行时 ID `qiao__skill_qun015_1`；源码 [skill_qun015_1.lua](../../../../pkg/qiao_generals/skills/skill_qun015_1.lua)。规则见[双刃持续期限](../../../rules/generals/qun015-jiling.md)与[只能当](../only-as.md)。
- **实现与接口**：出牌阶段开始时与一名角色真实拼点；赢时按显式目标条件视为对包含拼点对手在内的至多两名角色使用一张【杀】，不照搬上游同势力限制；没赢（含平局）时，手牌中的【杀】只能当【借刀杀人】使用至本回合结束，登记到公共 `only_as` 来源 `shuangren`，按当前手牌范围适用，转换后仍按【借刀杀人】自身规则选主副目标。
- **验证依据**：已执行 [qun_control.lua](../../../../tests/qun_control.lua) 的 `testShuangrenWinUsesOneSlashWithOpponent`、`testShuangrenLoseRestrictsHandSlashUntilTurnEnd`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：独立状态骨架 `qiao__qun_shuangren_state` 承载已建立的转换权限，失去本体后保留至回合结束；失技后真实借刀用例已通过定向验证。客户端拼点与借刀主副目标未人工验收。

<a id="qun017-1"></a>
#### 狂斧（QUN017 潘凤）

- **标识与依据**：运行时 ID `qiao__skill_qun017_1`；源码 [skill_qun017_1.lua](../../../../pkg/qiao_generals/skills/skill_qun017_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN017。
- **实现与接口**：出牌阶段限一次，弃置场上（含自己）一张装备牌，按 `bypassDistance` 显式策略视为使用一张无距离限制的【杀】；记录装备原所有者。后续摸两张／弃两张手牌由 [qun_cards_rule](../../../../pkg/qiao_mode/skills/qun_cards_rule.lua) 在整次用牌结束后按本次【杀】的 `damageDealt` 结算，不以本回合其他【杀】代替，也不在声明时提前终止。
- **验证依据**：已执行 [qun_cards.lua](../../../../tests/qun_cards.lua) 的 `testKuangfuOwnEquipmentDamageDrawsTwo`、`testKuangfuRuleSettlesWithoutSkill`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：弃置他人装备且未造成伤害、无牌可弃等分支未穷举；客户端选装备未人工验收。

<a id="qun027-2"></a>
#### 骁逆（QUN027 韩遂）

- **标识与依据**：运行时 ID `qiao__skill_qun027_2`；源码 [skill_qun027_2.lua](../../../../pkg/qiao_generals/skills/skill_qun027_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN027。
- **实现与接口**：限定技，出牌阶段按 `same_kingdom = false, other_roles = true` 显式策略视为对其他势力角色使用一张【杀】。未确定势力的角色也能被选，目标不套通常攻击距离。[qun_cards_rule](../../../../pkg/qiao_mode/skills/qun_cards_rule.lua) 在用牌结束后依据 `damageDealt` 处理未因此受伤的原目标。
- **发动与回归**：在出牌请求中直接选择目标，至少需要一名合法目标。客户端和服务端共用势力、用牌禁止及存活判断。[qun_cards.lua](../../../../tests/qun_cards.lua) 从正式韩遂的出牌按钮、目标选择及确认回包进入真实服务端结算，检查同势力目标不可选、限定次数、多目标杀及未受伤目标弃牌。
- **未完成与边界**：目标死亡／失技、全部受伤、无牌可弃等边界未直接覆盖；客户端多目标选择未人工验收。

### 晋

<a id="jin001-2"></a>
#### 兴图（JIN001 司马炎）

- **标识与依据**：运行时 ID `qiao__skill_jin001_2`；源码 [skill_jin001_2.lua](../../../../pkg/qiao_generals/skills/skill_jin001_2.lua)。规则见[司马炎规范](../../../rules/generals/jin001-simayan.md)。辅助主动技 `#qiao__skill_jin001_2_active`；同将垂统见[辅助与牌资源](support.md#jin001-1)。
- **实现与接口**：
  - 本回合应变牌使用事实：不要求当前拥有兴图的全局 `fk.PreTurnStart` 效果在每个回合开始时把房间标记 `qiao_jin001_2_adaptation_used` 置为 false，下一回合不继承上一回合事实；全局 `fk.AfterCardUseDeclared` 以 `A.isAdaptationCard(data.card, data)` 判断使用级应变牌，只检查本次实际使用的牌／使用数据，不把实体材料牌的应变条目或 `Adaptation.Triggered` 成功事件当作使用事实。任意角色使用均记录，条件是否满足、是否成功触发不影响事实。记录效果在技能尚未获得、暗置或后来获得时仍存在。纯“打出”走 `RespondCard`，不计入。
  - `fk.TurnEnd` 对每名角色（包括自己）的回合结束检查房间标记；技能有效且本回合序号匹配时只发起一次 `askToChoice`，直接给出“将一张装备牌当【桃】对一名角色使用”“摸一张牌”和取消。分支选择在 `on_cost` 完成并写入 `event:setCostData(self, { choice = ... })` 传给 `on_use`；取消返回 false，不进入 SkillEffect，因此不摸牌、不用牌、不消耗，也不明置来源或计为发动。第一项不合法时只提供摸牌与取消。
  - 第一项：辅助主动技只允许选择自己手牌区或装备区中的装备牌（`card_num = 1`、`include_equip = true`、`card_filter` 检查归属与 `Card.TypeEquip`），目标限已受伤角色（含自己与其他角色）。服务端再次复核材料归属／类型、目标存活及 `player:isProhibited`，然后调用公共 `C.useVirtualCard`，以 `C.explicit({})` 替换普通【桃】的牌面目标条件，并把 `skillName` 记为兴图；实际进入一次完整用牌流程，由【桃】自身效果回复体力，不直接 `recover`。
  - 第二项：直接 `drawCards(1, skill.name)`，不要求拥有装备牌。任一项都可取消；选择第一项后在选牌／选目标处取消，不摸牌、不使用、不移动。
- **验证依据**：[jin001_simayan.lua](../../../../tests/jin001_simayan.lua) 覆盖无应变用牌／普通牌／纯打出不触发；其他角色在本回合使用应变牌、条件未成功触发也计数；用牌发生在获得技能之前仍计入；下一回合清空；任意角色回合结束可发动；摸牌项与拒绝；第一项用手牌或装备区装备作材料、对受伤角色完整使用一次【桃】、材料离区且 `skillName` 为兴图，候选筛选和用牌校验均排除满体力角色；无合法装备时只提供摸牌项；主将、副将、暗置来源；真实 `ClientPlayer` 装备牌／非装备牌与目标可选性。历史 17/17，见[共享验证证据](verification-evidence.md#jin001_simayan)。
- **未完成与边界**：用户曾报告“应变牌后的下一回合，敌方普通杀→八卦阵视为闪，兴图误触发”，自动化未复现；真实连续回合回归及虚拟闪无应变条目检查通过，2026-11-13 用户复测确认无异常、反馈关闭，不据此追认具体根因，也未保留无复现依据的回合序号补丁。全局记录以使用牌事件为准，未覆盖“无任何目标但被使用”的边缘牌型。规范化描述待办见[司马炎入口](jin001-simayan.md#jin001-todo)。

<a id="jin005-1"></a>
#### 柔克（JIN005 羊祜）

- **标识与依据**：运行时 ID `qiao__skill_jin005_1`；源码 [skill_jin005_1.lua](../../../../pkg/qiao_generals/skills/skill_jin005_1.lua)。规则见[羊祜规范](../../../rules/generals/jin005-yanghu.md)与[易读描述的时机与然后](../../../rules/general-principles.md)。同将顺流见[伤害、体力与死亡](damage.md#jin005-2)。
- **实现与接口**：
  - `fk.PreCardUse` 全局触发；首张杀事实读取本回合 `GameEvent.UseCard` 历史，暗置/尚未取得时的使用仍保留。实际改牌通过 `UseCardData:changeCard("qiao__ice__slash", ..., skill.name)` 完成，保留本次使用与实体材料，不发起第二张杀；使用前已是冰杀时不重复改、不取得后续。
  - `data.qiao_jin005_1_changed` 记录实际改牌来源的 `player.id`；房间级监听器 `#qiao__skill_jin005_1_follow` 在 `fk.CardUseFinished` 只让该来源获得“未造成伤害后至多两名角色横置/重置”，不检查 `hasSkill`，因此本次用牌结束前失去柔克仍处理已建立后续。
  - `maxcards.correct_func` 先按 `player:hasSkill("qiao__skill_jin005_1")` 过滤，仅持有者获得“当前横置角色数”的手牌上限修正；`hasSkill` 为客户端公开判定。
- **验证依据**：[jin_chain.lua](../../../../tests/jin_chain.lua) 覆盖同势力首张杀改冰杀、被闪未伤害后横置/重置、持有者与非持有者手牌上限、改牌后失技后续仍执行；定向 6/6，见[共享验证证据](verification-evidence.md#jin-chain)。
- **未完成与边界**：多羊祜来源仅由来源 id 设计覆盖，未做双来源夹具；冰杀真实伤害重置由同一套件单独验证；客户端改牌显示与暗置历史未人工验收。

<a id="jin009-2"></a>
#### 骤霆（JIN009 司马懿）

- **标识与依据**：运行时 ID `qiao__skill_jin009_2`；源码 [skill_jin009_2.lua](../../../../pkg/qiao_generals/skills/skill_jin009_2.lua)。规则见[司马懿规范](../../../rules/generals/jin009-simayi.md)。同将权变见[辅助与牌资源](support.md#jin009-1)。
- **实现与接口**：限定技，出牌阶段发动；每次只从牌堆顶亮出一张并移入处理区，用正式 `askToUseRealCard` 实际使用（默认已执行，`extraUse` 不占空闲杀次数），完整结算后再取下一张；无法使用或亮出数达到当前存活角色数即止，不能任意取消。`expand_pile` 只授权本次亮出的处理区牌，不先拿入手牌，因此不会触发权变。
- **验证依据**：[jin_deck.lua](../../../../tests/jin_deck.lua) 覆盖处理区顶牌真实使用、无法使用即止、不能以手牌替代；3/3（0.787s），处理区唯一牌修正已通过，见[共享验证证据](verification-evidence.md#jin-deck)。
- **未完成与边界**：亮出即死亡、使用被抵消、牌堆不足与客户端连续用牌未人工验收。

<a id="jin010-1"></a>
#### 伤逝（JIN010 张春华）

- **标识与依据**：运行时 ID `qiao__skill_jin010_1`；源码 [skill_jin010_1.lua](../../../../pkg/qiao_generals/skills/skill_jin010_1.lua)。规则见[张春华规范](../../../rules/generals/jin010-zhangchunhua.md)。同将扼绝见[伤害、体力与死亡](damage.md#jin010-2)。
- **实现与接口**：结束阶段在同一可取消询问中展示冰【杀】和补牌两个选项，仅允许选择当前合法项。冰【杀】至少选择一张实际手牌。开放该选项前检查有无合法材料组合，选择后复核具体合成牌的限制，再以 `C.useVirtualCard` 和显式目标策略固定当前结束阶段角色。`extraUse` 不占空闲出杀次数。两项均不可执行时不发请求。
- **验证依据**：[jin_sources.lua](../../../../tests/jin_sources.lua) 覆盖双合法项时选择补牌、零手牌、单合法项、取消选牌、一张材料实际出冰【杀】、潜袭禁用材料及两张合成后无花色的合法分支。见[共享验证证据](verification-evidence.md#jin-sources)。
- **未完成与边界**：真人客户端选项及对局中动态状态变化待复测。
