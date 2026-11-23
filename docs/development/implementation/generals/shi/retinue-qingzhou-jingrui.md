# 青州精锐

[翼从索引](../retinues.md) · [返回分包索引](../shi.md)

<a id="qingzhou-jingrui"></a>

## 青州精锐

- **标识与依据** · 势包翼从 `qiao_heg__retinue_qingzhou_jingrui`，运行时技能 ID `qiao__retinue_skill_qingzhou_jingrui`。见[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_qingzhou_jingrui.lua)和[统领与翼从规则](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑资料的统领条目](../../../../../assets/docs/石激桑武将列表.json#L3487)。

> 出牌阶段限一次，你可以令一名手牌数最小的角色选择一项：1.弃置一张手牌；2.你对其造成1点伤害。

- **实现与接口** · 出牌阶段从公开在场角色中筛出手牌数最少者。被选者可弃一张合法手牌，选择受伤时由发动者对其造成 1 点伤害。次数按实际发动的翼从实例记录。
- **验证依据** · [zhen_shi_retinues.lua](../../../../../tests/zhen_shi_retinues.lua#L125)。回归覆盖并列最少的合法候选、每实例限次和客户端可用性。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
