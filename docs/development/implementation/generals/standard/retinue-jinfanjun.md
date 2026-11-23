# 锦帆军

[翼从索引](../retinues.md)

<a id="jinfanjun"></a>

## 锦帆军

- **标识与依据**：翼从 ID `qiao_heg__retinue_jinfanjun`，技能 ID `qiao__retinue_skill_jinfanjun`；源码 [retinue_skill_jinfanjun.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_jinfanjun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从锦帆军与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为甘宁（WU002）。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L6038)中甘宁（WU002）的统领条目。[乔剪国战表格.xlsx](../../../../../assets/docs/乔剪国战表格.xlsx)「兵情篇」J20 同文。

> 每回合每颜色限一次，你弃置任意角色的牌后，你可以弃置一张其中包含的颜色的牌，然后摸两张牌。

当前显示「每回合每颜色限一次，当你弃置牌后，你可以弃置一张同颜色的牌并摸两张牌。」与同一工作簿「官方范围」J63 同文。石激桑版本写明了任意角色的牌，并以该次所弃各牌包含的颜色为支付候选。

- **实现与接口**：依据真实 `ReasonDiscard` 操作者与弃牌颜色；每回合每颜色限一次，支付同色可弃牌后摸二；技能自身支付颜色牌的第二次弃置不再触发。颜色次数用 `-turn` 标记，每种颜色各自一次。统领能力与翼从效果沿用[公共规范](../../../../rules/commander-retinue.md)，不在专属技能中重写。
- **验证依据**：[wu_damage.lua](../../../../../tests/wu_damage.lua) 覆盖锦帆军真实弃牌。
- **未完成与边界**：同回合红黑组合、复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。
