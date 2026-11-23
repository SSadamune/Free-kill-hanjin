# 象兵

[翼从索引](../retinues.md)

<a id="xiangbing"></a>

## 象兵

- **标识与依据**：`qiao__retinue_skill_xiangbing`；[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_xiangbing.lua)；[标准翼从表](../../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L3527)的统领条目。

> 锁定技，当你使用【杀】后，你视为对受到此【杀】伤害的目标角色使用一张【南蛮入侵】；当你受到火焰伤害后，你视为对所有相邻角色使用一张【杀】。

- **实现与接口**：杀后按实际伤害记录与该杀目标集合的交集，一次生成南蛮；火伤后按座次相邻且去重的集合，一次生成杀；显式目标数量等于选定集合。火伤生成的杀造成伤害后仍正常触发杀后南蛮，不添加无依据豁免。
- **验证依据**：[shu_retinues.lua](../../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](../verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。
