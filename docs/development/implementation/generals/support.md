# 辅助与牌资源：跨势力技能实现与验证

本页是“辅助与牌资源”机制的主记录页：摸牌、弃牌、移牌、给牌分配、手牌上限与技能授予，另含在主记录页已完整记录、此处只展开牌资源侧的分记录。这里“牌资源”含摸弃移配及手牌上限；“辅助”不等于仅对友方有效，包含对敌方或全场生效的资源操作。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。技能若另有主要机制（如伤害、拼点、转化），正文放在对应机制页，本页只以锚点交叉引用；确有两侧均复杂的可另设分记录。谋断含授予技能，是本页条目但注明次要机制为技能授予，不因结束阶段分类为阶段流程。共享命令输出见[共享验证证据](verification-evidence.md)。

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
| WU001 | 孙权 | [制衡](#wu001-1) |
| WU003 | 吕蒙 | [克己](#wu003-1)、[谋断](#wu003-2)、[涉猎](#wu003-3) |
| WU005 | 周瑜 | [英姿](#wu005-1)、[反间](#wu005-2) |
| WU006 | 大乔 | [国色](#wu006-1)（分记录；主记录见[转化](conversion.md#wu006-1)） |
| WU008 | 孙尚香 | [结姻](#wu008-1)、[枭姬](#wu008-2) |
| WU009 | 孙坚 | [英魂](#wu009-1) |
| WU013 | 周泰 | [奋激](#wu013-2) |
| WU014 | 鲁肃 | [好施](#wu014-1)、[缔盟](#wu014-2) |
| WU015A | 张昭 | [直谏](#wu015a-1)、[固政](#wu015a-2) |
| JIN001 | 司马炎 | [垂统](#jin001-1) |

## 技能条目

### 汉

<a id="han001-1"></a>
#### 天命（HAN001 刘协）

- **标识与依据**：运行时 ID `hanjin__skill_han001_1`；源码 [skill_han001_1.lua](../../../../pkg/hanjin_generals/skills/skill_han001_1.lua)。规则见[刘协规范](../../../../rules/generals/han001-liuxie.md)。同将密诏见[拼点](pindian.md#han001-2)。
- **实现与接口**：
  - 成为【杀】的目标后触发；可弃手牌为 0 张、1 张、2 张或超过 2 张（含禁弃牌）时，弃 `min(2,K)` 张后摸 2 张，只用手牌；拒绝发动不弃不摸。
  - 普通／属性／视为【杀】均识别；在成为目标后、响应前弃摸，新摸的【闪】可响应；同一张【杀】的额外结算不再次触发。
  - 提示文案为“弃置两张手牌（不足则全弃，无牌则不弃）”和“请弃置 %arg 张手牌”。
- **验证依据**：[han001_liuxie.lua](../../../../tests/han001_liuxie.lua) 保留天命弃摸、公共机制与风险边界记录（旧验收组含触发时机与双技能联动）；原记录未以 han_standard_pindian 覆盖天命，本页不据此套用该文件名。历史执行见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：
  - [ ] 待办：编写天命、密诏各自的规范化描述，使用规则集定义的术语与结构，精确表达时机、条件、消耗和效果，并核对项目已确认裁定与实际代码。
  - [ ] 待办：将审定后的规范化描述纳入《汉晋规则集》对应武将资料；保留面向玩家的卡面描述。测试说明及 `rules/generals/han001-liuxie.md` 的裁定草案均不替代规范化描述，未决裁定须明确标注。
  - 天命与密诏的联动及汉晋／普通房间隔离沿用原验收组；正常闪响应、防具、伤害、牌移动和来源变化优先复用公共覆盖，按[测试分层](../../testing.md)决定新增用例，不将场景清单逐项视为测试义务。相关夹具污染的根因与确定性回归入口见[故障案例](../../lessons.md)。
  - 客户端发动／弃牌提示的真实点击未人工验收。

<a id="han002-1"></a>
#### 诗怨（HAN002 刘辩）

- **标识与依据**：运行时 ID `hanjin__skill_han002_1`；源码 [skill_han002_1.lua](../../../../pkg/hanjin_generals/skills/skill_han002_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN002。同将毒逝见[伤害、体力与死亡](damage.md#han002-2)。
- **实现与接口**：随汉区 25 技能骨架一并实装，骨架 `hanjinImplemented = true`，由 [init.lua](../../../../pkg/hanjin_generals/init.lua) 既有登记分支加载；原资料未记录该技能的独立回调与请求细节。
- **验证依据**：[han_standard.lua](../../../../tests/han_standard.lua) 共享汉区套件，已纳入默认国战套件；结果见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：本组暂无更细的接口接线、定向用例输出或人工验收记录；未完成边界沿用[汉包](han-standard.md#han-standard-boundary)。

<a id="han007-1"></a>
#### 敏思（HAN007 王荣）

- **标识与依据**：运行时 ID `hanjin__skill_han007_1`；源码 [skill_han007_1.lua](../../../../pkg/hanjin_generals/skills/skill_han007_1.lua)；共用工具 [minsi.lua](../../../../pkg/hanjin_generals/util/minsi.lua)。规则见[王荣规范](../../../../rules/generals/han007-wangrong.md)。同将追德见[伤害、体力与死亡](damage.md#han007-2)。
- **实现与接口**：
  - 本体主动技、追德额外发动用的辅助主动技，以及手牌上限豁免的 `maxcards` 状态技；两处共用选牌、13 点子集判断、弃牌、双倍摸牌、展示和红桃标记。技能不把敏思永久授予受赠者。
  - 选牌上限按 `player:getCardIds("he")` 计算，`include_equip = true`；服务端在真正移动前复核牌仍归自己、未被禁止弃置且点数和为 13，非法回复不动牌。
  - 「本回合不计入手牌上限」按卡牌标记实现，标记键含受益者 id，只豁免此次摸到的红桃；牌转给其他角色后不替原角色继续豁免。`-turn` 由房间在回合结束清理。`maxcards` 状态技是房间级的，受赠者额外发动后即使王荣死亡，标记仍按受赠者 id 生效。
  - 额外敏思走独立辅助主动技名 `#hanjin__skill_han007_1_aux`，不经过本体 `max_phase_use_time` 的阶段历史；受赠者已用普通敏思仍可额外发动，且不占用、不增加主技能次数。
  - 红桃判定使用 `Room:filterCard(id, player)` 的有效花色；点数和仍取实体牌原始点数。
- **验证依据**：[han007_wangrong.lua](../../../../tests/han007_wangrong.lua) 覆盖敏思手牌和（A+Q 弃置、摸 4 展示、同阶段第二次不可用）、敏思装备牌（可参与凑 13）、手牌上限豁免（真实弃牌阶段：体力 1、手中 5 张含 2 张红桃，只弃 2 张）；追德额外敏思用例见[追德条目](damage.md#han007-2)。历史定向记录见[共享验证证据](verification-evidence.md#han007_wangrong)。
- **未完成与边界**：手牌上限的引擎显示值不逐个扣除“不计入”的牌，实际弃牌阶段按 `MaxCardsSkill:excludeFrom` 计算；界面数字与有效上限差异属引擎显示范围，未修改公共机制。

<a id="han012-1"></a>
#### 铸典（HAN012 蔡邕）

- **标识与依据**：运行时 ID `hanjin__skill_han012_1`；源码 [skill_han012_1.lua](../../../../pkg/hanjin_generals/skills/skill_han012_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN012。同将博通见[转化与生成用牌](conversion.md#han012-2)。
- **实现与接口**：
  - 时机为“成为目标后”，使用 `fk.TargetConfirmed`；条件排除自己使用，并要求使用牌为黑色。
  - 重铸是“置入弃牌堆，然后摸一张牌”，不是弃置。选牌直接放在 `on_cost`：取消即不发动，避免先明置再询问可取消消耗；不调用 `prohibitDiscard` 过滤，也不把重铸写成弃牌消耗。`Room:recastCard` 返回实际摸到的牌。
  - 黑色分支对 `Room:filterCard(id, player)` 的有效颜色判断；展示前复核该牌仍由自己持有，展示通过 `Room:showCards`，再摸一张。重铸前再次核对牌仍属于自己；重铸后死亡则不继续展示／补摸。
- **验证依据**：[han012_caiyong.lua](../../../../tests/han012_caiyong.lua) 覆盖铸典黑色分支（装备牌在禁止弃置下仍可重铸、摸到黑色后展示并补摸、红牌不入展示）与非黑分支（摸到红牌不展示、不补摸，重铸牌进弃牌堆）。历史记录见[共享验证证据](verification-evidence.md#han012_caiyong)。
- **未完成与边界**：重铸牌若因其他效果多摸，只按第一张判断黑色分支；标准重铸规则为摸一张，此边界未另作扩展。客户端选牌与展示未人工验收。

<a id="han018-1"></a>
#### 集兵（HAN018 蹇硕）

- **标识与依据**：运行时 ID `hanjin__skill_han018_1`；源码 [skill_han018_1.lua](../../../../pkg/hanjin_generals/skills/skill_han018_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN018。
- **实现与接口**：随汉区 25 技能骨架一并实装，骨架 `hanjinImplemented = true`；原资料未记录独立回调与请求细节。
- **验证依据**：[han_standard.lua](../../../../tests/han_standard.lua) 共享汉区套件；结果见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：本组暂无更细的定向用例输出或人工验收；未完成边界沿用[汉包](han-standard.md#han-standard-boundary)。

### 魏

<a id="wei003-2"></a>
#### 持重（WEI003 夏侯惇）

- **标识与依据**：运行时 ID `hanjin__skill_wei003_2`；源码 [skill_wei003_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei003_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI003 与 `rulebook/terms/game-flow-terms/phase.md`。同将刚烈见[伤害、体力与死亡](damage.md#wei003-1)。
- **实现与接口**：
  - `fk.AfterCardsMove` 检查是否有牌移入该角色手牌区；装备区不计为“得到”。
  - “摸牌阶段外”依 `rulebook/terms/game-flow-terms/phase.md` 的“某角色于阶段内”默认指其自身阶段，直接检查 `player.phase == Player.Draw`；其他角色的摸牌阶段内自己得到牌仍可发动。
  - 已确认解释不是“只分出超额部分”：最小张数为 `math.max(1, 体力值 + 1)`，`max_num = 手牌数`；选牌使用 `Room:askToCards`（不施加弃置禁止，选牌不是弃置），选中牌全部通过公共 `Room:askToYiji` 分配，未使用自建分配循环。
  - 每回合一次以 `usedEffectTimes(..., Player.HistoryTurn)` 判定；分配目标为其他存活角色，不含自己。
- **验证依据**：[wei_support.lua](../../../../tests/wei_support.lua) 的 `testChizhongDistributesMoreThanHp`：4 体力、6 手牌时用 `askToCards` 选择 5 张全部分配、保留 1 张，验证“不是只分超额”；该文件历史 3/3 通过。旧记录执行入口为 `python scripts/test.py --file tests/wei_support.lua --timeout 120` 与 `python scripts/test.py --file tests/wei_damage.lua --timeout 120`，对应结果 3/3、8/8。历史间歇失败根因与夹具修复见[共享验证证据](verification-evidence.md#持重夹具根因)。
- **未完成与边界**：客户端分配界面未人工验收；引擎显示值与有效上限差异不在本技能范围。

<a id="wei004-1"></a>
#### 突袭（WEI004 张辽）

- **标识与依据**：运行时 ID `hanjin__skill_wei004_1`；源码 [skill_wei004_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei004_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI004 与[“X 只能当 Y 使用／打出”实现说明](../only-as.md)。
- **实现与接口**：
  - `fk.DrawNCards` 触发，在摸牌数量确定前减少 `data.n`；少摸张数等于实际选择的其他角色数。选择至多 `data.n` 名有手牌的其他角色，各获得一张手牌，使用 `fk.ReasonPrey`；目标中途无手牌时跳过。
  - 展示为可选项；确认展示后 `room:showCards` 公开获得的牌，并调用 `OnlyAs.addSource`：`def = "tuxi"`（仅开放【杀】的 `use`/`response`）、`cards = 本次实际获得的实体牌集合`、`duration = "turn"`、不传 `skill`。因此**失去突袭不会撤销**本回合已产生的限制，回合结束由 only-as 规则统一到期。
  - 直接使用／打出这些实体牌被公共 only-as 禁止；其他来源的转化权限仍按并集保留。未在技能内自行改写牌名或添加独立“只能当”技能。
- **验证依据**：[wei_support.lua](../../../../tests/wei_support.lua) 的 `testTuxiDrawReductionAndTurnRestriction`：2 张少摸为 0，获得两名角色各一张；展示后该牌被 only-as 禁止直接使用且提供【杀】转换；失去突袭后限制仍在。历史 3/3。
- **未完成与边界**：对“保留其他转化权限”仅依赖 only-as 并集语义，未新增专项组合测试；`tuxi` 来源的回合到期依赖公共 only-as 规则技能，测试未覆盖到期。

<a id="wei006-1"></a>
#### 轻辎（WEI006 郭嘉）

- **标识与依据**：运行时 ID `hanjin__skill_wei006_1`；源码 [skill_wei006_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei006_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI006。同将遗计见[伤害、体力与死亡](damage.md#wei006-2)。
- **实现与接口**：
  - 准备阶段弃置同势力其他角色装备区一张牌，令其获得“神速”直到其回合结束。
  - 临时技能授予使用 `Room:handleAddLoseSkills(player, skill, source, ...)`，来源记为轻辎；到期用同一来源 `"-" .. skillName` 移除。授予状态使用不带 `-turn` 的独立标记，不随郭嘉回合末自动清除，只在目标自己的 TurnEnd 回收。
  - 目标原有暗将神速或后获其他来源的同名技能不会被移除；同势力候选复用 hegemony 公共的 `HegUtil.compareExpectedKingdomWith`（拥有者暗置时按本人可见的 `__heg_kingdom`／`__heg_wild` 预测，他人暗置时公开势力为 `unknown`，不进入候选）。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖轻辎弃置目标装备后授予神速、施加者回合结束仍保留、目标回合结束回收、目标原有／另一来源神速不被移除；历史 14/14。
- **未完成与边界**：客户端授予技能提示与选牌未人工验收。

<a id="wei008-2"></a>
#### 设变（WEI008 夏侯渊）

- **标识与依据**：运行时 ID `hanjin__skill_wei008_2`；源码 [skill_wei008_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei008_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI008；共享工具 [wei_phases.lua](../../../../pkg/hanjin_generals/util/wei_phases.lua)。同将神速见[阶段与回合流程](phases.md#wei008-1)。
- **实现与接口**：
  - 仅 `HpLost` 触发；`can_trigger` 先检查场上确有可移动牌。
  - 移动场上牌先由引擎公共的 `Room:askToChooseToMoveCardInBoard` 在两阶段内筛出确有可移动关系的两名角色，再用 `Room:askToMoveCardInBoard`（0.5.25 `ltk/server/room.lua` 3374 行）在其中一人装备／判定区选牌移动；请求回复为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 的设变用例双方均有可移动牌（p1 藤甲、p2 武器），请求级用例历史通过；历史 14/14。曾有 90 秒超时，根因是测试直接比较 `ServerPlayer` 对象导致 LuaUnit 挂起，非请求 schema，见[共享验证证据](verification-evidence.md#设变巧变超时根因)。
- **未完成与边界**：客户端两步移牌面板未人工验收。

<a id="wei011-2"></a>
#### 励战（WEI011 曹仁）

- **标识与依据**：运行时 ID `hanjin__skill_wei011_2`；源码 [skill_wei011_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei011_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI011。同将伪溃见[用牌目标与距离](active.md#wei011-1)。
- **实现与接口**：结束阶段令任意名已受伤角色各摸一张牌。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖励战令已受伤角色摸牌；历史 14/14。
- **未完成与边界**：客户端目标选择未人工验收。

<a id="wei014-2"></a>
#### 放逐（WEI014 曹丕）

- **标识与依据**：运行时 ID `hanjin__skill_wei014_2`；源码 [skill_wei014_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei014_2.lua)。规则见[曹丕结算约定](../../../../rules/generals/wei014-caopi.md)与[叠置与平置](../../../../rulebook/terms/general-op-terms/stack.md)。同将行殇见[伤害、体力与死亡](damage.md#wei014-1)。
- **实现与接口**：
  - `fk.Damaged` 每次伤害事件一次；目标须为其他存活角色，先叠置再摸 2；手牌＋装备合计 ≥4 时可足额弃 4 并平置，弃置牌名字数之和 >7 则失去 1 点体力。
  - 国战“叠置／平置”对应引擎 `faceup`：平置 `faceup = true`，叠置 `faceup = false`。叠置仅在 `faceup` 为真时调用原生 `player:turnOver()`；已叠置不重复翻转，但后续摸牌与弃牌分支仍分别执行。
  - 摸牌后不足四张不进入弃牌分支：不平置，也不检查牌名字数、不失去体力。足够四张时由目标决定是否弃置；`min_num = max_num = 4` 保证足额，范围含手牌与装备。弃置后仅在仍为叠置时调用原生 `turnOver` 平置，再按实际弃置的四张牌逐张累计中文牌名字数（`utf8.len`），大于 7 则失去 1 点体力。
  - 使用原生翻面入口，保留 `BeforeTurnOver`／`TurnedOver` 事件、翻面跳回合流程与客户端 `faceup` 朝向显示；未修改引擎本体。
- **验证依据**：[wei_support.lua](../../../../tests/wei_support.lua) 的 `testFangzhuStackDrawDiscardAndHpLoss`：平置→叠置并摸 2；足额弃 4 后平置且牌名字数和 >7 失去体力；已有叠置目标不反转且仍摸 2；不足 4 张时不提供弃牌分支、保持叠置。历史 3/3。
- **未完成与边界**：客户端翻面朝向与弃牌交互未人工验收。

### 吴

<a id="wu001-1"></a>
#### 制衡（WU001 孙权）

- **标识与依据**：运行时 ID `hanjin__skill_wu001_1`；源码 [skill_wu001_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu001_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU001。
- **实现与接口**：弃牌不超过体力上限；本次弃完已有手牌额外摸一张。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖制衡数量与额外摸牌；历史 15/15，见[共享验证证据](verification-evidence.md#wu_support)。
- **未完成与边界**：客户端弃牌界面未人工验收。

<a id="wu003-1"></a>
#### 克己（WU003 吕蒙）

- **标识与依据**：运行时 ID `hanjin__skill_wu003_1`；源码 [skill_wu003_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu003_1.lua)。规则见[吕蒙规范](../../../../rules/generals/wu003-lvmeng.md)。同将谋断、涉猎见[本页](#wu003-2)。
- **实现与接口**：按出牌阶段使用牌的颜色判断；与谋断共享 [wu_history.lua](../../../../pkg/hanjin_mode/rules/wu_history.lua) 与[全局记录器](../../../../pkg/hanjin_mode/skills/wu_history.lua)，后者由模式启动安装，真实使用声明写入公开标记，客户端读取同步数据而不读取服务端事件树。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖克己历史判断；历史 12/12，见[共享验证证据](verification-evidence.md#wu_phases)。
- **未完成与边界**：客户端提示与人工交互未验收。

<a id="wu003-2"></a>
#### 谋断（WU003 吕蒙）

- **标识与依据**：运行时 ID `hanjin__skill_wu003_2`；源码 [skill_wu003_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu003_2.lua)。规则见[吕蒙规范](../../../../rules/generals/wu003-lvmeng.md)。同将[克己](#wu003-1)、[涉猎](#wu003-3)。
- **实现与接口**：按整回合花色／类别判断，两条件同时满足才授予后天涉猎，不立即发动。**次要机制：技能授予**（授予而非阶段流程，故本页收录）。历史写入与客户端读取同克己。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖谋断授予；历史 12/12。
- **未完成与边界**：客户端授予提示未人工验收；谋断只获得涉猎，不额外发动（依已确认规范）。

<a id="wu003-3"></a>
#### 涉猎（WU003 吕蒙）

- **标识与依据**：运行时 ID `hanjin__skill_wu003_3`；源码 [skill_wu003_3.lua](../../../../pkg/hanjin_generals/skills/skill_wu003_3.lua)。规则见[吕蒙规范](../../../../rules/generals/wu003-lvmeng.md)。以 `related = true` 登记，仅通过谋断获得，不计入天生技能数；不是独立武将技能。
- **实现与接口**：替换本次正常摸牌，以正式整理界面选择异花色牌，并服务端复核牌属于本次五张、仍在处理区且无重复花色；涉猎 poxi 注册由[共享工具](../../../../pkg/hanjin_generals/util/wu_phases.lua)提供。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖涉猎异花色；历史 12/12。
- **未完成与边界**：客户端整理界面未人工验收；作为后天技能不计入吴包天生技能数统计。

<a id="wu005-1"></a>
#### 英姿（WU005 周瑜）

- **标识与依据**：运行时 ID `hanjin__skill_wu005_1`；源码 [skill_wu005_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu005_1.lua)。规则见[周瑜规范](../../../../rules/generals/wu005-zhouyu.md)。同将反间见[本页](#wu005-2)。
- **实现与接口**：主将条件由 `MainPlace` 接线；具体摸牌加成随正式摸牌流程执行。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖英姿；历史 15/15。
- **未完成与边界**：主将／副将切换的客户端显示未人工验收。

<a id="wu005-2"></a>
#### 反间（WU005 周瑜）

- **标识与依据**：运行时 ID `hanjin__skill_wu005_2`；源码 [skill_wu005_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu005_2.lua)。规则见[周瑜规范](../../../../rules/generals/wu005-zhouyu.md)。
- **实现与接口**：交牌前快照展示花色；响应只展示手牌，弃同花色手牌与装备，检查至少两张及禁弃；弃置执行者是目标；响应有选择权。主将体力贡献 −1 按半格公共表示处理。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖反间接受与拒绝、手装弃置及拒绝；历史 15/15。
- **未完成与边界**：反间红颜组合及实际 `ProhibitSkill` 禁弃组合未单独验证；客户端点击未人工验收。

<a id="wu006-1"></a>
#### 国色（WU006 大乔，分记录）

- **标识与依据**：运行时 ID `hanjin__skill_wu006_1`；源码 [skill_wu006_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu006_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU006。转化使用与目标条件见主记录[转化 WU006](conversion.md#wu006-1)；本页只展开弃置分支与费用／限次侧。
- **实现与接口**：两分支独立限次，在交互、牌／目标筛选及执行前分别复核；弃置分支的两项费用都确认可执行后才批量移动，避免只支付一部分。使用分支的目标条件见主记录。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖国色两分支及不可重用；历史 12/12，见[共享验证证据](verification-evidence.md#wu_phases)。
- **未完成与边界**：客户端两分支选择未人工验收；复杂禁弃／费用不足组合未穷举。

<a id="wu008-1"></a>
#### 结姻（WU008 孙尚香）

- **标识与依据**：运行时 ID `hanjin__skill_wu008_1`；源码 [skill_wu008_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu008_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU008 与[装备置入](../../../../rules/equipment-movement.md)。同将枭姬见[本页](#wu008-2)。
- **实现与接口**：仅展示合法弃牌／空栏置入候选；体力相等无较大／较小收益；装备置入要求空置对应栏；客户端安全房间访问支持无 `room` 字段的真实 `ClientPlayer`。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖结姻置入及代表性真实 `ClientPlayer` 用例（无 `room` 字段下的可用性与候选）；历史 15/15。
- **未完成与边界**：客户端置入动画与人工交互未验收。

<a id="wu008-2"></a>
#### 枭姬（WU008 孙尚香）

- **标识与依据**：运行时 ID `hanjin__skill_wu008_2`；源码 [skill_wu008_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu008_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU008。
- **实现与接口**：失去装备逐张触发，回合内／外分别摸一张／两张。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖枭姬回合内外；历史 15/15。
- **未完成与边界**：客户端失去装备提示未人工验收。

<a id="wu009-1"></a>
#### 英魂（WU009 孙坚）

- **标识与依据**：运行时 ID `hanjin__skill_wu009_1`；源码 [skill_wu009_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu009_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU009。
- **实现与接口**：X 为已损失体力值；摸牌／弃牌两分支使用正式接口。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖英魂；历史 15/15。
- **未完成与边界**：客户端两分支选择未人工验收。

<a id="wu013-2"></a>
#### 奋激（WU013 周泰）

- **标识与依据**：运行时 ID `hanjin__skill_wu013_2`；源码 [skill_wu013_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu013_2.lua)。规则见[周泰规范](../../../../rules/generals/wu013-zhoutai.md)。同将不屈见[伤害、体力与死亡](damage.md#wu013-1)。
- **实现与接口**：按真实“失去全部手牌”历史选择目标；使用中性 `hanjin_wu_fenxun_target-turn` 标记与[模式距离技能](../../../../pkg/hanjin_mode/skills/wu_distance_effects.lua)，失去来源技能不提前终止，也不随来源前缀被交换机制迁移。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖奋激及失技后持续；历史 22/22。
- **未完成与边界**：客户端目标选择未人工验收。

<a id="wu014-1"></a>
#### 好施（WU014 鲁肃）

- **标识与依据**：运行时 ID `hanjin__skill_wu014_1`；源码 [skill_wu014_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu014_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU014。同将缔盟见[本页](#wu014-2)。
- **实现与接口**：将多摸后的给牌承诺绑在本次摸牌事件数据上，由静态辅助完成；失去好施不取消已承诺给牌，也不跨摸牌阶段泄漏。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖好施承诺后失技、好施与缔盟来源到期；历史 22/22。
- **未完成与边界**：客户端给牌交互未人工验收。

<a id="wu014-2"></a>
#### 缔盟（WU014 鲁肃）

- **标识与依据**：运行时 ID `hanjin__skill_wu014_2`；源码 [skill_wu014_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu014_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU014。到期辅助 [wu_dimeng_expiry.lua](../../../../pkg/hanjin_mode/skills/wu_dimeng_expiry.lua)。
- **实现与接口**：使用可弃牌支付手牌数差，真实交换后按 FAQ 授予纵横好施至目标下个回合结束；来源级移除不删除其他来源的同名技能。差为零不能支付弃置消耗，依公共消耗规范处理。到期辅助在加载期注册、模式启动预装，不在房间运行期创建客户端未知的技能；角色时效标记采用中性名。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖缔盟交换与多来源到期；历史 22/22。
- **未完成与边界**：客户端交换界面未人工验收。

<a id="wu015a-1"></a>
#### 直谏（WU015A 张昭）

- **标识与依据**：运行时 ID `hanjin__skill_wu015a_1`；源码 [skill_wu015a_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu015a_1.lua)。规则见[张昭规范](../../../../rules/generals/wu015a-zhangzhao.md)与[装备置入](../../../../rules/equipment-movement.md)。同将固政见[本页](#wu015a-2)。
- **实现与接口**：手牌区→你摸牌、装备区→其摸牌的顺序对应；装备置入要求空置对应栏；仅展示合法候选。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖直谏两来源（手牌／装备区决定摸牌者）与空栏；历史 15/15。
- **未完成与边界**：客户端置入面板未人工验收。

<a id="wu015a-2"></a>
#### 固政（WU015A 张昭）

- **标识与依据**：运行时 ID `hanjin__skill_wu015a_2`；源码 [skill_wu015a_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu015a_2.lua)。规则见[张昭规范](../../../../rules/generals/wu015a-zhangzhao.md)。
- **实现与接口**：同事件多个弃牌者由玩家择一，只取该角色本事件仍在弃牌堆的牌，返一后批量取得至多三张。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖固政同事件多弃牌者选择；历史 15/15。
- **未完成与边界**：客户端弃牌者选择未人工验收。

### 晋

<a id="jin001-1"></a>
#### 垂统（JIN001 司马炎）

- **标识与依据**：运行时 ID `hanjin__skill_jin001_1`；源码 [skill_jin001_1.lua](../../../../pkg/hanjin_generals/skills/skill_jin001_1.lua)。规则见[司马炎规范](../../../../rules/generals/jin001-simayan.md)与[装备移动通则](../../../../rules/equipment-movement.md)。同将兴图见[转化与生成用牌](conversion.md#jin001-2)。
- **实现与接口**：
  - `fk.EnterDying` 提供一次发动机会，`target` 为进入濒死的其他角色；`target == player` 直接排除，不按敌友或势力筛选。未改为监听求桃，同一濒死流程不会按求桃次数反复触发。
  - 候选牌只取该角色装备区中 `target:canMoveCardInBoardTo(player, id)` 为真的牌；该锁定接口检查目标栏存在、未废除且为空，并排除目标为自己；已有同类装备、废除栏或无牌时 `can_trigger` 不成立。
  - 发动者从复核后的候选牌中选择一张（`Room:askToChooseCard`，候选以 `$Equip` 列表给出）；选择后再次复核来源归属、双方存活与 `canMoveCardInBoardTo`，再调用 `Room:moveCardIntoEquip(player, card, skill, false, target)`。`convert = false` 保证不替换目标已有装备；移动进入对应空栏而非手牌，并按正常移牌触发失去／得到装备结算。
  - 发动在 `askToSkillInvoke` 处可取消；取消、候选为空或复核失败时不移动。
- **验证依据**：[jin001_simayan.lua](../../../../tests/jin001_simayan.lua) 覆盖其他角色进入濒死时移入空置对应栏且非手牌；同类栏已占用、废除栏、无牌、取消、自己濒死均不移动；`hp = 0` 的完整濒死流程只提供一次发动；主将、副将、暗置预亮来源均验证。历史 17/17，见[共享验证证据](verification-evidence.md#jin001_simayan)。
- **未完成与边界**：未应用开发适配的本体人工交互验收尚未执行；规范化描述待办见[司马炎入口](jin001-simayan.md#jin001-todo)。
