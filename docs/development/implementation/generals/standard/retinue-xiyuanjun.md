# 西园军

[翼从索引](../retinues.md)

<a id="xiyuanjun"></a>

## 西园军

- **标识与依据**：翼从 ID `qiao_heg__retinue_xiyuanjun`，技能 ID `qiao__retinue_skill_xiyuanjun`；源码 [retinue_skill_xiyuanjun.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_xiyuanjun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从西园军、[阶段事件](../../../../../rulebook/events/phase.md)、[展示](../../../../../rulebook/terms/card-op-terms/showCards.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L836)的统领条目。

> 与你势力相同的角色出牌阶段开始时，你可以选择一名角色的一张手牌，本回合此牌对所有角色可见且其不能使用或打出之，其受到伤害后来源获得之。

- **实现与接口**：
  - `fk.EventPhaseStart` 以普通 `global + can_trigger + on_cost + on_use` 处理：触发条件是与西园军同势力的角色出牌阶段开始；当前阶段角色可以没有手牌。
  - 被选牌角色是“一名角色”，候选为全场有手牌的合法角色，不限制与西园军同势力（可选敌方，也可选当前空手的阶段角色以外的角色）。先选角色，再用 `askToChooseCard(flag="h")` 由引擎隐藏选牌；返回值用 `Card:getIdList` 规范化为单个 id，兼容 Card/ID/数组。
  - 每个西园军 owner 各自独立处理同一事件，不使用单一 `__done` 互相阻止。
  - 选中牌打两个标记：`qiao_retinue_xiyuanjun_visible-turn`（`visibility.card_visible` 对全部角色公开，回合末清理）与 `qiao_retinue_xiyuanjun_lock-turn-inhand`（`prohibit_use`／`prohibit_response` 禁止持有者使用或打出；名字同时含 `-turn` 与 `-inhand`，牌离开手牌立即清理，回合末也清理，避免后续持有者继承错误禁用）。禁止判断会展开虚拟／转化牌的实体子牌，不只看虚拟牌自身 mark。
  - 通过[公共可见性接口](../../skill-ui.md#交牌和获得牌的可见性)读取牌上的公开标记。两张手牌同批交给另一人时，测试逐席验证旁人只看见被【西园军】标记的那张牌。
  - `fk.Damaged` 监听带标记牌的角色：有伤害来源时由来源经 `obtainCard` 获得该牌并清标记；无来源不获得。弃置、给予等其他操作不受用牌／打出限制影响。
- **验证依据**：[han_retinues.lua](../../../../../tests/han_retinues.lua) 覆盖当前阶段角色空手、所选敌方角色有手牌也可选；选中手牌对其他角色可见、持有者不能使用（含该子牌的虚拟牌也不能使用）；受伤后伤害来源获得该牌、标记清理。历史记录见[共享验证证据](../verification-evidence.md#han_retinues)。
- **未完成与边界**：“公开”使用现有 `VisibilitySkill` 公共接口，无客户端补丁；若客户端未按该接口刷新手牌可见性，需基础组回报最小公共接线，而不是伪造可见数据。伤害来源为空的场合已跳过；多张同时带标记的异常输入只取一张，正常流程一次只建立一张。翼从取得／失去技能由统领公共流程覆盖。
