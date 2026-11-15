# 实现与验证导航

本目录存放从项目规范迁出的接口、接线及验收依据，不是正式规则条文。当前完成度见[开发状态](../status.md)；规则与实现不一致时按[开发流程](../README.md)处理。

## 武将与翼从

- [汉势力标准包](generals/han-standard.md)
- [魏势力标准包](generals/wei-standard.md)
- [蜀势力标准包](generals/shu-standard.md)
- [吴势力标准包](generals/wu-standard.md)
- [群势力标准包逐将检索](generals/qun-standard.md)（验证结果见开发状态及对应验证记录）
- [晋势力标准包](generals/jin001-simayan.md)

## 基础机制

- [鏖战状态](battle-royal.md)
- [同一张牌的多次结算](card-resolution.md)
- [效果指定的用牌目标条件](card-use-targets.md)
- [统领与翼从](commander-retinue.md)
- [指定额外目标](extra-targets.md)
- [势力禁选规范](faction-ban.md)
- [交换武将](general-exchange.md)
- [客将](guest-factions.md)
- [“X 只能当 Y 使用／打出”](only-as.md)
- [第二君主](second-lord.md)
- [野心家效忠](wild-allegiance.md)
- [应变规范](adaptation.md)
- [基础牌表](card-deck.md)

## 效果分类

