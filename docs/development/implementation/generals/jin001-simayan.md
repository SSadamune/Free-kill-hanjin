# 晋势力标准包：逐将检索与验证入口

本页是晋势力标准包的逐将检索与验证入口，只保留编号、运行时 ID、源码、逐技能锚点与真实验证记录；技能正文已拆入机制页，本页不重复。当前只收已实装部分（JIN001 垂统、兴图及 JIN009 同文应期），不代表晋势力其余技能完成。游戏语义见[司马炎规范](../../../../rules/generals/jin001-simayan.md)及[装备移动通则](../../../../rules/equipment-movement.md)，本页不替代规则裁定。当前完成度与全局待办由[开发状态](../../status.md)维护。

## 1. 逐将表

| 编号 | 武将 | 技能 | 运行时 ID | 源码 | 实现详情 | 验证 |
| --- | --- | --- | --- | --- | --- | --- |
| JIN001 | 司马炎 | 垂统、兴图 | `hanjin__jin001` | [skill_jin001_1.lua](../../../../pkg/hanjin_generals/skills/skill_jin001_1.lua)、[skill_jin001_2.lua](../../../../pkg/hanjin_generals/skills/skill_jin001_2.lua) | [垂统](support.md#jin001-1)、[兴图](conversion.md#jin001-2) | [jin001_simayan](../../../../tests/jin001_simayan.lua) |
| JIN009 | 司马懿 | 应期（同文，已实装） | `hanjin__jin009` | [skill_jin009_3.lua](../../../../pkg/hanjin_generals/skills/skill_jin009_3.lua) | [应期](pair-hp.md#wei002-3)（与 WEI002 共享正文，不另设） | [wei_pair_hp](../../../../tests/wei_pair_hp.lua) |

JIN009 仅列已实装的同文应期引用；其权变、骤霆等其余技能未在本批实装，不计入晋完成度。

## 2. 关联翼从

晋关联翼从目前无实装记录，本页不列未开发条目；统领能力与翼从效果见[统领与翼从](../commander-retinue.md)与[规则](../../../../rules/commander-retinue.md)。

## 3. 接线

两技能已在 [init.lua](../../../../pkg/hanjin_generals/init.lua) 的正式实装例外白名单登记；[standard_generals.lua](../../../../tests/standard_generals.lua) 的同一白名单和事实断言同步更新。默认国战套件由 [all.lua](../../../../tests/all.lua) 接入 [jin001_simayan.lua](../../../../tests/jin001_simayan.lua)。技能入口：垂统 `fk.EnterDying`；兴图 `fk.TurnEnd`、全局 `fk.PreTurnStart`／`fk.AfterCardUseDeclared`、辅助主动技 `#hanjin__skill_jin001_2_active`。

## 4. 验证

常规专项验收入口：

```text
python scripts/test.py --file tests/jin001_simayan.lua --timeout 120
```

最近一次由 DSH 直接通过同一 runtime 的 `FreeKill.exe --testfile` 执行专项（当时用户正在运行游戏，未重复同步运行环境），原记录为 `Ran 17 tests ... 17 successes, 0 failures`（原文省略运行时间）。覆盖垂统的濒死移装与各类不移动边界、兴图的应变牌事实／回合清空／两项执行／主副将与暗置来源，以及真实 `ClientPlayer` 请求处理器中装备牌／非装备牌与目标的可选性。默认全量套件通过 507/507（该批次）；安装包已构建。原始执行记录见[共享验证证据](verification-evidence.md#jin001_simayan)。

## 5. 未完成与边界

未应用开发适配的本体人工交互验收尚未执行。全局记录以使用牌事件为准，未覆盖“无任何目标但被使用”的边缘牌型，后续如出现具体用例再补。用户曾报告“应变牌后的下一回合，敌方普通杀→八卦阵视为闪，兴图误触发”，自动化未能复现；真实连续回合回归及虚拟闪无应变条目检查通过，2026-11-13 用户复测确认已无异常，该反馈关闭，不据此追认具体根因，也未保留无复现依据的回合序号补丁。用户同时确认当轮界面调整无异常；该复测不代表完整联网、重连或未应用开发适配的独立本体验收。

### 规范化描述待办

<a id="jin001-todo"></a>

- [ ] 编写垂统、兴图各自的规范化描述，使用规则集定义的术语与结构，精确表达时机、条件、消耗和效果，并核对项目已确认裁定与实际代码。
- [ ] 将审定后的规范化描述纳入《汉晋规则集》对应武将资料；保留面向玩家的卡面描述。本页的实现说明及 `rules/generals/jin001-simayan.md` 的结算约定均不替代规范化描述，未决裁定须明确标注。
