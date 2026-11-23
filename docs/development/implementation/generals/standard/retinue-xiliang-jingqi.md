# 西凉精骑

[翼从索引](../retinues.md)

<a id="xiliang-jingqi"></a>

## 西凉精骑

- **标识与依据**：`qiao__retinue_skill_xiliang_jingqi`；[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_xiliang_jingqi.lua)；[标准翼从表](../../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑资料的统领条目](../../../../../assets/docs/石激桑武将列表.json#L2788)。

> 结束阶段，你可以使用一张【杀】；当你使用【杀】指定攻击范围内没有你的角色为目标后，你可以令其弃置一张牌。

- **实现与接口**：结束阶段选择实际手牌／转化杀，正确传递四种杀名、pattern、bypass_times 与 extraUse，恰执行一次；目标攻击范围内无持有者时，可令目标自行强制弃一张牌。
- **验证依据**：[shu_retinues.lua](../../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](../verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。
