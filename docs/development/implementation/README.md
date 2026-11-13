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

- [汉势力标准包：全 15 将 25 技能及穆顺、西园军实现与验证](generals/han-standard.md)：全包入口，汇总逐将实现说明、专项测试、发布接线与验收边界；刘协等武将的详细记录由此进入。
- [魏势力标准包：全 15 将 25 技能及并州狼骑、虎卫军、牛金实现与验证](generals/wei-standard.md)：魏区总入口，按受伤/伤害、主动/距离、阶段/转换、改判、配将体力、翼从分组进入专项说明与真实验证状态。
- [JIN001 司马炎：垂统、兴图实装与验证](generals/jin001-simayan.md)
- [WEI002／JIN009 司马懿：应期与配将体力贡献](generals/wei-pair-hp.md)：开局与升变共用计算；晋司马懿仅应期随本批接入。

### 魏势力专项入口

按武将编号、运行时 ID 或源码查找，先看[魏包逐将总表](generals/wei-standard.md#1-分组与逐将入口)。多个武将共用同一组说明，不另复制逐将正文。

| 分组 | 覆盖技能／机制 |
| --- | --- |
| [受伤／伤害](generals/wei-damage.md) | 奸雄、狼顾、刚烈、裸衣、遗计、节命、行殇、骁果 |
| [支持与状态](generals/wei-support.md) | 持重、突袭、放逐及行殇牌区修正 |
| [阶段与转换](generals/wei-phases.md) | 轻辎、倾国、洛神、神速、设变、巧变、断粮、励战 |
| [主动与距离](generals/wei-active.md) | 长驱、伪溃、强袭、驱虎；公开伤害记录与持续距离 |
| [改判](generals/wei-retrial.md) | 鹰视真实打出与判定替换 |
| [配将体力](generals/wei-pair-hp.md) | 应期的开局贡献、身份判定及升变复用 |
| [翼从](generals/wei-retinues.md) | 并州狼骑、虎卫军、牛金的专属技能；统领能力仍见公共机制文档 |

新入口须区分只选择、返回待执行数据和已执行，核对当前事件数据的类型及客户端可见信息。上游接口以 `dependencies.lock.json` 锁定版本的本地源码核实，外部规则资料中的 API 引用仅供查找。
