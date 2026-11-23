# 牛金

[翼从索引](../retinues.md)

<a id="niujin"></a>

## 牛金

- **标识与依据**：翼从 ID `qiao_heg__retinue_niujin`，技能 ID `qiao__retinue_skill_niujin`；源码 [retinue_skill_niujin.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_niujin.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从牛金与 [docs/rules/general-principles.md](../../../../rules/general-principles.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L5005)的统领条目。

> 与你势力相同的角色回合结束时，你可以使用每种类别至多各一张牌，你以此法杀死角色后摸三张牌。

- **实现与接口**：
  - `fk.TurnEnd` 全局触发，目标为同势力角色（含自己）；同势力角色回合结束时，可使用基本／锦囊／装备每类别至多各一张牌；以此法杀死角色后摸三张牌。
  - 发动时直接进入自由用牌请求。每次用牌后按实际用牌类别缩减下一次请求的候选和提示，取消或用完三类即结束。公共入口允许武圣、血海魔王樽等需要用牌时可用的技能，排除【闪】等被动牌并复核禁止和目标。合法用牌设置 `bypass_times` 和 `extraUse`。
  - 来源写入本次 `use.extra_data`；房间级奖励监听在 `fk.Death` 中向上追溯 `GameEvent.UseCard` 的 `extra_data`，仅在本次窗口用牌击杀时摸三张，不依赖持有者之后是否仍有技能。
- **验证依据**：[wei_retinues.lua](../../../../../tests/wei_retinues.lua) 覆盖真实用【杀】击杀不同势力角色，牛金奖励恰好一次 3 张，另加标准国战击杀奖励 1 张，总手牌 4；断言技能／同势力／实际用牌后再断言击杀奖励。此前 `expected 3 actual 25` 的根因与修复见[共享验证证据](../verification-evidence.md#牛金奖励根因)。
- **未完成与边界**：每类别用牌的真实客户端面板未人工验收；若后续改用牌流程，需复核 `extra_data` 来源追溯仍只奖励一次。
