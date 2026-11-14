# 实现与验证导航

本目录存放从项目规范迁出的接口、接线及验收依据，不是正式规则条文。当前完成度见[开发状态](../status.md)；规则与实现不一致时按[开发流程](../README.md)处理。

- [鏖战状态：实现与验证](battle-royal.md)
- [同一张牌的多次结算：实现与验证](card-resolution.md)
- [效果指定的用牌目标条件：实现与验证](card-use-targets.md)
- [统领与翼从：实现与验证](commander-retinue.md)
- [指定额外目标：实现与验证](extra-targets.md)
- [势力禁选规范：实现与验证](faction-ban.md)
- [交换武将：实现与验证](general-exchange.md)
- [客将：实现与验证](guest-factions.md)
- [“X 只能当 Y 使用／打出”：实现与验证](only-as.md)
- [第二君主：实现与验证](second-lord.md)
- [野心家效忠：实现与验证](wild-allegiance.md)
- [应变规范：实现与验证](adaptation.md)
- [基础牌表：实现与验证](card-deck.md)

## 武将与翼从

- [吴势力标准包：实现与验证](generals/wu-standard.md)：15 将 27 个天生技能、后天涉猎及两翼从的逐将索引、真实验证与发布状态。
- [汉势力标准包：全 15 将 25 技能及穆顺、西园军实现与验证](generals/han-standard.md)：汉区逐将总表，按编号、运行时 ID、源码和机制专项检索。
- [魏势力标准包：全 15 将 25 技能及并州狼骑、虎卫军、牛金实现与验证](generals/wei-standard.md)：魏区逐将总表，按编号、运行时 ID、源码和机制专项检索。
- [JIN001 司马炎：垂统、兴图实装与验证](generals/jin001-simayan.md)
- [WEI002／JIN009 司马懿：应期与配将体力贡献](generals/pair-hp.md)：开局与升变共用计算；晋司马懿仅应期随本批接入。

### 机制专项入口（跨势力共用）

按武将编号、运行时 ID 或源码查找，先看[汉包逐将总表](generals/han-standard.md#1-分组与逐将入口)、[魏包逐将总表](generals/wei-standard.md#1-分组与逐将入口)或[吴包逐将总表](generals/wu-standard.md#1-分组与逐将入口)。同一个机制只维护一份专项正文；整将记录放在其主要机制组，其他组以锚点引用，不复制逐将正文。

| 机制专项 | 汉包覆盖 | 魏包覆盖 | 吴包覆盖 |
| --- | --- | --- | --- |
| [受伤、伤害与死亡](generals/damage.md) | [唐姬](generals/damage.md#han011)（哀舞、诀别） | 奸雄、狼顾、刚烈、裸衣、遗计、节命、行殇、骁果 | 苦肉、诈降、天香、红颜、不屈、奋激、好施、缔盟 |
| [支持、手牌与状态](generals/support.md) | [刘辩](generals/support.md#han002)（诗怨、毒逝）、[王荣](generals/support.md#han007)（敏思、追德） | 持重、突袭、放逐及行殇牌区修正 | 制衡、奇袭、英姿、反间、结姻、枭姬、英魂、直谏、固政 |
| [阶段、转换与限定技](generals/phases.md) | [张让](generals/phases.md#han004)（滔乱）、[蔡邕](generals/phases.md#han012)（铸典、博通）、[刘宠](generals/phases.md#han016a)（劲弩、威屯）、[蹇硕](generals/phases.md#han018)（集兵） | 轻辎、倾国、洛神、神速、设变、巧变、断粮、励战 | 克己、谋断、涉猎、国色、流离、谦逊、度势、短兵、奋迅 |
| [主动、用牌与目标](generals/active.md) | [何进](generals/active.md#han005)（谋诛、构难）、[伏完](generals/active.md#han009)（谋溃） | 长驱、伪溃、强袭、驱虎；公开伤害记录与持续距离 | 主动交互见支持组；国色、流离、短兵、奋迅见阶段组 |
| [拼点](generals/pindian.md) | [刘协](generals/pindian.md#han001)（天命、密诏）、[王允](generals/pindian.md#han006)（连计、定著）、[伏皇后](generals/pindian.md#han008)（惴恐、求援）、[董承](generals/pindian.md#han010)（承诏）、[皇甫嵩](generals/pindian.md#han013)（奋钺）、[刘繇](generals/pindian.md#han017)（戡难、逆拒） | 驱虎的拼点分支随[主动、用牌与目标](generals/active.md)整将记录，不另复制 | 天义、酣战 |
| [改判](generals/retrial.md) | — | 鹰视真实打出与判定替换 | — |
| [配将体力](generals/pair-hp.md) | — | 应期的开局贡献、身份判定及升变复用 | — |
| [翼从](generals/retinues.md) | [穆顺](generals/retinues.md#mushun)、[西园军](generals/retinues.md#xiyuanjun) | 并州狼骑、虎卫军、牛金的专属技能；统领能力仍见公共机制文档 | 锦帆军、曲阿小将 |

新入口须区分只选择、返回待执行数据和已执行，核对当前事件数据的类型及客户端可见信息。上游接口以 `dependencies.lock.json` 锁定版本的本地源码核实，外部规则资料中的 API 引用仅供查找。
