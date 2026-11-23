# 八阵兵

[翼从索引](../retinues.md) · [返回分包索引](../zhen.md)

<a id="bazhenbing"></a>

## 八阵兵

- **标识与依据** · 阵包翼从 `qiao_heg__retinue_bazhenbing`，运行时技能 ID `qiao__retinue_skill_bazhenbing`。见[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_bazhenbing.lua)和[统领与翼从规则](../../../../rules/commander-retinue.md)。

牌面原文见[石激桑资料的统领条目](../../../../../assets/docs/石激桑武将列表.json#L1976)。

> 轮次技，一名角色的出牌阶段开始时，你可以视为使用【调虎离山】，此牌结算中其可以将【杀】当【无懈可击】使用。

- **实现与接口** · 角色进入出牌阶段时，由持有者按当前翼从实例的轮次额度询问。使用虚拟【调虎离山】时仅在这次结算临时授予该角色将【杀】当【无懈可击】使用的权限，结算完成后收回。
- **验证依据** · [retinue_bazhenbing.lua](../../../../../tests/retinue_bazhenbing.lua#L40)。覆盖真实无懈请求、轮次和同名实例独立记账，以及结算后权限消失。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
