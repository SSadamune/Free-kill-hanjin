# 并州狼骑

[翼从索引](../retinues.md)

<a id="bingzhou-langqi"></a>

## 并州狼骑

- **标识与依据**：翼从 ID `qiao_heg__retinue_bingzhou_langqi`，技能 ID `qiao__retinue_skill_bingzhou_langqi`；源码 [retinue_skill_bingzhou_langqi.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_bingzhou_langqi.lua)，距离状态技 [retinue_skill_bingzhou_distance.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_bingzhou_distance.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从并州狼骑与[统领与翼从](../../../../rules/commander-retinue.md)。**多来源**：并州狼骑可由张辽、吕布等不同统领取得。

牌面原文见[石激桑资料的统领条目](../../../../../assets/docs/石激桑武将列表.json#L2559)。

> 出牌阶段限一次，你可以令一名其他角色视为对你使用一张【决斗】，本回合你与其距离视为1。

- **实现与接口**：
  - 出牌阶段限一次，令一名其他角色视为对你使用【决斗】，本回合你与其距离视为 1。主动技不依赖骨架次数限制：active `can_use` 用 `usedSkillTimes(..., Player.HistoryPhase)` 限制每阶段一次，`on_use` 不再次拒绝已记录的本次发动（引擎在进入 `on_use` 前已记次，二次检查会吞掉本次发动）。
  - 距离关系改为双方 `@[qiao_bingzhou_pairs]` 表标记，支持多来源／多持有者；距离状态技为随包加载的独立骨架（服务端／客户端同一对象），回合末由房间级清理监听移除状态技并清标记。关系不因失去翼从技能消失。
- **验证依据**：[wei_retinues.lua](../../../../../tests/wei_retinues.lua) 覆盖真实【决斗】使用者／目标、双向距离、每阶段一次，见[共享验证证据](../verification-evidence.md#wei_retinues)。
- **未完成与边界**：距离状态技双方挂载／回合末移除、以及客户端距离显示需要实际运行与客户端验证；真实客户端【决斗】与距离提示未人工验收。
