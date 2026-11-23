# 黄巾雷使

[翼从索引](../retinues.md)

<a id="huangjin-leishi"></a>

## 黄巾雷使

- **标识与依据**：翼从 ID `qiao_heg__retinue_huangjin_leishi`，技能 ID `qiao__retinue_skill_huangjin_leishi`；源码 [retinue_skill_huangjin_leishi.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_huangjin_leishi.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从黄巾雷使与[统领与翼从](../../../../rules/commander-retinue.md)。来源武将为张角（QUN010）。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L363)的统领条目。

> 每回合首次有角色不因使用手牌而造成伤害时，你可以弃置一张手牌并判定，若为：黑色，此伤害+1；红色，其获得此判定牌。

- **实现与接口**：模式级常驻记录器 [qun_damage_history](../../../../../pkg/qiao_mode/skills/qun_damage_history.lua) 在开局安装，记录本回合第一个“不因使用手牌而造成伤害”的 `fk.DamageCaused` 时机；黄巾雷使只在该时机开放一次选择，未发动／无手牌／放弃都消耗本回合机会。记录器按真实 `DamageData` 的 `chain/parent` 与 `UseCardData:isUsingHandcard` 判断直接渠道，翼从本体不重复判断。
- **验证依据**：已执行 [qun_judgement.lua](../../../../../tests/qun_judgement.lua) 的 `testHuangjinBlackIncreasesFirstNonHandcardDamage`、`testHuangjinRedGivesJudgeCardToSource`、`testHuangjinLateAcquisitionDoesNotReopenFirstChance`、`testHuangjinIgnoresHandcardSlashDamage`。历史批次见[验证记录](../verification-evidence.md#qun-standard)。
- **未完成与边界**：转化牌、无实体牌、铁索传导组合未穷举；客户端判定与增伤提示未人工验收。
