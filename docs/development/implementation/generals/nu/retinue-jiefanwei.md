# 解烦卫

[翼从索引](../retinues.md) · [弩包](../nu.md)

<a id="jiefanwei"></a>

## 解烦卫的翼从效果

> 限定技，出牌阶段，你可以弃置两张牌并令一名角色回复1点体力。若为你，则你复原自己一个“出牌阶段限一次”的技能，否则你复原其一个限定技。

多份限定技分别记录消耗；给自己回血后复原出牌阶段限一次的技能，给别人回血时复原对方的限定技。 [qiao__retinue_skill_jiefanwei](../../../../../pkg/qiao_bingqing/skills/retinue_jiefanwei.lua)

出牌阶段限一次的翼从效果按实例复原。持有两份已用的【青州精锐】时，一次复原使其中一份可再次发动，并同步客户端的公开计数。

[统领登记](../../../../../pkg/qiao_bingqing/data/nu.lua) · [原生回归](../../../../../tests/nu_generals.lua#L567)
