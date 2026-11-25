# 飞熊军

[翼从索引](../retinues.md) · [返回分包索引](../bian.md)

<a id="feixiongjun"></a>

## 飞熊军

- **标识与依据** · 变包普通翼从 `qiao_heg__retinue_feixiongjun`（李傕 `QUN022A` 统领牌【火攻】），运行时技能 ID `qiao__retinue_skill_feixiongjun`。见[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_feixiongjun.lua)、[变包公共辅助](../../../../../pkg/qiao_generals/util/bian_common.lua)和[李傕逐将规则](../../../../rules/generals/qun022a-lijue.md#关联翼从飞熊军)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json)。

> 限定技，出牌阶段，你可以选择一名体力值与你相同的其他角色，依次视为对其使用一张【顺手牵羊】和一张【杀】。

- **实现与接口** · 通过 `retinue_instances.lua` 与 `bian_common.lua` 维护同名多份实例的独立限定次数，并在公开标记 `qiao_bian_retinue_limited` 同步给客户端用于按钮可用性判定。出牌阶段选择一名体力值相同的在场其他角色，消耗一份未用实例后依次视为对其使用无视距离的【顺手牵羊】（目标区域无牌时跳过）与无视距离及次数的普通【杀】。支持被李傕【凶算】在回合末逐份复原。
- **验证依据** · [bian_wu_qun_jin.lua](../../../../../tests/bian_wu_qun_jin.lua#L350)。覆盖两份同名实例各自独立发动、远距离顺手牵羊与杀无视距离、目标无牌跳过顺手牵羊仍出杀，以及【凶算】复原接口。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
