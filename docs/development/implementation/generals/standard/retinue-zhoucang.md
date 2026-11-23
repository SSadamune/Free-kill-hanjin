# 周仓

[翼从索引](../retinues.md)

<a id="zhoucang"></a>

## 周仓

- **标识与依据**：`qiao__retinue_skill_zhoucang`；[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_zhoucang.lua)；[标准翼从表](../../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L3685)的统领条目。

> 当你使用【杀】后，你可以将此【杀】或目标角色使用的【闪】交给另一名其他角色，若其以此法获得红色牌，其可以对你攻击范围内的一名角色使用一张【杀】。

- **实现与接口**：杀后从仍可取得的本次杀或目标闪实体牌中选牌给第三人；红牌受赠者以实际手牌／转化使用杀，显式目标条件读取周仓攻击范围，选择及执行沿用同一策略，绕过通常次数且不计次。
  `in_attack_range_of` 是由双方共用的公开条件。客户端与服务端都按周仓的攻击范围筛选，服务端独立读取阶段历史和抵消事件。
- **验证依据**：[shu_retinues.lua](../../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](../verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。
