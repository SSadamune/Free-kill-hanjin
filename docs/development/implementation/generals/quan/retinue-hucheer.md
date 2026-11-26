# 胡车儿

[翼从索引](../retinues.md) · [返回分包索引](../quan.md)

<a id="hucheer"></a>

## 胡车儿

- **标识与依据** · 权包偏将（限一） `qiao_heg__retinue_hucheer`（统领来源：张绣 QUN023，统领牌【顺手牵羊】），运行时技能 ID `qiao__retinue_skill_hucheer`。见[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_hucheer.lua)和[张绣逐将规则](../../../../rules/generals/qun023-zhangxiu.md#关联偏将胡车儿限一)。

> 轮次技，与你相互处于彼此攻击范围的角色出牌阶段开始时，你可以获得其装备区的一张牌且可以使用之，若你因此离开其攻击范围，你摸一张牌。

- **实现与接口** · 登记为限一偏将（`limited = true`，来源统领能力亦 `limited = true`），接入 `R.triggerEach` 与 `Player.HistoryRound` 轮次限次。筛选目标装备区可移动装备时过滤明置【聚宝】保护的宝物牌；获得装备牌后通过 `room:askToUseRealCard` 按该牌实体 ID 询问是否立即使用（兼容回合外装备牌使用），全部完成后统一复查 `not target:inMyAttackRange(player)`，满足即摸一张牌。
- **验证依据** · [quan_han_wei_shu.lua](../../../../../tests/quan_han_wei_shu.lua)、[quan_wu_qun_jin.lua](../../../../../tests/quan_wu_qun_jin.lua)。覆盖偏将限一登记、获得并立即装备防御坐骑离开对方攻击范围摸牌，以及仅剩明置【聚宝】宝物牌时不触发。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
