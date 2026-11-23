# 锦帆军

[翼从索引](../retinues.md)

<a id="jinfanjun"></a>

## 锦帆军

- **标识与依据**：翼从 ID `qiao_heg__retinue_jinfanjun`，技能 ID `qiao__retinue_skill_jinfanjun`；源码 [retinue_skill_jinfanjun.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_jinfanjun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从锦帆军与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为甘宁（WU002）。

牌面采用[项目登记](../../../../../pkg/qiao_generals/data/standard.lua)的文字。来源与共通说明见[统领与翼从](../../../../rules/commander-retinue.md)。

> 每回合每颜色限一次，当你弃置牌后，你可以弃置一张同颜色的牌并摸两张牌。

- **实现与接口**：依据真实 `ReasonDiscard` 操作者与弃牌颜色；每回合每颜色限一次，支付同色可弃牌后摸二；技能自身支付颜色牌的第二次弃置不再触发。颜色次数用 `-turn` 标记，每种颜色各自一次。统领能力与翼从效果沿用[公共规范](../../../../rules/commander-retinue.md)，不在专属技能中重写。
- **验证依据**：[wu_damage.lua](../../../../../tests/wu_damage.lua) 覆盖锦帆军真实弃牌。
- **未完成与边界**：同回合红黑组合、复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。
