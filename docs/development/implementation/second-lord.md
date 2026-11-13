# 第二君主：实现与验证

游戏语义见[对应规则](../../../rules/second-lord.md)；当前实装与待办见[开发状态](../status.md)。本页保留接口、接线和验收依据，不替代规则裁定，历史覆盖说明不代表已完成全部人工验收。

## 扩展内实现

实现位置：

| 内容 | 文件/接口 |
| --- | --- |
| 显式版本登记 | `pkg/hanjin_mode/rules/general_versions.lua`：`Versions.register { normal, lord, loyalty }`、`lord_version`、`lord_kingdoms`、`is_lord`、`selectable` |
| 升变通则 | `pkg/hanjin_mode/rules/ascension.lua`：`pair_max_hp`、`population_blocks`、`ascend`、`flip_lord_for_death`、`death_succession`、`convert_to_wild`、`get_winner` |
| 模式规则技能 | `pkg/hanjin_mode/skills/ascension_rule.lua`：`fk.TurnStart` 普通升变、`fk.BeforeGameOverJudge` 死亡继位、`fk.GameOverJudge` 胜负 |
| 模式接线 | `pkg/hanjin_mode/mode.lua`：`winner_getter = Ascension.get_winner`；其余选将池逻辑由 `Versions.plan` → `Pool.resolve` 使用 |

版本登记使用显式对应关系，不依赖同名替换或上游 `HegUtil.lordGenerals`。君主版程序名不得包含 `lord`，并且登记时设置 `general.is_lord`；这样可以避开上游 `new_hegemony_mode.lua` 死亡奖惩与 `hegemony_rule.lua` 明置处理中只按名字识别的君主特例，汉晋自己接管继位、转野和胜负。普通升变在角色首个回合的 `fk.TurnStart` 提供，先于上游同回合的亮将询问；死亡继位在 `fk.BeforeGameOverJudge` 执行，先于标准游戏结束判定，候选人按当前回合角色起逆时针询问并在提交时复核。涉及暗将时由服务端私下校验和询问，不向全场展示候选名单。

胜负判定一律根据场上是否只剩唯一势力决定游戏是否结束，与是否有君主及势力人数是否超过全场人数一半无关。超员野心家不会因君主存在被并回原势力；各野心家仍按国战规则分别视为独立势力。

## 自动化验收

`tests/second_lord.lua` 覆盖：

- 同势力两人先后尝试普通升变，首位成功后第二位不再获得该势力君主位置。
- 主将已明置或仍然暗置的死亡继位、从当前回合角色起的询问顺序、首人拒绝后次人接受。
- 加入后超员、已因超员成为野心家、受明置限制等不合资格情形。
- 无人继位时按君主死亡转野、已有野心家不回归、继位成功时本次死亡不转野。
- 升变后主将明置、势力同步、技能替换、暗置副将保持暗置。
- 体力上限增加时加 1 并回复 1 点；持平或减少时不调整。
- 珠联璧合与阴阳鱼只在“此次升变首次使两张武将牌均明置”时发放；已花费或升变前已双亮不重领。
- 君主在场不豁免超员；有君主的势力仍会因超员转为野心家。
- 有君主与无君主采用相同的唯一势力胜负判定；覆盖势力人数超过全场人数一半的情况，以及常规势力与野心家并存、多个野心家并存和仅剩一个野心家的情况。