| 机制 | 范围 | 技能和效果 |
| --- | --- | --- |
| [伤害、体力与死亡](generals/damage.md) | 受伤触发、造成伤害、伤害修正、失去体力、死亡结算 | [毒逝](generals/damage.md#han002-2)、[构难](generals/damage.md#han005-2)、[连计](generals/damage.md#han006-1)、[追德](generals/damage.md#han007-2)、[哀舞](generals/damage.md#han011-1)、[诀别](generals/damage.md#han011-2)、[奸雄](generals/damage.md#wei001-1)、[狼顾](generals/damage.md#wei002-1)、[刚烈](generals/damage.md#wei003-1)、[裸衣](generals/damage.md#wei005-1)、[遗计](generals/damage.md#wei006-2)、[强袭](generals/damage.md#wei012-1)、[节命](generals/damage.md#wei013-2)、[行殇](generals/damage.md#wei014-1)、[骁果](generals/damage.md#wei016-1)、[狂骨](generals/damage.md#shu009-1)、[涅槃](generals/damage.md#shu010-2)、[祸首](generals/damage.md#shu014-1)、[苦肉](generals/damage.md#wu004-1)、[诈降](generals/damage.md#wu004-2)、[天香](generals/damage.md#wu011-1)、[不屈](generals/damage.md#wu013-1)、[济世](generals/damage.md#qun001-1)、[完杀](generals/damage.md#qun007-1)、[雷击](generals/damage.md#qun010-1)、[断肠](generals/damage.md#qun012-2)、[随势](generals/damage.md#qun016-2)、[夷灭](generals/damage.md#jin002-2)、[悖弑](generals/damage.md#jin004-2)、[顺流](generals/damage.md#jin005-2)、[扼绝](generals/damage.md#jin010-2)、[乘流](generals/damage.md#jin013-1) |
| [辅助与牌资源](generals/support.md) | 摸弃移配、手牌上限、给牌与技能授予；“辅助”不限于友方 | [天命](generals/support.md#han001-1)、[诗怨](generals/support.md#han002-1)、[敏思](generals/support.md#han007-1)、[铸典](generals/support.md#han012-1)、[集兵](generals/support.md#han018-1)、[持重](generals/support.md#wei003-2)、[突袭](generals/support.md#wei004-1)、[轻辎](generals/support.md#wei006-1)、[设变](generals/support.md#wei008-2)、[励战](generals/support.md#wei011-2)、[放逐](generals/support.md#wei014-2)、[观星](generals/support.md#shu004-1)、[集智](generals/support.md#shu007-1)、[藏机](generals/support.md#shu007-2)、[再起](generals/support.md#shu014-2)、[巨象](generals/support.md#shu015-1)、[淑慎](generals/support.md#shu016-1)、[神智](generals/support.md#shu016-2)、[制衡](generals/support.md#wu001-1)、[克己](generals/support.md#wu003-1)、[谋断](generals/support.md#wu003-2)、[涉猎](generals/support.md#wu003-3)、[英姿](generals/support.md#wu005-1)、[反间](generals/support.md#wu005-2)、[结姻](generals/support.md#wu008-1)、[枭姬](generals/support.md#wu008-2)、[英魂](generals/support.md#wu009-1)、[奋激](generals/support.md#wu013-2)、[好施](generals/support.md#wu014-1)、[缔盟](generals/support.md#wu014-2)、[直谏](generals/support.md#wu015a-1)、[固政](generals/support.md#wu015a-2)、[除疠](generals/support.md#qun001-2)、[闭月](generals/support.md#qun003-2)、[雄异](generals/support.md#qun013-2)、[死谏](generals/support.md#qun016-1)、[倾城](generals/support.md#qun018-2)<br>[国色·弃置分支](generals/support.md#wu006-1)、[垂统](generals/support.md#jin001-1)、[泰然](generals/support.md#jin002-1)、[昭然](generals/support.md#jin003-1)、[通法](generals/support.md#jin004-1)、[识人](generals/support.md#jin007-1)、[恤下](generals/support.md#jin007-2)、[宜室](generals/support.md#jin008-1)、[权变](generals/support.md#jin009-1)、[果毅](generals/support.md#jin011-1)、[弘训](generals/support.md#jin012-2)、[膂力](generals/support.md#jin014-1)、[复礼](generals/support.md#jin016-1)、[风物](generals/support.md#jin016-2) |
| [转化与生成用牌](generals/conversion.md) | 视为牌／view-as、以转化结果使用或打出、生成虚拟牌并使用 | [滔乱](generals/conversion.md#han004-1)、[定著](generals/conversion.md#han006-2)、[博通](generals/conversion.md#han012-2)、[劲弩](generals/conversion.md#han016a-1)、[倾国](generals/conversion.md#wei007-1)、[断粮](generals/conversion.md#wei010-1)、[仁德](generals/conversion.md#shu001-1)、[武圣](generals/conversion.md#shu002-1)、[龙胆](generals/conversion.md#shu005-1)、[连环](generals/conversion.md#shu010-1)、[八阵](generals/conversion.md#shu011-1)、[火计](generals/conversion.md#shu011-2)、[看破](generals/conversion.md#shu011-3)、[奇袭](generals/conversion.md#wu002-1)、[国色](generals/conversion.md#wu006-1)、[度势](generals/conversion.md#wu007-2)、[乱击](generals/conversion.md#qun004-1)、[双雄](generals/conversion.md#qun005-1)、[双刃](generals/conversion.md#qun015-1)、[狂斧](generals/conversion.md#qun017-1)、[骁逆](generals/conversion.md#qun027-2)、[兴图](generals/conversion.md#jin001-2)、[柔克](generals/conversion.md#jin005-1)、[骤霆](generals/conversion.md#jin009-2)、[伤逝](generals/conversion.md#jin010-1) |
| [用牌目标与距离](generals/active.md) | 主动用牌、额外／强制目标、抵消与转移、距离修正 | [谋诛](generals/active.md#han005-1)、[求援](generals/active.md#han008-2)、[谋溃](generals/active.md#han009-1)、[长驱](generals/active.md#wei010-2)、[伪溃](generals/active.md#wei011-1)、[咆哮](generals/active.md#shu003-1)、[空城](generals/active.md#shu004-2)、[突阵](generals/active.md#shu005-2)、[马术](generals/active.md#shu006-1)（含 QUN008/QUN013/QUN027 来源）、[铁骑](generals/active.md#shu006-2)、[烈勇](generals/active.md#shu008-1)、[享乐](generals/active.md#shu013-1)、[流离](generals/active.md#wu006-2)、[谦逊](generals/active.md#wu007-1)、[短兵](generals/active.md#wu016-1)、[奋迅](generals/active.md#wu016-2)、[离间](generals/active.md#qun003-1)、[无双](generals/active.md#qun002-1)、[虓猛](generals/active.md#qun002-2)、[乱武](generals/active.md#qun007-2)、[帷幕](generals/active.md#qun007-3)、[猛撼](generals/active.md#qun008-2)、[祸水](generals/active.md#qun018-1)<br>[驱虎·没赢分支](generals/active.md#wei013-1)、[天义·持续用杀修正](generals/active.md#wu012-1)、[挟征](generals/active.md#jin003-2)、[慈威](generals/active.md#jin012-1)、[克清](generals/active.md#jin013-2)、[前驱](generals/active.md#jin015-1) |
| [阶段与回合流程](generals/phases.md) | 阶段替换、跳过与重排（不收一切阶段时机触发） | [威屯](generals/phases.md#han016a-2)、[神速](generals/phases.md#wei008-1)、[巧变](generals/phases.md#wei009-1)、[放权](generals/phases.md#shu013-2)、[夺气](generals/phases.md#jin014-2) |
| [拼点](generals/pindian.md) | 发起拼点、结果分支、拼点牌取得与点数修正 | [密诏](generals/pindian.md#han001-2)、[惴恐](generals/pindian.md#han008-1)、[承诏](generals/pindian.md#han010-1)、[奋钺](generals/pindian.md#han013-1)、[戡难](generals/pindian.md#han017-1)、[逆拒](generals/pindian.md#han017-2)、[驱虎](generals/pindian.md#wei013-1)、[烈刃](generals/pindian.md#shu015-2)、[天义](generals/pindian.md#wu012-1)、[酣战](generals/pindian.md#wu012-2)、[识度](generals/pindian.md#jin008-2) |
| [判定与花色](generals/retrial.md) | 改判、判定结果处理、花色视为与过滤 | [鹰视](generals/retrial.md#wei002-2)、[洛神](generals/retrial.md#wei007-2)、[红颜](generals/retrial.md#wu011-2)、[鬼道](generals/retrial.md#qun010-2)、[悲歌](generals/retrial.md#qun012-1) |
| [配将体力](generals/pair-hp.md) | 配将体力贡献修正及开局／升变复用 | [应期](generals/pair-hp.md#wei002-3)（WEI002；JIN009 同文共享，来源在该条记录） |
| [翼从专属技能](generals/retinues.md) | 汉、魏、蜀、吴、群、晋翼从的专属技能（统领能力另见公共机制） | [穆顺](generals/retinues.md#mushun)、[西园军](generals/retinues.md#xiyuanjun)、[并州狼骑](generals/retinues.md#bingzhou-langqi)、[虎卫军](generals/retinues.md#huweijun)、[牛金](generals/retinues.md#niujin)、[周仓](generals/retinues.md#zhoucang)、[白马义从](generals/retinues.md#baima-yicong)、[西凉精骑](generals/retinues.md#xiliang-jingqi)、[象兵](generals/retinues.md#xiangbing)、[锦帆军](generals/retinues.md#jinfanjun)、[曲阿小将](generals/retinues.md#quaxiaojiang)、[黄巾雷使](generals/retinues.md#huangjin-leishi)、[腹心死士](generals/retinues.md#fuxin-sishi)、[文虎](generals/retinues.md#wenhu) |

## 共享验证证据与历史记录

- [共享验证证据](generals/verification-evidence.md)：按原测试文件集中保存一次历史命令输出、日期与故障根因，各技能条目引用而不重复。
- 实现与验证状态总览仍见[开发状态](../status.md)；测试分层见[测试规范](../testing.md)；故障案例见[故障案例](../lessons.md)。

<details>
<summary>分类与检索约定</summary>

武将技能按**技能**存储：每个技能有一份主记录，收在其主要机制页；确有两套机制各自复杂（两侧都有独立接口与测试）的技能，可在第二个机制页设分记录，只写该侧实现与测试并互相链接，不复制整段正文。轻量关联只以锚点交叉引用。

- 机制页按“技能的主要效果”归类，不按原测试套件分组或 DSH 开发批次；阶段时机触发不等于阶段流程，授予技能不等于阶段流程。
- 技能索引表全站统一为三列：编号、武将、技能（技能列内链接）；分记录的技能在链接后括注“分记录”并交叉链接主记录。
- 每条技能条目统一四小节，顺序固定：**标识与依据**（运行时 ID／源码／规则链接）、**实现与接口**、**验证依据**、**未完成与边界**。
- 排序统一为汉→魏→蜀→吴→群→晋；同势力编号升序，同将技能保持原顺序。当前资料六势力均有条目；马术的 QUN008、QUN013、QUN027 复用 `#shu006-1`，不重复正文。
- 锚点与骨架编号对应：`#han001-1`、`#wei002-3`、`#wu015a-1`；HAN016A 用 `#han016a-1`（运行时仍为 `hanjin__han016`）。翼从保留 `#mushun`、`#xiyuanjun` 等统一 ID。晋司马懿的同文应期不重复正文，只在 [WEI002 应期条目](generals/pair-hp.md#wei002-3)记录 `jin009-3` 来源。

新入口须区分只选择、返回待执行数据和已执行，核对当前事件数据的类型及客户端可见信息。上游接口以 `dependencies.lock.json` 锁定版本的本地源码核实，外部规则资料中的 API 引用仅供查找。

</details>
