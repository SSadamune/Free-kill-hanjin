# 腹心死士

[翼从索引](../retinues.md)

<a id="fuxin-sishi"></a>

## 腹心死士

- **标识与依据**：翼从 ID `qiao_heg__retinue_fuxin_sishi`，技能 ID `qiao__retinue_skill_fuxin_sishi`；源码 [retinue_skill_fuxin_sishi.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_fuxin_sishi.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从腹心死士与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为司马师（JIN002）与司马懿（JIN009）。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L1503)的统领条目。

> 与你势力相同的角色回合结束时，若其有未发动的限定技，你可以摸一张牌，交给其一张牌；若其本回合发动过限定技，你可以视为对其攻击范围内的一名角色使用【杀】。

- **实现与接口**：同势力角色回合结束时，由 [jin_resources.lua](../../../../../pkg/qiao_generals/util/jin_resources.lua) 的 `hasUnusedLimitedSkill`／`limitedUsedThisTurn` 按真实限定技标签与发动历史分别检查两项，可都执行。条件一：其仍有未发动限定技时，翼从持有者摸一张，然后交给其一张自己的牌；目标就是持有者时只摸不交。条件二：其本回合发动过限定技时，可视为使用一张【杀】，目标范围按当前回合角色（`target`）的攻击范围计算，不是翼从持有者；接入 `C.explicit` 的 `in_attack_range_of` 与 `room:useCard`。统领取得、限一与翼从来源由公共规则处理，本技能不重写。
- **验证依据**：[jin_resources.lua](../../../../../tests/jin_resources.lua) 覆盖未用限定技给牌、自己为目标只摸不交、已用限定技时用当前回合角色攻击范围使用【杀】；定向 15/15（3.686s），见[共享验证证据](../verification-evidence.md#jin-resources)。
- **未完成与边界**：暗置来源、多个限定技、目标死亡、无合法【杀】目标与客户端交互未人工验收。
