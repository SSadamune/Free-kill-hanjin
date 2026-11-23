# 虎卫军

[翼从索引](../retinues.md)

<a id="huweijun"></a>

## 虎卫军

- **标识与依据**：翼从 ID `qiao_heg__retinue_huweijun`，技能 ID `qiao__retinue_skill_huweijun`；源码 [retinue_skill_huweijun.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_huweijun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从虎卫军与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为典韦／许褚。

牌面原文见[石激桑资料的统领条目](../../../../../assets/docs/石激桑武将列表.json#L4891)。

> 每回合结束时，若你本回合共计造成和受到过的伤害数大于1，你可以移动场上一张牌。

- **实现与接口**：
  - `fk.TurnEnd` 为全局触发，不限于自己回合；每回合结束时，若持有者本回合共计造成和受到过的伤害数大于 1，可以移动场上一张牌。
  - 用 `logic:getActualDamageEvents` 读取实际伤害（排除被防止），`data.from == player` 与 `data.to == player` 分别累加，自己对自己的伤害计两份。满足后复用阶段组 `wei_phases.moveCardInBoard`。
  - 魏、吴调用者共用选人和移牌逻辑。选人请求只开放可移出或接收的候选，选牌请求按角色列出可移动的装备与判定牌并允许取消。确认后重新校验牌区和目标。
- **验证依据**：[wei_retinues.lua](../../../../../tests/wei_retinues.lua) 覆盖真实回合内伤害、客户端选人、合法牌组、实际移动、取消及无合法组合时关闭询问。
- **未完成与边界**：真实客户端移牌面板未人工验收；测试在真实 `GameEvent.Turn` 内制造伤害，避免伪造回合历史。
