# 文虎

[翼从索引](../retinues.md)

<a id="wenhu"></a>

## 文虎

- **标识与依据**：翼从 ID `qiao_heg__retinue_wenhu`，技能 ID `qiao__retinue_skill_wenhu`；源码 [retinue_skill_wenhu.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_wenhu.lua)。规则见[文鸯规范](../../../../rules/generals/jin014-wenyang.md)与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为文鸯（JIN014），限一；同一武将的冰杀统领能力另见公共统领记录。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L1790)的统领条目。

> 出牌阶段限一次，你可以弃置任意个区域的所有牌，然后视为使用目标上限为X的【决斗】（X为你以此法弃置牌的区域数）。

- **实现与接口**：出牌阶段限一次，`askToChoices` 让玩家勾选手牌/装备/判定三区中任意个非空且全部可弃置的区域；选定后先固定所有选中区的原始牌，再用**一次** `throwCard` 同时弃置，避免逐区重新读取把弃牌触发技新增的牌一并收走。X 按选择时固定牌的完整选中区计算，不按牌数或装备栏数。随后以 `card_use_targets` 的 `C.askToUseVirtualCard` 使用正式 `qiao__duel`，`C.default` 只把 `max_targets` 改为 X，保留原牌其他目标条件，不放宽距离。
- **验证依据**：[jin_chain.lua](../../../../../tests/jin_chain.lua) 覆盖完整弃置手牌区+装备区（X=2）、判定区保留、决斗有 2 名目标；定向 6/6，见[共享验证证据](../verification-evidence.md#jin-chain)。
- **未完成与边界**：仅弃判定区、区域含禁弃牌、空区/部分弃置、目标上限大于可指定人数、客户端多选与联网未人工验收。
