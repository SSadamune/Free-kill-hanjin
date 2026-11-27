# QUN022A 李傕

[返回分包索引](../bian.md)

<a id="qun022a-1"></a>

## 凶算

- **标识与依据** · 李傕（QUN022A，变包），运行时 ID `qiao__skill_qun022a_1`。见[源码](../../../../../pkg/qiao_generals/skills/skill_qun022a_1.lua)、[变包模式规则](../../../../../pkg/qiao_mode/skills/bian_rules.lua)和[逐将规则](../../../../rules/generals/qun022a-lijue.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json)。

> 限定技，出牌阶段，你可以弃置一张手牌并对一名与你势力相同的角色造成1点伤害，然后摸三张牌，回合结束时复原其一个限定技。

- **实现与接口** · 出牌阶段限定主动技，沿用 FreeKill 0.5.25 原生限定技动画（淡入、停留、淡出合计 2 秒）。允许选择包括李傕自己在内的同势力在场角色。弃置 1 张合法手牌后对其造成 1 点伤害并摸 3 张牌，在房间标签登记回合末复原任务。模式级规则 `qiao__bian_rules` 在 `fk.TurnEnd` 通过引擎的角色技能全集与公共武将技能分类筛选明置且已发动过的限定技，包括角色独立获授的限定技。【激诏】【鼎沸】读取 `qiao_limited_used_marks` 登记的已用标记。【飞熊军】只列入仍有技能且已用过的实例，每次复原一份。李傕对自己发动时可复原【凶算】本身。复原时按来源更新引擎次数、武将牌记录或翼从实例，并刷新限定技界面。另登记有且仅有汉势力客将（2026-11-25 用户确认）及对应客将插画 `qiao_heg__qun022a.jpg`。
- **验证依据** · [bian_wu_qun_jin.lua](../../../../../tests/bian_wu_qun_jin.lua#L302)、[bian_wu_qun_jin.lua](../../../../../tests/bian_wu_qun_jin.lua#L375) 与 `testQun022aNaoxiCancelledTargetAndXiongsuanCustomLimitedReset`。覆盖对自己发动并在回合末复原【凶算】自身循环、复原已用尽的【飞熊军】实例，以及复原【激诏】【鼎沸】并实测二次发动。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。

<a id="qun022a-2"></a>

## 挠袭

- **标识与依据** · 李傕（QUN022A，变包），运行时 ID `qiao__skill_qun022a_2`。见[源码](../../../../../pkg/qiao_generals/skills/skill_qun022a_2.lua)和[逐将规则](../../../../rules/generals/qun022a-lijue.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json)。

> 每回合限一次，当你使用普通锦囊牌后，你可以减1点体力上限并视为再使用一张同牌名的牌（不能包含相同的目标）。

- **实现与接口** · 模式级规则 `qiao__bian_rules` 在 `fk.AfterCardTargetDeclared` 与 `fk.TargetSpecifying` 持续记录每张牌曾指定过的全部目标（`extra_data.qiao_ever_targets`，包含后续被【谦逊】等取消的目标）。【挠袭】在 `fk.CardUseFinished` 校验普通锦囊牌及本回合未发动过，合并当前与曾指定目标后预检：固定目标牌按完整固定目标集合判定，只要包含任一曾指定目标即整张禁止使用（不拆分剔除）；手选目标牌校验存在完全不重叠的合法组合，发动时先减 1 点体力上限，再通过 `room:askToUseVirtualCard` 传入 `exclusive_targets` 强制限制新目标与全部原目标不重叠。
- **验证依据** · [bian_wu_qun_jin.lua](../../../../../tests/bian_wu_qun_jin.lua#L302)、`testQun022aNaoxiCancelledTargetAndXiongsuanCustomLimitedReset` 与 `testQun022aNaoxiCannotSplitFixedTargetsButAllowsDisjoint`。验证【洞烛先机】无新目标禁发、陆逊【谦逊】取消原目标后仍被排除、【火烧连营】队列扩大重叠时不得拆分而完全不重叠时仍可复用。
- **未完成与边界** · 关联统领来源为 `{飞熊军 | 火攻}`，翼从实现见[飞熊军](retinue-feixiongjun.md#feixiongjun)。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
