# 魏势力标准包：受伤／伤害类 8 技能实现与验证

本页记录 WEI001 奸雄、WEI002 狼顾、WEI003 刚烈、WEI005 裸衣、WEI006 遗计、WEI013 节命、WEI014 行殇、WEI016 骁果的最小可运行实现、引擎接线与定向验证，不替代规则裁定。技能原文见[标准武将表](../../../../rules/standard-generals.md)魏区；已确认差异见[rules/generals/](../../../../rules/generals/)（本轮适用 [WEI016 乐进·骁果](../../../../rules/generals/wei016-yuejin.md)）。源码接口按锁定运行时 0.5.25 与 hegemony `e8d93acd34a3` 核对，`rules/`、`rulebook/`、外部资料与公共文件未改。

## 1. 本轮范围

| 技能 | 运行时 id | 源码 | 时机与要点 |
| --- | --- | --- | --- |
| 奸雄 | `hanjin__skill_wei001_1` | [skill_wei001_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei001_1.lua) | `fk.Damaged`；先摸一张，再可足额弃一张牌（手牌/装备，不含判定区）取得仍在处理区的伤害牌 |
| 狼顾 | `hanjin__skill_wei002_1` | [skill_wei002_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei002_1.lua) | `fk.Damaged`；获得来源一张手牌/装备牌；来源为自己时只取装备区，与既有反馈类公共处理一致 |
| 刚烈 | `hanjin__skill_wei003_1` | [skill_wei003_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei003_1.lua) | `fk.Damaged`；判定红色对来源造成1点普通伤害，黑色弃置来源一张牌；来源离场后不再执行对应分支 |
| 裸衣 | `hanjin__skill_wei005_1` | [skill_wei005_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei005_1.lua) | `fk.EventPhaseEnd`（摸牌阶段）弃一张牌；`fk.DamageCaused` 延时效果按回合标记给【杀】/【决斗】伤害+1 |
| 遗计 | `hanjin__skill_wei006_2` | [skill_wei006_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei006_2.lua) | `fk.Damaged` 每次伤害事件一次；看牌堆顶两张，先选1~2张给一名角色，剩余再给一名角色，不做上游式任意循环分配 |
| 节命 | `hanjin__skill_wei013_2` | [skill_wei013_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei013_2.lua) | `fk.Damaged` + `trigger_times = data.damage`；每个伤害点分别询问目标并摸至 `min(体力上限,5)` 张手牌 |
| 行殇 | `hanjin__skill_wei014_1` | [skill_wei014_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei014_1.lua) | `fk.Death`（弃置其牌之前）；获得死亡角色的手牌与装备牌（“某人的牌”不含判定区）；其没有牌时回复1点体力 |
| 骁果 | `hanjin__skill_wei016_1` | [skill_wei016_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei016_1.lua) | `fk.EventPhaseStart`（其他角色准备阶段）；弃置至少一张基本牌为消耗，目标弃置等量装备（不足全弃），实际基本数>装备数则造成1点伤害，否则摸一张 |

## 2. 接线与公共机制

- 8 个技能骨架均在源码内显式 `hanjinImplemented = true`；[init.lua](../../../../pkg/hanjin_generals/init.lua) 的既有无 effect 断言据此放行，无需改 `init.lua`、`data/standard.lua` 或公共测试文件。
- 主副将、明暗置、势力来源：技能均以 `player:hasSkill(技能名)` 判定当前是否持有；效果通过玩家自身技能、牌与事件结算，不依赖服务端私有字段。技能的来源武将、称号与描述继续由 `data/standard.lua` 统一注册。
- 客户端可见性：选牌/选目标使用 `askToDiscard`、`askToChooseCard`、`askToChoosePlayers`、`askToChooseCardsAndPlayers` 等正式请求接口；遗计以 `expand_pile` 展示牌堆顶两张。裸衣的回合标记只服务端判定，不使用 `@@` 展示标记。
- 裸衣效果独立于技能存在：延时效果通过回合标记与 `fk.DamageCaused` 结算，不检查 `hasSkill`；标记命名为 `hanjin_wei005_luoyi-turn`，不以技能名前缀开头，避免武将交换把它当成来源技能标记迁走，回合结束由 `-turn` 后缀清理。
- 节命保留引擎逐次调度：没有拆分伤害事件，也没有在 `on_use` 内循环；`trigger_times` 直接取 `data.damage`。
- 骁果遵循已确认消耗规则：弃置基本牌须至少一张，`skip = true` 后在 `on_use` 统一移动；目标装备不足时全弃、无装备不弃；伤害比较用实际弃置张数。

## 3. 定向验证

测试文件：[tests/wei_damage.lua](../../../../tests/wei_damage.lua)（本轮未改 [all.lua](../../../../tests/all.lua)，由 Codex 统一并入默认国战套件）。

```text
python scripts/test.py --file tests/wei_damage.lua --timeout 180
Ran 8 tests in 1.923 seconds, 8 successes, 0 failures
```

覆盖：奸雄摸牌+弃牌取得伤害牌；狼顾取得来源牌；刚烈红/黑两分支；裸衣失去技能后本回合加伤仍生效；遗计一次2点伤害只发动一次且分两次给牌；节命2点伤害逐点发动两次；行殇取得死亡角色手牌与装备牌及无牌回复；骁果基本数多于装备数造成伤害、相等时摸牌。

行殇用例直接触发 `fk.Death`（真实死亡事件类与真实请求/回复），未经过完整的 `killPlayer` 死亡结算链；完整死亡、奖惩与客户端界面仍是未验证边界。

## 4. 未完成项与边界

- 最终默认全量已由 DSH 工具原生检查确认 608/608 通过，包含本组 8 项；逐项客户端人工交互仍待验收。
- 本组已接入 [all.lua](../../../../tests/all.lua) 默认国战套件。
- 未做真实客户端 QML 交互（选牌、选目标、确认/取消）与明暗置、主副将来源切换的人工验收。
- 遗计使用 `getNCards(2)` 读取牌堆顶两张（该接口只读取、不移入处理区），选择对话框以 `expand_pile` 展示这两张，再按两次分配从牌堆移动到目标手牌；未新增仅客户端可见的私有展示层。
- 行殇在 `fk.Death` 取得死亡角色的手牌与装备牌；判定区牌不移动，只有判定区牌的死亡角色按“没有牌”回复体力。未展开与白银狮子等死亡时失去装备触发之间的完整时序回归。
