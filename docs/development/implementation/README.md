# 实现与验证导航

本目录存放从项目规范迁出的接口、接线及验收依据，不是正式规则条文。当前完成度见[开发状态](../status.md)；规则与实现不一致时按[开发流程](../README.md)处理。

- [鏖战状态：实现与验证](battle-royal.md)
- [紫乔汉晋国战：同一张牌的多次结算：实现与验证](card-resolution.md)
- [紫乔汉晋国战：效果指定的用牌目标条件：实现与验证](card-use-targets.md)
- [统领与翼从：实现与验证](commander-retinue.md)
- [紫乔汉晋国战：指定额外目标：实现与验证](extra-targets.md)
- [紫乔汉晋国战：势力禁选规范：实现与验证](faction-ban.md)
- [交换武将：实现与验证](general-exchange.md)
- [客将：实现与验证](guest-factions.md)
- [“X 只能当 Y 使用／打出”：实现与验证](only-as.md)
- [第二君主：实现与验证](second-lord.md)
- [野心家效忠：实现与验证](wild-allegiance.md)
- [紫乔汉晋国战：应变规范：实现与验证](adaptation.md)
- [紫乔汉晋国战：基础牌表：实现与验证](card-deck.md)

## 武将与翼从

- [汉势力标准包：全 15 将 25 技能及穆顺、西园军实现与验证](generals/han-standard.md)：全包入口，汇总逐将实现说明、专项测试、发布接线与验收边界；刘协等武将的详细记录由此进入。
- [JIN001 司马炎：垂统、兴图实装与验证](generals/jin001-simayan.md)

新入口须区分只选择、返回待执行数据和已执行，核对当前事件数据的类型及客户端可见信息。上游接口以 `dependencies.lock.json` 锁定版本的本地源码核实，外部规则资料中的 API 引用仅供查找。
