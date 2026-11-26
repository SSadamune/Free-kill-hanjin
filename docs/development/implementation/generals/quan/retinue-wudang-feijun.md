# 无当飞军

[翼从索引](../retinues.md) · [返回分包索引](../quan.md)

<a id="wudang-feijun"></a>

## 无当飞军

- **标识与依据** · 权包普通翼从 `qiao_heg__retinue_wudang_feijun`（统领来源：王平 SHU023，统领牌【杀】），运行时技能 ID `qiao__retinue_skill_wudang_feijun`。见[源码](../../../../../pkg/qiao_generals/skills/retinue_skill_wudang_feijun.lua)、[权包模式规则](../../../../../pkg/qiao_mode/skills/quan_rules.lua)和[王平逐将规则](../../../../rules/generals/shu023-wangping.md#关联翼从无当飞军)。

> 当你使用【杀】造成伤害时，你可以防止受伤角色本回合下一次回复体力，当前回合结束时，若其未触发此效果，其弃置每区域各一张牌。

- **实现与接口** · 接入多实例框架 `R.triggerEach` 并在技能栏使用简称「无当军」。使用【杀】造成伤害时为受伤角色叠加本回合延时标记 `qiao_wudang_feijun_pending-turn`（同步展示在状态面板），由房间级 `qiao__quan_rules` 监听 `fk.PreHpRecover` 防止一次回复并消去一层；回合结束时若仍有剩余层数，每层调用 `Quan.discardOnePerArea` 令其手牌、装备、判定三区各弃一张。
- **验证依据** · [quan_han_wei_shu.lua](../../../../../tests/quan_han_wei_shu.lua)。覆盖注册与简称、防止回血消费标记分支及未触发回血时回合末三区各弃一分支。
- **未完成与边界** · 本条只记录上述覆盖。共通的人工验收范围见[开发状态](../../../status.md#当前验收基线)。
