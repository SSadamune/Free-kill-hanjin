# 庐江上甲

[翼从索引](../retinues.md) · [返回分包索引](../shi.md)

<a id="lujiang-shangjia"></a>

## 庐江上甲

- **标识与依据** · 势包翼从 `qiao_heg__retinue_lujiang_shangjia`，运行时技能 ID `qiao__retinue_skill_lujiang_shangjia`。见[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_lujiang_shangjia.lua)和[统领与翼从规则](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L6513)的统领条目。

> 出牌阶段限X次（X为拥有庐江上甲的角色数），你可以调整手牌至你装备区的牌数，若为弃牌，你此阶段使用【杀】的次数+1。

- **实现与接口** · 出牌阶段按在场拥有该兵种的角色人数决定本实例的次数。将自身手牌数调整到装备区张数。本次实际弃牌时建立当前阶段的【杀】次数加成，兵种来源移除后仍保留已建立的加成。
- **验证依据** · [zhen_shi_retinues.lua](../../../../../tests/zhen_shi_retinues.lua#L188)。验证按角色数而非实例数，排除死亡角色，实测弃牌增次与失去实例后继续生效。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
