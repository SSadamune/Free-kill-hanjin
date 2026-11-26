# WEI021B 毛玠

[返回分包索引](../quan.md)

<a id="wei021b-1"></a>

## 征辟

- **标识与依据** · 毛玠（WEI021B，权包），运行时 ID `qiao__skill_wei021b_1`（配合辅助选牌技能 `#qiao__skill_wei021b_1_return`）。见[源码](../../../../../pkg/qiao_generals/skills/skill_wei021b_1.lua)、[交还辅助](../../../../../pkg/qiao_generals/skills/wei021b_1_return.lua)和[逐将规则](../../../../rules/generals/wei021b-maojie.md)。

> 出牌阶段限一次，你可以将一张牌交给一名角色，其展示并交给你一张非基本牌或两张基本牌，若其有暗置武将牌，本回合此技能限两次。

- **实现与接口** · 出牌阶段主动技，目标为任意在场其他角色，基础限一次；指定目标时若其有暗置武将牌，在交出第一张牌前，写入公开标记 `qiao_wei021b_zhengpi_twice-turn` 将本回合发动上限动态放宽至两次（两端共用公开标记并在状态面板展示）。目标通过单窗口辅助技 `#qiao__skill_wei021b_1_return` 选择 1 张非基本牌（允许装备区装备牌）或 2 张基本牌展示并交还；无合法组合时直接跳过。
- **验证依据** · [quan_han_wei_shu.lua](../../../../../tests/quan_han_wei_shu.lua)。覆盖装备区非基本牌交还、暗置目标在收牌时明置仍解锁本回合第二次、真实客户端可用性校验与无合法组合跳过。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。

<a id="wei021b-2"></a>

## 奉迎

- **标识与依据** · 毛玠（WEI021B，权包），运行时 ID `qiao__skill_wei021b_2`。见[源码](../../../../../pkg/qiao_generals/skills/skill_wei021b_2.lua)、[挟天子以令诸侯](../../../../../pkg/qiao_cards/skills/threaten_emperor.lua)和[逐将规则](../../../../rules/generals/wei021b-maojie.md)。

> 限定技，你可以将所有手牌当【挟天子以令诸侯】使用（无视大势力限制），使用时所有与你势力相同的角色摸牌至其体力上限。

- **实现与接口** · 限定转化技，将全部手牌转化为带 `qiao_ignore_big_kingdom` 标记的 `qiao__threaten_emperor`，由【挟天子以令诸侯】卡技 `can_use` 放行大势力限制（仍遵循额定回合等基础限制）。在 `fk.CardUsing`（先于【无懈可击】响应窗口）按座次令所有同势力在场角色摸牌至体力上限。
- **验证依据** · [quan_han_wei_shu.lua](../../../../../tests/quan_han_wei_shu.lua)。覆盖非大势力客户端可用性、使用时同势力全员摸至体力上限（含被无懈可击抵消场景）及整局限一次。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
