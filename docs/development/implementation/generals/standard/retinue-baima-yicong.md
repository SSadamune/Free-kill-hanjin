# 白马义从

[翼从索引](../retinues.md)

<a id="baima-yicong"></a>

## 白马义从

- **标识与依据**：`qiao__retinue_skill_baima_yicong`；[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_baima_yicong.lua)；[标准翼从表](../../../../rules/standard-generals.md#翼从)与[统领与翼从](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑资料的统领条目](../../../../../assets/docs/石激桑武将列表.json#L3019)。

> 当你使用或打出【闪】时，你可以获得对方的一张牌。

- **实现与接口**：CardUsing／CardResponding 两入口定位 responseToEvent.from，在使用／打出闪时获得对方一张手牌或装备；包含虚拟闪，不按响应牌当前持有者猜对方。
- **验证依据**：[shu_retinues.lua](../../../../../tests/shu_retinues.lua) 七项核心流程；[共享证据](../verification-evidence.md#shu-standard)。
- **未完成与边界**：真实客户端、联网与重连未人工验收；公共统领能力及翼从来源沿用独立公共机制。
