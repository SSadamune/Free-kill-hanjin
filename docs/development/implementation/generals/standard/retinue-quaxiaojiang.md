# 曲阿小将

[翼从索引](../retinues.md)

<a id="quaxiaojiang"></a>

## 曲阿小将

- **标识与依据**：翼从 ID `qiao_heg__retinue_quaxiaojiang`，技能 ID `qiao__retinue_skill_quaxiaojiang`；源码 [retinue_skill_quaxiaojiang.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_quaxiaojiang.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从曲阿小将与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为太史慈（WU012）。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L6251)的统领条目。

> 每回合限一次，当你使用牌后，若此牌目标与你本回合上一张使用牌的目标不完全相同，你可以对这两张牌的重合目标各造成1点伤害。

- **实现与接口**：读取服务器真实 `GameEvent.UseCard` 历史，按事件顺序取得当前使用前的上一张牌，包含同回合获得技能前的使用；不以结算完成顺序误认嵌套用牌。两次目标不完全相同时，可对重合存活目标各造成一点伤害，每回合限一次。
- **验证依据**：[wu_damage.lua](../../../../../tests/wu_damage.lua) 覆盖曲阿小将完整两次用牌及重合目标伤害。
- **未完成与边界**：复杂嵌套／改目标组合未逐项新增独立用例；客户端与联网／重连未人工验收。
