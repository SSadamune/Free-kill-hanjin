# 辅助与牌资源：跨势力技能实现与验证

本页是“辅助与牌资源”机制的主记录页：摸牌、弃牌、移牌、给牌分配、手牌上限与技能授予，另含在主记录页已完整记录、此处只展开牌资源侧的分记录。这里“牌资源”含摸弃移配及手牌上限；“辅助”不等于仅对友方有效，包含对敌方或全场生效的资源操作。不替代规则条文，规则冲突时以 `docs/rules/` 与 `rulebook/` 为准。技能若另有主要机制（如伤害、拼点、转化），正文放在对应机制页，本页只以锚点交叉引用；确有两侧均复杂的可另设分记录。谋断含授予技能，是本页条目但注明次要机制为技能授予，不因结束阶段分类为阶段流程。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN001 | 刘协 | [天命](#han001-1) |
| HAN002 | 刘辩 | [诗怨](#han002-1) |
| HAN007 | 王荣 | [敏思](#han007-1) |
| HAN012 | 蔡邕 | [铸典](#han012-1) |
| HAN018 | 蹇硕 | [集兵](#han018-1) |
| WEI003 | 夏侯惇 | [持重](#wei003-2) |
| WEI004 | 张辽 | [突袭](#wei004-1) |
| WEI006 | 郭嘉 | [轻辎](#wei006-1) |
| WEI008 | 夏侯渊 | [设变](#wei008-2) |
| WEI011 | 曹仁 | [励战](#wei011-2) |
| WEI014 | 曹丕 | [放逐](#wei014-2) |
| SHU004 | 诸葛亮 | [观星](#shu004-1) |
| SHU007 | 黄月英 | [集智](#shu007-1) |
| SHU007 | 黄月英 | [藏机](#shu007-2) |
| SHU014 | 孟获 | [再起](#shu014-2) |
| SHU015 | 祝融夫人 | [巨象](#shu015-1) |
| SHU016 | 甘夫人 | [淑慎](#shu016-1) |
| SHU016 | 甘夫人 | [神智](#shu016-2) |
| WU001 | 孙权 | [制衡](#wu001-1) |
| WU003 | 吕蒙 | [克己](#wu003-1)、[谋断](#wu003-2)、[涉猎](#wu003-3) |
| WU005 | 周瑜 | [英姿](#wu005-1)、[反间](#wu005-2) |
| WU006 | 大乔 | [国色](#wu006-1)（分记录；主记录见[转化](conversion.md#wu006-1)） |
| WU008 | 孙尚香 | [结姻](#wu008-1)、[枭姬](#wu008-2) |
| WU009 | 孙坚 | [英魂](#wu009-1) |
| WU013 | 周泰 | [奋激](#wu013-2) |
| WU014 | 鲁肃 | [好施](#wu014-1)、[缔盟](#wu014-2) |
| WU015A | 张昭 | [直谏](#wu015a-1)、[固政](#wu015a-2) |
| QUN001 | 华佗 | [除疠](#qun001-2) |
| QUN003 | 貂蝉 | [闭月](#qun003-2) |
| QUN013 | 马腾 | [雄异](#qun013-2) |
| QUN016 | 田丰 | [死谏](#qun016-1) |
| QUN018 | 邹氏 | [倾城](#qun018-2) |
| JIN001 | 司马炎 | [垂统](#jin001-1) |
| JIN002 | 司马师 | [泰然](#jin002-1) |
| JIN003 | 司马昭 | [昭然](#jin003-1) |
| JIN004 | 贾充 | [通法](#jin004-1) |
| JIN007 | 王元姬 | [识人](#jin007-1)、[恤下](#jin007-2) |
| JIN008 | 夏侯徽 | [宜室](#jin008-1) |
| JIN009 | 司马懿 | [权变](#jin009-1) |
| JIN011 | 张虎&乐綝 | [果毅](#jin011-1) |
| JIN012 | 羊徽瑜 | [弘训](#jin012-2) |
| JIN014 | 文鸯 | [膂力](#jin014-1) |
| JIN016 | 张华 | [复礼](#jin016-1)、[风物](#jin016-2) |

## 技能条目

### 汉

<a id="han001-1"></a>
#### 天命（HAN001 刘协）

- **标识与依据**：运行时 ID `qiao__skill_han001_1`；源码 [skill_han001_1.lua](../../../../pkg/qiao_generals/skills/skill_han001_1.lua)。规则见[刘协规范](../../../rules/generals/han001-liuxie.md)。同将密诏见[拼点](pindian.md#han001-2)。
- **实现与接口**：
  - 成为【杀】的目标后触发；可弃手牌为 0 张、1 张、2 张或超过 2 张（含禁弃牌）时，弃 `min(2,K)` 张后摸 2 张，只用手牌；拒绝发动不弃不摸。
  - 普通／属性／视为【杀】均识别；在成为目标后、响应前弃摸，新摸的【闪】可响应；同一张【杀】的额外结算不再次触发。
  - 提示文案为“弃置两张手牌（不足则全弃，无牌则不弃）”和“请弃置 %arg 张手牌”。
- **验证依据**：[han001_liuxie.lua](../../../../tests/han001_liuxie.lua) 保留天命弃摸、公共机制与风险边界记录（旧验收组含触发时机与双技能联动）；原记录未以 han_standard_pindian 覆盖天命，本页不据此套用该文件名。历史执行见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：
  - [ ] 待办：编写天命、密诏各自的规范化描述，使用规则集定义的术语与结构，精确表达时机、条件、消耗和效果，并核对项目已确认裁定与实际代码。
  - [ ] 待办：将审定后的规范化描述纳入《汉晋规则集》对应武将资料；保留面向玩家的卡面描述。测试说明及 `docs/rules/generals/han001-liuxie.md` 的裁定草案均不替代规范化描述，未决裁定须明确标注。
  - 天命与密诏的联动及汉晋／普通房间隔离沿用原验收组；正常闪响应、防具、伤害、牌移动和来源变化优先复用公共覆盖，按[测试分层](../../testing.md)决定新增用例，不将场景清单逐项视为测试义务。相关夹具污染的根因与确定性回归入口见[故障案例](../../lessons.md)。
  - 客户端发动／弃牌提示的真实点击未人工验收。

<a id="han002-1"></a>
#### 诗怨（HAN002 刘辩）

- **标识与依据**：运行时 ID `qiao__skill_han002_1`；源码 [skill_han002_1.lua](../../../../pkg/qiao_generals/skills/skill_han002_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN002。同将毒逝见[伤害、体力与死亡](damage.md#han002-2)。
- **实现与接口**：随汉区 25 技能骨架一并实装，骨架 `qiaoImplemented = true`，由 [init.lua](../../../../pkg/qiao_generals/init.lua) 既有登记分支加载；原资料未记录该技能的独立回调与请求细节。
- **验证依据**：[han_standard.lua](../../../../tests/han_standard.lua) 共享汉区套件，已纳入默认国战套件；结果见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：本组暂无更细的接口接线、定向用例输出或人工验收记录；未完成边界沿用[汉包](han-standard.md#han-standard-boundary)。

<a id="han007-1"></a>
#### 敏思（HAN007 王荣）

- **标识与依据**：运行时 ID `qiao__skill_han007_1`；源码 [skill_han007_1.lua](../../../../pkg/qiao_generals/skills/skill_han007_1.lua)；共用工具 [minsi.lua](../../../../pkg/qiao_generals/util/minsi.lua)。规则见[王荣规范](../../../rules/generals/han007-wangrong.md)。同将追德见[伤害、体力与死亡](damage.md#han007-2)。
- **实现与接口**：
  - 本体主动技、追德额外发动用的辅助主动技，以及手牌上限豁免的 `maxcards` 状态技；两处共用选牌、13 点子集判断、弃牌、双倍摸牌、展示和红桃标记。技能不把敏思永久授予受赠者。
  - 选牌上限按 `player:getCardIds("he")` 计算，`include_equip = true`；服务端在真正移动前复核牌仍归自己、未被禁止弃置且点数和为 13，非法回复不动牌。
  - 「本回合不计入手牌上限」按卡牌标记实现，标记键含受益者 id，只豁免此次摸到的红桃；牌转给其他角色后不替原角色继续豁免。`-turn` 由房间在回合结束清理。`maxcards` 状态技是房间级的，受赠者额外发动后即使王荣死亡，标记仍按受赠者 id 生效。
  - 额外敏思走独立辅助主动技名 `#qiao__skill_han007_1_aux`，不经过本体 `max_phase_use_time` 的阶段历史；受赠者已用普通敏思仍可额外发动，且不占用、不增加主技能次数。
  - 红桃判定使用 `Room:filterCard(id, player)` 的有效花色；点数和仍取实体牌原始点数。
- **验证依据**：[han007_wangrong.lua](../../../../tests/han007_wangrong.lua) 覆盖敏思手牌和（A+Q 弃置、摸 4 展示、同阶段第二次不可用）、敏思装备牌（可参与凑 13）、手牌上限豁免（真实弃牌阶段：体力 1、手中 5 张含 2 张红桃，只弃 2 张）；追德额外敏思用例见[追德条目](damage.md#han007-2)。历史定向记录见[共享验证证据](verification-evidence.md#han007_wangrong)。
- **未完成与边界**：手牌上限的引擎显示值不逐个扣除“不计入”的牌，实际弃牌阶段按 `MaxCardsSkill:excludeFrom` 计算；界面数字与有效上限差异属引擎显示范围，未修改公共机制。

<a id="han012-1"></a>
#### 铸典（HAN012 蔡邕）

- **标识与依据**：运行时 ID `qiao__skill_han012_1`；源码 [skill_han012_1.lua](../../../../pkg/qiao_generals/skills/skill_han012_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN012。同将博通见[转化与生成用牌](conversion.md#han012-2)。
- **实现与接口**：
  - 时机为“成为目标后”，使用 `fk.TargetConfirmed`；条件排除自己使用，并要求使用牌为黑色。
  - 重铸是“置入弃牌堆，然后摸一张牌”，不是弃置。选牌直接放在 `on_cost`：取消即不发动，避免先明置再询问可取消消耗；不调用 `prohibitDiscard` 过滤，也不把重铸写成弃牌消耗。`Room:recastCard` 返回实际摸到的牌。
  - 黑色分支对 `Room:filterCard(id, player)` 的有效颜色判断；展示前复核该牌仍由自己持有，展示通过 `Room:showCards`，再摸一张。重铸前再次核对牌仍属于自己；重铸后死亡则不继续展示／补摸。
- **验证依据**：[han012_caiyong.lua](../../../../tests/han012_caiyong.lua) 覆盖铸典黑色分支（装备牌在禁止弃置下仍可重铸、摸到黑色后展示并补摸、红牌不入展示）与非黑分支（摸到红牌不展示、不补摸，重铸牌进弃牌堆）。历史记录见[共享验证证据](verification-evidence.md#han012_caiyong)。
- **未完成与边界**：重铸牌若因其他效果多摸，只按第一张判断黑色分支；标准重铸规则为摸一张，此边界未另作扩展。客户端选牌与展示未人工验收。

<a id="han018-1"></a>
#### 集兵（HAN018 蹇硕）

- **标识与依据**：运行时 ID `qiao__skill_han018_1`；源码 [skill_han018_1.lua](../../../../pkg/qiao_generals/skills/skill_han018_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)汉区 HAN018。
- **实现与接口**：随汉区 25 技能骨架一并实装，骨架 `qiaoImplemented = true`；原资料未记录独立回调与请求细节。
- **验证依据**：[han_standard.lua](../../../../tests/han_standard.lua) 共享汉区套件；结果见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：本组暂无更细的定向用例输出或人工验收；未完成边界沿用[汉包](han-standard.md#han-standard-boundary)。

### 魏

<a id="wei003-2"></a>
#### 持重（WEI003 夏侯惇）

- **标识与依据**：运行时 ID `qiao__skill_wei003_2`；源码 [skill_wei003_2.lua](../../../../pkg/qiao_generals/skills/skill_wei003_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI003 与 `rulebook/terms/game-flow-terms/phase.md`。同将刚烈见[伤害、体力与死亡](damage.md#wei003-1)。
- **实现与接口**：
  - `fk.AfterCardsMove` 检查是否有牌移入该角色手牌区；装备区不计为“得到”。
  - “摸牌阶段外”依 `rulebook/terms/game-flow-terms/phase.md` 的“某角色于阶段内”默认指其自身阶段，直接检查 `player.phase == Player.Draw`；其他角色的摸牌阶段内自己得到牌仍可发动。
  - 已确认解释不是“只分出超额部分”：最小张数为 `math.max(1, 体力值 + 1)`，`max_num = 手牌数`；选牌使用 `Room:askToCards`（不施加弃置禁止，选牌不是弃置），选中牌全部通过公共 `Room:askToYiji` 分配，未使用自建分配循环。
  - 每回合一次以 `usedEffectTimes(..., Player.HistoryTurn)` 判定；分配目标为其他存活角色，不含自己。
- **验证依据**：[wei_support.lua](../../../../tests/wei_support.lua) 的 `testChizhongDistributesMoreThanHp`：4 体力、6 手牌时用 `askToCards` 选择 5 张全部分配、保留 1 张，验证“不是只分超额”；该文件历史 3/3 通过。旧记录执行入口为 `python scripts/test.py --file tests/wei_support.lua --timeout 120` 与 `python scripts/test.py --file tests/wei_damage.lua --timeout 120`，对应结果 3/3、8/8。历史间歇失败根因与夹具修复见[共享验证证据](verification-evidence.md#持重夹具根因)。
- **未完成与边界**：客户端分配界面未人工验收；引擎显示值与有效上限差异不在本技能范围。

<a id="wei004-1"></a>
#### 突袭（WEI004 张辽）

- **标识与依据**：运行时 ID `qiao__skill_wei004_1`；源码 [skill_wei004_1.lua](../../../../pkg/qiao_generals/skills/skill_wei004_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI004 与[“X 只能当 Y 使用／打出”实现说明](../only-as.md)。
- **实现与接口**：
  - `fk.DrawNCards` 触发，在摸牌数量确定前减少 `data.n`；少摸张数等于实际选择的其他角色数。选择至多 `data.n` 名有手牌的其他角色，各获得一张手牌，使用 `fk.ReasonPrey`；目标中途无手牌时跳过。
  - 展示为可选项；确认展示后 `room:showCards` 公开获得的牌，并调用 `OnlyAs.addSource`：`def = "tuxi"`（仅开放【杀】的 `use`/`response`）、`cards = 本次实际获得的实体牌集合`、`duration = "turn"`、不传 `skill`。因此**失去突袭不会撤销**本回合已产生的限制，回合结束由 only-as 规则统一到期。
  - 独立回合状态提供视为【杀】的客户端入口，手牌只对持有者提示当前用途。限制与转换入口均持续至回合结束，失去突袭后仍可完成既有转换。
  - 直接使用／打出这些实体牌被公共 only-as 禁止；其他来源的转化权限仍按并集保留。未在技能内自行改写牌名或添加独立“只能当”技能。
- **验证依据**：[wei_support.lua](../../../../tests/wei_support.lua) 的 `testTuxiDrawReductionAndTurnRestriction`：2 张少摸为 0，获得两名角色各一张；展示后该牌被 only-as 禁止直接使用且提供【杀】转换；失去突袭后限制仍在。历史 3/3。
- **未完成与边界**：对“保留其他转化权限”仅依赖 only-as 并集语义，未新增专项组合测试；`tuxi` 来源的回合到期依赖公共 only-as 规则技能，测试未覆盖到期。

<a id="wei006-1"></a>
#### 轻辎（WEI006 郭嘉）

- **标识与依据**：运行时 ID `qiao__skill_wei006_1`；源码 [skill_wei006_1.lua](../../../../pkg/qiao_generals/skills/skill_wei006_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI006。同将遗计见[伤害、体力与死亡](damage.md#wei006-2)。
- **实现与接口**：
  - 准备阶段弃置同势力其他角色装备区一张牌，令其获得“神速”直到其回合结束。
  - 临时技能授予使用 `Room:handleAddLoseSkills(player, skill, source, ...)`，来源记为轻辎；到期用同一来源 `"-" .. skillName` 移除。授予状态使用不带 `-turn` 的独立标记，不随郭嘉回合末自动清除，只在目标自己的 TurnEnd 回收。
  - 目标原有暗将神速或后获其他来源的同名技能不会被移除；同势力候选复用 hegemony 公共的 `HegUtil.compareExpectedKingdomWith`（拥有者暗置时按本人可见的 `__heg_kingdom`／`__heg_wild` 预测，他人暗置时公开势力为 `unknown`，不进入候选）。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖轻辎弃置目标装备后授予神速、施加者回合结束仍保留、目标回合结束回收、目标原有／另一来源神速不被移除；历史 14/14。
- **未完成与边界**：客户端授予技能提示与选牌未人工验收。

<a id="wei008-2"></a>
#### 设变（WEI008 夏侯渊）

- **标识与依据**：运行时 ID `qiao__skill_wei008_2`；源码 [skill_wei008_2.lua](../../../../pkg/qiao_generals/skills/skill_wei008_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI008；共享工具 [wei_phases.lua](../../../../pkg/qiao_generals/util/wei_phases.lua)。同将神速见[阶段与回合流程](phases.md#wei008-1)。
- **实现与接口**：
  - 仅 `HpLost` 触发；`can_trigger` 先检查场上确有可移动牌。
  - 移动场上牌先由引擎公共的 `Room:askToChooseToMoveCardInBoard` 在两阶段内筛出确有可移动关系的两名角色，再用 `Room:askToMoveCardInBoard`（0.5.25 `ltk/server/room.lua` 3374 行）在其中一人装备／判定区选牌移动；请求回复为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 的设变用例双方均有可移动牌（p1 藤甲、p2 武器），请求级用例历史通过；历史 14/14。曾有 90 秒超时，根因是测试直接比较 `ServerPlayer` 对象导致 LuaUnit 挂起，非请求 schema，见[共享验证证据](verification-evidence.md#设变巧变超时根因)。
- **未完成与边界**：客户端两步移牌面板未人工验收。

<a id="wei011-2"></a>
#### 励战（WEI011 曹仁）

- **标识与依据**：运行时 ID `qiao__skill_wei011_2`；源码 [skill_wei011_2.lua](../../../../pkg/qiao_generals/skills/skill_wei011_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI011。同将伪溃见[用牌目标与距离](active.md#wei011-1)。
- **实现与接口**：结束阶段用同一个可取消的选人请求确认发动；选中的已受伤角色各摸一张牌。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖选中已受伤角色与取消不增加发动次数。
- **未完成与边界**：客户端目标选择未人工验收。

<a id="wei014-2"></a>
#### 放逐（WEI014 曹丕）

- **标识与依据**：运行时 ID `qiao__skill_wei014_2`；源码 [skill_wei014_2.lua](../../../../pkg/qiao_generals/skills/skill_wei014_2.lua)。规则见[曹丕结算约定](../../../rules/generals/wei014-caopi.md)与[叠置与平置](../../../../rulebook/terms/general-op-terms/stack.md)。同将行殇见[伤害、体力与死亡](damage.md#wei014-1)。
- **实现与接口**：
  - `fk.Damaged` 每次伤害事件一次；目标须为其他存活角色，先叠置再摸 2；手牌＋装备合计 ≥4 时可足额弃 4 并平置，弃置牌名字数之和 >7 则失去 1 点体力。
  - 国战“叠置／平置”对应引擎 `faceup`：平置 `faceup = true`，叠置 `faceup = false`。叠置仅在 `faceup` 为真时调用原生 `player:turnOver()`；已叠置不重复翻转，但后续摸牌与弃牌分支仍分别执行。
  - 摸牌后不足四张不进入弃牌分支：不平置，也不检查牌名字数、不失去体力。足够四张时由目标决定是否弃置；`min_num = max_num = 4` 保证足额，范围含手牌与装备。弃置后仅在仍为叠置时调用原生 `turnOver` 平置，再按实际弃置的四张牌逐张累计中文牌名字数（`utf8.len`），大于 7 则失去 1 点体力。
  - 使用原生翻面入口，保留 `BeforeTurnOver`／`TurnedOver` 事件、翻面跳回合流程与客户端 `faceup` 朝向显示；未修改引擎本体。
- **验证依据**：[wei_support.lua](../../../../tests/wei_support.lua) 的 `testFangzhuStackDrawDiscardAndHpLoss`：平置→叠置并摸 2；足额弃 4 后平置且牌名字数和 >7 失去体力；已有叠置目标不反转且仍摸 2；不足 4 张时不提供弃牌分支、保持叠置。历史 3/3。
- **未完成与边界**：客户端翻面朝向与弃牌交互未人工验收。

### 蜀

<a id="shu004-1"></a>
#### 观星（SHU004 诸葛亮）

- **标识与依据**：`qiao__skill_shu004_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu004_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU004。
- **实现与接口**：准备阶段卜算五张，存活角色不足四时三张；全置底记录本回合结束阶段强制再执行，模式级后续不依赖仍持有观星，回合末清理未执行记录。
- **验证依据**：[shu_phases.lua](../../../../tests/shu_phases.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu007-1"></a>
#### 集智（SHU007 黄月英）

- **标识与依据**：`qiao__skill_shu007_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu007_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU007。
- **实现与接口**：CardUsing 检查锦囊类别、非转化且有实体牌对应，普通和延时锦囊均可触发；适用[集智已确认的描述层次裁定](../../../rules/generals/shu007-huangyueying.md)。
- **验证依据**：[shu_conversion.lua](../../../../tests/shu_conversion.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu007-2"></a>
#### 藏机（SHU007 黄月英）

- **标识与依据**：`qiao__skill_shu007_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu007_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU007。
- **实现与接口**：BeforeCardsMove 筛选本人装备区因弃置离开的非坐骑牌，每回合可取消其中一张的移动，保留其余移动。
- **验证依据**：[shu_effects.lua](../../../../tests/shu_effects.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu014-2"></a>
#### 再起（SHU014 孟获）

- **标识与依据**：`qiao__skill_shu014_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu014_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU014。
- **实现与接口**：模式级 AfterCardsMove 累计当前回合全场红牌进入弃牌堆次数；弃牌阶段结束先选至多 X 名角色含自己，座次依次由各人选摸一或令孟获回复。
- **验证依据**：[shu_savage.lua](../../../../tests/shu_savage.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu015-1"></a>
#### 巨象（SHU015 祝融夫人）

- **标识与依据**：`qiao__skill_shu015_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu015_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU015。
- **实现与接口**：只对持有者设置南蛮无效；他人南蛮 CardUseFinished 后获得仍可取得的对应实体牌，不提前到每目标结算时取得。
- **验证依据**：[shu_savage.lua](../../../../tests/shu_savage.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu016-1"></a>
#### 淑慎（SHU016 甘夫人）

- **标识与依据**：`qiao__skill_shu016_1`；[源码](../../../../pkg/qiao_generals/skills/skill_shu016_1.lua)；[标准武将表](../../../rules/standard-generals.md) SHU016。
- **实现与接口**：HpRecover 按实际回复点数提供独立机会，持有者选其他角色回复一点或双方各摸一张，满体力不开放回复分支。
- **验证依据**：[shu_effects.lua](../../../../tests/shu_effects.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

<a id="shu016-2"></a>
#### 神智（SHU016 甘夫人）

- **标识与依据**：`qiao__skill_shu016_2`；[源码](../../../../pkg/qiao_generals/skills/skill_shu016_2.lua)；[标准武将表](../../../rules/standard-generals.md) SHU016。
- **实现与接口**：准备阶段检查能足额弃置非空的全部手牌，再比较弃牌数与结算时体力，满足则回复一点。
- **验证依据**：[shu_effects.lua](../../../../tests/shu_effects.lua)；[本批共享证据](verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收。

### 吴

<a id="wu001-1"></a>
#### 制衡（WU001 孙权）

- **标识与依据**：运行时 ID `qiao__skill_wu001_1`；源码 [skill_wu001_1.lua](../../../../pkg/qiao_generals/skills/skill_wu001_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU001。
- **实现与接口**：弃牌不超过体力上限；本次弃完已有手牌额外摸一张。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖制衡数量与额外摸牌；历史 15/15，见[共享验证证据](verification-evidence.md#wu_support)。
- **未完成与边界**：客户端弃牌界面未人工验收。

<a id="wu003-1"></a>
#### 克己（WU003 吕蒙）

- **标识与依据**：运行时 ID `qiao__skill_wu003_1`；源码 [skill_wu003_1.lua](../../../../pkg/qiao_generals/skills/skill_wu003_1.lua)。规则见[吕蒙规范](../../../rules/generals/wu003-lvmeng.md)。同将谋断、涉猎见[本页](#wu003-2)。
- **实现与接口**：按出牌阶段使用牌的颜色判断；与谋断共享 [wu_history.lua](../../../../pkg/qiao_mode/rules/wu_history.lua) 与[全局记录器](../../../../pkg/qiao_mode/skills/wu_history.lua)，后者由模式启动安装，真实使用声明写入公开标记，客户端读取同步数据而不读取服务端事件树。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖克己历史判断；历史 12/12，见[共享验证证据](verification-evidence.md#wu_phases)。
- **未完成与边界**：客户端提示与人工交互未验收。

<a id="wu003-2"></a>
#### 谋断（WU003 吕蒙）

- **标识与依据**：运行时 ID `qiao__skill_wu003_2`；源码 [skill_wu003_2.lua](../../../../pkg/qiao_generals/skills/skill_wu003_2.lua)。规则见[吕蒙规范](../../../rules/generals/wu003-lvmeng.md)。同将[克己](#wu003-1)、[涉猎](#wu003-3)。
- **实现与接口**：按整回合花色／类别判断，两条件同时满足才授予后天涉猎，不立即发动。**次要机制：技能授予**（授予而非阶段流程，故本页收录）。历史写入与客户端读取同克己。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖谋断授予；历史 12/12。
- **未完成与边界**：客户端授予提示未人工验收；谋断只获得涉猎，不额外发动（依已确认规范）。

<a id="wu003-3"></a>
#### 涉猎（WU003 吕蒙）

- **标识与依据**：运行时 ID `qiao__skill_wu003_3`；源码 [skill_wu003_3.lua](../../../../pkg/qiao_generals/skills/skill_wu003_3.lua)。规则见[吕蒙规范](../../../rules/generals/wu003-lvmeng.md)。以 `related = true` 登记，仅通过谋断获得，不计入天生技能数；不是独立武将技能。
- **实现与接口**：替换本次正常摸牌，以正式整理界面选择异花色牌，并服务端复核牌属于本次五张、仍在处理区且无重复花色；涉猎 poxi 注册由[共享工具](../../../../pkg/qiao_generals/util/wu_phases.lua)提供。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖涉猎异花色；历史 12/12。
- **未完成与边界**：客户端整理界面未人工验收；作为后天技能不计入吴包天生技能数统计。

<a id="wu005-1"></a>
#### 英姿（WU005 周瑜）

- **标识与依据**：运行时 ID `qiao__skill_wu005_1`；源码 [skill_wu005_1.lua](../../../../pkg/qiao_generals/skills/skill_wu005_1.lua)。规则见[周瑜规范](../../../rules/generals/wu005-zhouyu.md)。同将反间见[本页](#wu005-2)。
- **实现与接口**：主将条件由 `MainPlace` 接线；具体摸牌加成随正式摸牌流程执行。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖英姿；历史 15/15。
- **未完成与边界**：主将／副将切换的客户端显示未人工验收。

<a id="wu005-2"></a>
#### 反间（WU005 周瑜）

- **标识与依据**：运行时 ID `qiao__skill_wu005_2`；源码 [skill_wu005_2.lua](../../../../pkg/qiao_generals/skills/skill_wu005_2.lua)。规则见[周瑜规范](../../../rules/generals/wu005-zhouyu.md)。
- **实现与接口**：交牌前快照展示花色；响应只展示手牌，弃同花色手牌与装备，检查至少两张及禁弃；弃置执行者是目标；响应有选择权。主将体力贡献 −1 按半格公共表示处理。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖反间接受与拒绝、手装弃置及拒绝；历史 15/15。
- **未完成与边界**：反间红颜组合及实际 `ProhibitSkill` 禁弃组合未单独验证；客户端点击未人工验收。

<a id="wu006-1"></a>
#### 国色（WU006 大乔，分记录）

- **标识与依据**：运行时 ID `qiao__skill_wu006_1`；源码 [skill_wu006_1.lua](../../../../pkg/qiao_generals/skills/skill_wu006_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU006。转化使用与目标条件见主记录[转化 WU006](conversion.md#wu006-1)；本页只展开弃置分支与费用／限次侧。
- **实现与接口**：两分支独立限次，在交互、牌／目标筛选及执行前分别复核；弃置分支的两项费用都确认可执行后才批量移动，避免只支付一部分。使用分支的目标条件见主记录。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖国色两分支及不可重用；历史 12/12，见[共享验证证据](verification-evidence.md#wu_phases)。
- **未完成与边界**：客户端两分支选择未人工验收；复杂禁弃／费用不足组合未穷举。

<a id="wu008-1"></a>
#### 结姻（WU008 孙尚香）

- **标识与依据**：运行时 ID `qiao__skill_wu008_1`；源码 [skill_wu008_1.lua](../../../../pkg/qiao_generals/skills/skill_wu008_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU008 与[装备置入](../../../rules/equipment-movement.md)。同将枭姬见[本页](#wu008-2)。
- **实现与接口**：仅展示合法弃牌／空栏置入候选；体力相等无较大／较小收益；装备置入要求空置对应栏；客户端安全房间访问支持无 `room` 字段的真实 `ClientPlayer`。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖结姻置入及代表性真实 `ClientPlayer` 用例（无 `room` 字段下的可用性与候选）；历史 15/15。
- **未完成与边界**：客户端置入动画与人工交互未验收。

<a id="wu008-2"></a>
#### 枭姬（WU008 孙尚香）

- **标识与依据**：运行时 ID `qiao__skill_wu008_2`；源码 [skill_wu008_2.lua](../../../../pkg/qiao_generals/skills/skill_wu008_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU008。
- **实现与接口**：失去装备逐张触发，回合内／外分别摸一张／两张。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖枭姬回合内外；历史 15/15。
- **未完成与边界**：客户端失去装备提示未人工验收。

<a id="wu009-1"></a>
#### 英魂（WU009 孙坚）

- **标识与依据**：运行时 ID `qiao__skill_wu009_1`；源码 [skill_wu009_1.lua](../../../../pkg/qiao_generals/skills/skill_wu009_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU009。
- **实现与接口**：X 为已损失体力值；摸牌／弃牌两分支使用正式接口。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖英魂；历史 15/15。
- **未完成与边界**：客户端两分支选择未人工验收。

<a id="wu013-2"></a>
#### 奋激（WU013 周泰）

- **标识与依据**：运行时 ID `qiao__skill_wu013_2`；源码 [skill_wu013_2.lua](../../../../pkg/qiao_generals/skills/skill_wu013_2.lua)。规则见[周泰规范](../../../rules/generals/wu013-zhoutai.md)。同将不屈见[伤害、体力与死亡](damage.md#wu013-1)。
- **实现与接口**：按真实“失去全部手牌”历史选择目标；使用中性 `qiao_wu_fenxun_target-turn` 标记与[模式距离技能](../../../../pkg/qiao_mode/skills/wu_distance_effects.lua)，失去来源技能不提前终止，也不随来源前缀被交换机制迁移。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖奋激及失技后持续；历史 22/22。
- **未完成与边界**：客户端目标选择未人工验收。

<a id="wu014-1"></a>
#### 好施（WU014 鲁肃）

- **标识与依据**：运行时 ID `qiao__skill_wu014_1`；源码 [skill_wu014_1.lua](../../../../pkg/qiao_generals/skills/skill_wu014_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU014。同将缔盟见[本页](#wu014-2)。
- **实现与接口**：将多摸后的给牌承诺绑在本次摸牌事件数据上，由静态辅助完成；失去好施不取消已承诺给牌，也不跨摸牌阶段泄漏。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖好施承诺后失技、好施与缔盟来源到期；历史 22/22。
- **未完成与边界**：客户端给牌交互未人工验收。

<a id="wu014-2"></a>
#### 缔盟（WU014 鲁肃）

- **标识与依据**：运行时 ID `qiao__skill_wu014_2`；源码 [skill_wu014_2.lua](../../../../pkg/qiao_generals/skills/skill_wu014_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU014。到期辅助 [wu_dimeng_expiry.lua](../../../../pkg/qiao_mode/skills/wu_dimeng_expiry.lua)。
- **实现与接口**：使用可弃牌支付手牌数差，真实交换后按 FAQ 授予纵横好施至目标下个回合结束；来源级移除不删除其他来源的同名技能。差为零不能支付弃置消耗，依公共消耗规范处理。到期辅助在加载期注册、模式启动预装，不在房间运行期创建客户端未知的技能；角色时效标记采用中性名。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖缔盟交换与多来源到期；历史 22/22。
- **未完成与边界**：客户端交换界面未人工验收。

<a id="wu015a-1"></a>
#### 直谏（WU015A 张昭）

- **标识与依据**：运行时 ID `qiao__skill_wu015a_1`；源码 [skill_wu015a_1.lua](../../../../pkg/qiao_generals/skills/skill_wu015a_1.lua)。规则见[张昭规范](../../../rules/generals/wu015a-zhangzhao.md)与[装备置入](../../../rules/equipment-movement.md)。同将固政见[本页](#wu015a-2)。
- **实现与接口**：手牌区→你摸牌、装备区→其摸牌的顺序对应；装备置入要求空置对应栏；仅展示合法候选。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖直谏两来源（手牌／装备区决定摸牌者）与空栏；历史 15/15。
- **未完成与边界**：客户端置入面板未人工验收。

<a id="wu015a-2"></a>
#### 固政（WU015A 张昭）

- **标识与依据**：运行时 ID `qiao__skill_wu015a_2`；源码 [skill_wu015a_2.lua](../../../../pkg/qiao_generals/skills/skill_wu015a_2.lua)。规则见[张昭规范](../../../rules/generals/wu015a-zhangzhao.md)。
- **实现与接口**：同事件多个弃牌者由玩家择一，只取该角色本事件仍在弃牌堆的牌，返一后批量取得至多三张。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖固政同事件多弃牌者选择；历史 15/15。
- **未完成与边界**：客户端弃牌者选择未人工验收。

### 群

<a id="qun001-2"></a>
#### 除疠（QUN001 华佗）

- **标识与依据**：运行时 ID `qiao__skill_qun001_2`；源码 [skill_qun001_2.lua](../../../../pkg/qiao_generals/skills/skill_qun001_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN001。同将济世见[伤害、体力与死亡](damage.md#qun001-1)。
- **实现与接口**：出牌阶段限一次，选至多三名**彼此势力不相同**的其他角色，不要求与华佗不同；随后华佗与这些角色各弃一张手牌或装备。全部弃置完成后按实际失去的牌结算，失去黑桃者各摸一张，后弃的黑桃不漏记。
- **验证依据**：已执行 [qun_basic.lua](../../../../tests/qun_basic.lua) 的 `testChuliTwoCandidatesSpadeDraws`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **客户端入口**：按钮计算经 `Fk:currentRoom()` 读取公开存活角色，不读取 `ClientPlayer` 不具备的 `room` 字段。`testChuliClientAvailabilityWithoutPlayerRoom` 使用配套客户端角色／房间走 `ReqPlayCard.setup` 与 `skillButtonValidity`，覆盖合法候选、本人无牌、全场无候选及阶段次数耗尽；已通过自动化回归。
- **未完成与边界**：候选势力并列、目标无牌、华佗自己无牌等边界未穷举；客户端选人／弃牌未人工验收。

<a id="qun003-2"></a>
#### 闭月（QUN003 貂蝉）

- **标识与依据**：运行时 ID `qiao__skill_qun003_2`；源码 [skill_qun003_2.lua](../../../../pkg/qiao_generals/skills/skill_qun003_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN003。同将离间见[用牌目标与距离](active.md#qun003-1)。
- **实现与接口**：`fk.EventPhaseStart` 的结束阶段入口，按发动时（摸牌前）是否空手决定摸一张或两张；不先摸一张再判断。可取消，不强制发动。
- **验证依据**：已执行 [qun_basic.lua](../../../../tests/qun_basic.lua) 的 `testBiyueEmptyHandDrawsTwo`、`testBiyueWithHandDrawsOne`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：结束阶段被跳过、其他结束阶段技能排队未专项覆盖；客户端提示未人工验收。

<a id="qun013-2"></a>
#### 雄异（QUN013 马腾）

- **标识与依据**：运行时 ID `qiao__skill_qun013_2`；源码 [skill_qun013_2.lua](../../../../pkg/qiao_generals/skills/skill_qun013_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN013。同将马术复用[共享马术锚点](active.md#shu006-1)。
- **实现与接口**：限定技，出牌阶段先令所有与自己势力相同的角色（含自己）各摸三张；再按锁定上游 `hegemony.util` 的 `compareKingdomWith`／`getKingdomPlayersNum` 统计，若同势力人数全场最少（含并列）才回复 1 点，不自行聚合势力字符串。
- **验证依据**：已执行 [qun_basic.lua](../../../../tests/qun_basic.lua) 的 `testXiongyiSameKingdomDrawsAndTieMinimumRecovers`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：野心家、并列最少、摸牌中死亡等边界未穷举；客户端提示未人工验收。

<a id="qun016-1"></a>
#### 死谏（QUN016 田丰）

- **标识与依据**：运行时 ID `qiao__skill_qun016_1`；源码 [skill_qun016_1.lua](../../../../pkg/qiao_generals/skills/skill_qun016_1.lua)。规则见[田丰来源基线](../../../rules/generals/qun016-tianfeng.md)。同将随势见[伤害、体力与死亡](damage.md#qun016-2)。
- **实现与接口**：两个独立时机。失去最后的手牌：本次移动批次确实有手牌离开，且移动结束后为空手，不在已是空手的其他批次重复触发。体力值变化为 1：比较变化前后，仅从非 1 变为 1 时触发，维持在 1 或变为 0 不触发，也不要求是失去体力。效果为弃一名其他角色一张手牌或装备，不含判定区，不附带回复。
- **验证依据**：已执行 [qun_basic.lua](../../../../tests/qun_basic.lua) 的 `testSijianLastHandcardDiscardsOtherCard`、`testSijianNotTriggeredWhileStillHoldingHandcards`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：同批次多次失牌、体力一次变化跨过 1、目标无牌等边界未穷举；客户端选择未人工验收。

<a id="qun018-2"></a>
#### 倾城（QUN018 邹氏）

- **标识与依据**：运行时 ID `qiao__skill_qun018_2`；源码 [skill_qun018_2.lua](../../../../pkg/qiao_generals/skills/skill_qun018_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN018。同将祸水见[用牌目标与距离](active.md#qun018-1)。
- **实现与接口**：出牌阶段限一次，选一名手牌数小于等于自己的其他男性角色，双方交换全部手牌；交换的是一方或双方为空也可执行。保留来源：用一次移牌事件交换两边手牌，不逐张获得／交给。次数按本阶段记录。
- **验证依据**：已执行 [qun_judgement.lua](../../../../tests/qun_judgement.lua) 的 `testQingchengSwapsAllHandcardsOncePerPhase`，本轮群包定向 47 项通过，见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：交换中手牌被其他效果移动、双方空手、手牌数变化等边界未穷举；客户端交换展示未人工验收。

### 晋

<a id="jin001-1"></a>
#### 垂统（JIN001 司马炎）

- **标识与依据**：运行时 ID `qiao__skill_jin001_1`；源码 [skill_jin001_1.lua](../../../../pkg/qiao_generals/skills/skill_jin001_1.lua)。规则见[司马炎规范](../../../rules/generals/jin001-simayan.md)与[装备移动通则](../../../rules/equipment-movement.md)。同将兴图见[转化与生成用牌](conversion.md#jin001-2)。
- **实现与接口**：
  - `fk.EnterDying` 提供一次发动机会，`target` 为进入濒死的其他角色；`target == player` 直接排除，不按敌友或势力筛选。未改为监听求桃，同一濒死流程不会按求桃次数反复触发。
  - 候选牌只取该角色装备区中 `target:canMoveCardInBoardTo(player, id)` 为真的牌；该锁定接口检查目标栏存在、未废除且为空，并排除目标为自己；已有同类装备、废除栏或无牌时 `can_trigger` 不成立。
  - 发动者从复核后的候选牌中选择一张（`Room:askToChooseCard`，候选以 `$Equip` 列表给出）；选择后再次复核来源归属、双方存活与 `canMoveCardInBoardTo`，再调用 `Room:moveCardIntoEquip(player, card, skill, false, target)`。`convert = false` 保证不替换目标已有装备；移动进入对应空栏而非手牌，并按正常移牌触发失去／得到装备结算。
  - 发动在 `askToSkillInvoke` 处可取消；取消、候选为空或复核失败时不移动。
- **验证依据**：[jin001_simayan.lua](../../../../tests/jin001_simayan.lua) 覆盖其他角色进入濒死时移入空置对应栏且非手牌；同类栏已占用、废除栏、无牌、取消、自己濒死均不移动；`hp = 0` 的完整濒死流程只提供一次发动；主将、副将、暗置预亮来源均验证。历史 17/17，见[共享验证证据](verification-evidence.md#jin001_simayan)。
- **未完成与边界**：未应用开发适配的本体人工交互验收尚未执行；规范化描述待办见[司马炎入口](jin001-simayan.md#jin001-todo)。

<a id="jin002-1"></a>
#### 泰然（JIN002 司马师）

- **标识与依据**：运行时 ID `qiao__skill_jin002_1`；源码 [skill_jin002_1.lua](../../../../pkg/qiao_generals/skills/skill_jin002_1.lua)。规则见[司马师规范](../../../rules/generals/jin002-simashi.md)。同将夷灭见[伤害、体力与死亡](damage.md#jin002-2)。
- **实现与接口**：`fk.EventPhaseStart`（出牌阶段）询问是否失去任意点体力，并可弃置至多当前已损失体力值的牌；两项都可放弃。实际失去量与弃牌数分别交给 [jin_resources.lua](../../../../pkg/qiao_generals/util/jin_resources.lua) 记录，由模式规则 [jin_resources_rule](../../../../pkg/qiao_mode/skills/jin_resources_rule.lua) 在 `fk.TurnEnd` 逐条结算：先回复该次实际失去的体力，再摸该次实际弃牌数。
- **验证依据**：[jin_resources.lua](../../../../tests/jin_resources.lua) 覆盖记录与回末结算、两条记录分别结算、救回后按实际失去量记录；定向 15/15（3.686s），见[共享验证证据](verification-evidence.md#jin-resources)。
- **未完成与边界**：后续时机尚未定案，当前暂按 `fk.TurnEnd` 逐条结算，**不是最终裁定**；回合结束前死亡、弃牌触发插入效果、客户端交互未验。

<a id="jin003-1"></a>
#### 昭然（JIN003 司马昭）

- **标识与依据**：运行时 ID `qiao__skill_jin003_1`；源码 [skill_jin003_1.lua](../../../../pkg/qiao_generals/skills/skill_jin003_1.lua)。规则见[司马昭规范](../../../rules/generals/jin003-simazhao.md)。同将挟征见[用牌目标与距离](active.md#jin003-2)。
- **实现与接口**：出牌阶段开始加 `-phase` 可见标记；`visibility` 的 `card_visible` 只认当前在所有者手牌区的牌，因此本阶段之后获得的手牌也可见。`fk.AfterCardsMove` 以移动前牌面快照统计每种花色首次失去最后一张手牌，按 `newlyLostSuits` 固定并记录到 `lost_suits`；每个新花色由司马昭选择摸一张或弃其他角色一张。房间级可见性来源 [jin_information_rule](../../../../pkg/qiao_mode/skills/jin_information_rule.lua) 已随 mode 接线，保证失去昭然后本阶段已经公开的手牌仍可见。阶段标记由 `-phase` 后缀清理，同花色事实不因重新获得而重开。
- **验证依据**：[jin_information.lua](../../../../tests/jin_information.lua) 覆盖可见性与首次失去花色；2/2（0.511s）通过，见[共享验证证据](verification-evidence.md#jin-information)。
- **未完成与边界**：客户端可见性、同事件多花色、摸回同花色与暗置来源未人工验收。

<a id="jin004-1"></a>
#### 通法（JIN004 贾充）

- **标识与依据**：运行时 ID `qiao__skill_jin004_1`；源码 [skill_jin004_1.lua](../../../../pkg/qiao_generals/skills/skill_jin004_1.lua)。规则见[贾充规范](../../../rules/generals/jin004-jiachong.md)与[应变规范](../../../rules/adaptation.md)。同将悖弑见[伤害、体力与死亡](damage.md#jin004-2)。
- **实现与接口**：全局监听 `fk.AfterCardUseDeclared`，只对同势力实际使用应变牌的角色触发。使用者自己支付一张手牌/装备（`askToDiscard`，已执行）或交给贾充一张（`askToChooseCard`＋`obtainCard`）；随后 `A.grantIgnore` 只给本次 `use` 增加一个“无视一个尚未满足条件”的应变令牌，不把所有条目一起视为成立，也不覆盖已有条目；条目由共享 [jin_adaptation_rule](../../../../pkg/qiao_mode/skills/jin_adaptation_rule.lua) 在结算时读取。`PAID` 写在 `data.extra_data`，同一使用不重复收费。
- **验证依据**：[jin_adaptation.lua](../../../../tests/jin_adaptation.lua) 覆盖付费后一个条目触发与延迟 ignore 令牌；应变定向 5/5；公共应变 25/25、`ignore_times` 14/14 属公共机制历史结果，不挪作本技能覆盖，见[共享验证证据](verification-evidence.md#jin-adaptation)。
- **未完成与边界**：暗置来源明置、多个应变条目同时满足、无法支付与同一使用多次询问未单独验；客户端交互未人工验收。

<a id="jin007-1"></a>
#### 识人（JIN007 王元姬）

- **标识与依据**：运行时 ID `qiao__skill_jin007_1`；源码 [skill_jin007_1.lua](../../../../pkg/qiao_generals/skills/skill_jin007_1.lua)。规则见[王元姬规范](../../../rules/generals/jin007-wangyuanji.md)。同将恤下见本页[恤下](#jin007-2)。
- **实现与接口**：准备阶段选择至多三名其他势力、仍有手牌的角色，逐个以 `askToChooseCard(flag="h")` 隐藏选牌并先固定；随后按行动顺序让各拥有者用 `askToChoice` 声明一个牌名。只展示并获得其中一张；仅将该牌实际牌名与其拥有者声明比较，不同才把其余已选牌一并获得。选牌阶段不展示、不提前公开；声明及比较按通用牌名口径与 `trueName` 去重；不将应变分组专属的属性杀区分规则推广到识人。
- **验证依据**：[jin_information.lua](../../../../tests/jin_information.lua) 覆盖隐藏选牌、声明与只展示一张；2/2（0.511s）通过，见[共享验证证据](verification-evidence.md#jin-information)。
- **未完成与边界**：取消选择后的部分名单、目标死亡/手牌变化、声明牌名集合与客户端展示未人工验收。

<a id="jin007-2"></a>
#### 恤下（JIN007 王元姬）

- **标识与依据**：运行时 ID `qiao__skill_jin007_2`；源码 [skill_jin007_2.lua](../../../../pkg/qiao_generals/skills/skill_jin007_2.lua)。规则见[王元姬规范](../../../rules/generals/jin007-wangyuanji.md)。同将识人见本页[识人](#jin007-1)。
- **实现与接口**：全局监听 `fk.Damaged`，目标为受伤的其他角色；按 `H.getGeneralsRevealedNum` 读取实际明置将数，少于王元姬（含暗置来源的预测）才可发动，每回合一次（`HistoryTurn`）。消耗为交给目标两张自己的手牌/装备，使用 `askToChooseCardsAndPlayers` 的“交给”而非弃置过滤；随后摸两张。暗置来源的明置由引擎 `SkillEffect` 完成，技能只预测并检查 `prohibitReveal`，不自行明置。
- **验证依据**：[jin_resources.lua](../../../../tests/jin_resources.lua) 有交两张摸两张、明置数不足与两张牌门槛；定向 15/15（3.686s）；恤下真实“0 明置→发动后明置→交给两张→摸两张”已通过，见[共享验证证据](verification-evidence.md#jin-resources)。
- **未完成与边界**：目标死亡、禁明置、交给中插入移牌、客户端交互未人工验收。

<a id="jin008-1"></a>
#### 宜室（JIN008 夏侯徽）

- **标识与依据**：运行时 ID `qiao__skill_jin008_1`；源码 [skill_jin008_1.lua](../../../../pkg/qiao_generals/skills/skill_jin008_1.lua)。规则见[夏侯徽规范](../../../rules/generals/jin008-xiahouhui.md)。同将识度见[拼点](pindian.md#jin008-2)。
- **实现与接口**：全局监听 `fk.AfterCardsMove`，每回合一次；按弃置操作者 `proposer`（不是牌的原拥有者 `from`）和同势力筛选，收集本批仍在弃牌堆的牌。选一张交给操作者，再从剩余牌中选一张获得；只取一张，不收取全部剩余。已被其他同时机效果移走的牌不再从新区域强取；第一步合法执行后不因第二步无法执行而倒推取消。
- **验证依据**：[jin_resources.lua](../../../../tests/jin_resources.lua) 覆盖交给一张再获得一张、按操作者势力而非原拥有者；定向 15/15（3.686s），见[共享验证证据](verification-evidence.md#jin-resources)。
- **未完成与边界**：多批弃牌、同一操作者多次弃置、目标死亡与客户端选牌未人工验收。

<a id="jin009-1"></a>
#### 权变（JIN009 司马懿）

- **标识与依据**：运行时 ID `qiao__skill_jin009_1`；源码 [skill_jin009_1.lua](../../../../pkg/qiao_generals/skills/skill_jin009_1.lua)。规则见[司马懿规范](../../../rules/generals/jin009-simayi.md)；共享工具 [jin_deck.lua](../../../../pkg/qiao_generals/util/jin_deck.lua)。同将骤霆见[转化与生成用牌](conversion.md#jin009-2)。
- **实现与接口**：`fk.AfterCardUseDeclared` 按本阶段 `GameEvent.UseCard` 历史判断每种花色的首张真实手牌使用；响应中的实际使用也计入，纯打出不计。发动后把该花色写入 `jin_deck.lua` 的中性 `-phase` 标记；模式规则 [jin_deck_rule](../../../../pkg/qiao_mode/skills/jin_deck_rule.lua) 在真实用牌入口禁止使用该花色手牌，但不禁止打出、不限制非手牌来源，失技后已建立限制保留。
- **验证依据**：[jin_deck.lua](../../../../tests/jin_deck.lua) 覆盖首张红桃后禁手牌不禁响应；3/3（0.787s），见[共享验证证据](verification-evidence.md#jin-deck)。
- **未完成与边界**：暗置/晚明置、同花色重复获得、客户端禁选显示未人工验收。

<a id="jin011-1"></a>
#### 果毅（JIN011 张虎&乐綝）

- **标识与依据**：运行时 ID `qiao__skill_jin011_1`；源码 [skill_jin011_1.lua](../../../../pkg/qiao_generals/skills/skill_jin011_1.lua)。规则见[张虎&乐綝规范](../../../rules/generals/jin011-zhanghu-yuechen.md)。同将无其他已实装技能。
- **实现与接口**：`active` 效果使用引擎正式选牌／选目标请求；`include_equip = true`，候选基本牌同时检查 `prohibitDiscard`，目标为有手牌或有装备的其他存活角色。`feasible` 要求已选目标数等于已选基本牌数，`on_use` 再复核至少一张、数量相等及素材归属；随后 `Room:throwCard` 实际弃置。每名目标按 `askToChoice` 只在“其有可弃装备／其有手牌”中显示可执行分支，选牌操作者均为发动者（`askToChooseCard`＋`throwCard`／`obtainCard`）。全部目标完成后，统计的是“两项分支是否均被目标选择过”，不是移牌是否最终成功；选择后插入的移牌或失去牌结算不会抹除已选择事实。仅两项均有人选过时才询问一名目标并调用 `Room:damage`，一次发动至多造成1点伤害。短时按同名与关键事件查找项目及锁定上游，未发现同效果实现；复用引擎 `active` 选牌／选人、`askToChooseCard`、`throwCard`／`obtainCard` 与 `damage`。
- **验证依据**：[jin_basic.lua](../../../../tests/jin_basic.lua) 以真实出牌阶段验证两张基本牌弃置、等量目标、装备与手牌两分支、两项均有人选后对一名目标造成伤害、仅单分支不造成伤害、分支选择只显示合法项、服务端拒绝牌数与目标数不符。本批定向 19/19。
- **未完成与边界**：未应用开发适配的本体人工交互验收尚未执行；目标同时具两分支时的界面选择只覆盖一个代表性用例，客户端多选顺序与暗置来源未人工验收。

<a id="jin012-2"></a>
#### 弘训（JIN012 羊徽瑜）

- **标识与依据**：运行时 ID `qiao__skill_jin012_2`；源码 [skill_jin012_2.lua](../../../../pkg/qiao_generals/skills/skill_jin012_2.lua)。规则见[羊徽瑜规范](../../../rules/generals/jin012-yanghuiyu.md)。同将慈威见[用牌目标与距离](active.md#jin012-1)。
- **实现与接口**：锁定技，`fk.EventPhaseStart`（`Player.Finish`）的全局触发；`B.sameKingdom` 复用 [jin_basic.lua](../../../../pkg/qiao_generals/util/jin_basic.lua) 与 hegemony 公共势力比较，合法情况下包含自己。已受伤先摸一张；已横置先用 `setChainState(false)` 定向重置，再摸一张；两项分别检查，可各执行一次。没有发动询问，也不依赖服务端私有字段。短时按同名查找未发现同效果上游实现；重置复用引擎 `setChainState`，摸牌复用 `drawCards`。
- **验证依据**：[jin_basic.lua](../../../../tests/jin_basic.lua) 覆盖自己同时受伤且横置时摸两张并重置、同势力仅受伤／仅横置分别摸一张、不同势力不摸牌且不重置。本批 `jin_basic` 套件合计 19/19。
- **未完成与边界**：未应用开发适配的本体人工交互验收尚未执行；暗置来源、多来源同势力与死亡中断未单独覆盖。

<a id="jin014-1"></a>
#### 膂力（JIN014 文鸯）

- **标识与依据**：运行时 ID `qiao__skill_jin014_1`；源码 [skill_jin014_1.lua](../../../../pkg/qiao_generals/skills/skill_jin014_1.lua)。规则见[文鸯规范](../../../rules/generals/jin014-wenyang.md)。同将夺气见[阶段与回合流程](phases.md#jin014-2)，文虎翼从未在本批实装。
- **实现与接口**：`fk.Damage`（造成伤害后，使用者为事件目标；不是 `DamageFinished`）且 `data.from == player`、`data.damage > 0`，按 `HistoryTurn` 每回合限一次，不按伤害点数重复。选项一仅在当前手牌数小于体力值时出现，使用 [jin_basic.lua](../../../../pkg/qiao_generals/util/jin_basic.lua) 的 `drawHandToHp`，按当前体力值与手牌数差额摸牌；手牌已不少于体力值时不展示无效的补至项。选项二仅在 `canDiscardAllHand` 为真（手牌非空且全部可弃）时出现；先实际弃置全部手牌，再按实际张数 `recoverHpTo`，受体力上限限制，当前体力高于目标值时不降低。两项均不可执行时不发动、不占次数；空手不能以部分弃置充作全弃。短时按同名查找未发现同效果上游实现；复用引擎 `Damage`、`drawCards`、`throwCard` 与 `recover`。
- **验证依据**：[jin_basic.lua](../../../../tests/jin_basic.lua) 覆盖补至当前体力值、弃两张后回复至2、体力高于弃牌数时不被降低、空手只显示摸牌项、手牌不少于体力值时隐藏补至项、`fk.Damage` 早于 `fk.Damaged` 的结算顺序、同一回合第二次伤害不再发动。本批定向 19/19。
- **未完成与边界**：未应用开发适配的本体人工交互验收尚未执行；伤害被防止、濒死死亡、禁弃来源并存等边界未单独覆盖。

<a id="jin016-1"></a>
#### 复礼（JIN016 张华）

- **标识与依据**：运行时 ID `qiao__skill_jin016_1`；源码 [skill_jin016_1.lua](../../../../pkg/qiao_generals/skills/skill_jin016_1.lua)。规则见[张华规范](../../../rules/generals/jin016-zhanghua.md)。同将风物见本页[风物](#jin016-2)。
- **实现与接口**：全局监听 `fk.DrawNCards`，同势力角色摸牌阶段可多摸一张，并把 `{target, source}` 承诺写入房间 tag；`jin_sources_rule` 在摸牌完成后的正式流程读取承诺，令其展示一张手牌、交给张华，并建立本回合不能使用/打出该花色的标记。自己展示自己时不虚构交给移动；限制由房间规则读取角色标记，失技不撤销已建立限制。
- **验证依据**：[jin_sources.lua](../../../../tests/jin_sources.lua) 覆盖复礼多摸、展示交给与花色标记；独立 `jin_sources_rule` 已正式 mode 接线，9/9（2.179s）通过，见[共享验证证据](verification-evidence.md#jin-sources)。
- **未完成与边界**：真实暗将、目标死亡、无手牌展示、同回合多花色与客户端交互未人工验收。

<a id="jin016-2"></a>
#### 风物（JIN016 张华）

- **标识与依据**：运行时 ID `qiao__skill_jin016_2`；源码 [skill_jin016_2.lua](../../../../pkg/qiao_generals/skills/skill_jin016_2.lua)。规则见[张华规范](../../../rules/generals/jin016-zhanghua.md)。同将复礼见本页[复礼](#jin016-1)。
- **实现与接口**：出牌阶段限一次主动技，选至多三名角色依次使用一张牌，每人可放弃。用牌走 `free_use.askToUseCard`，以 `not_passive` 限定客户端候选并在服务端复核，合法提交只执行一次。效果内用牌标 `extraUse`，不占空闲出杀次数。全部询问结束后读取 `wu_history` 的本回合全体真实使用记录，四花色齐备才摸两张并回复1点体力，纯打出不计。
- **验证依据**：[jin_sources.lua](../../../../tests/jin_sources.lua) 10/10 通过。覆盖真实客户端可选合法装备、无法选择【闪】，服务端拒绝本次请求返回的【闪】并保留其手牌位置，以及四花色与合法用牌结算。
- **未完成与边界**：目标放弃、用牌被抵消、四花色跨回合与客户端交互未验。
