# 魏势力标准包：15 将 25 技能及 3 翼从实现与验证

本页是[标准武将表](../../../../rules/standard-generals.md)魏区的实现总入口，汇总 15 张正式武将、25 个技能与并州狼骑、虎卫军、牛金 3 张魏关联翼从的源码、专项测试和**真实验证状态**，不替代规则条文。逐将裁定以 `rules/generals/` 的已确认文件为准；牌面数据来源为 `docs/石激桑武将列表.json`，外部资料只读。

## 1. 分组与逐将入口

| 编号 | 武将 | 技能 | 实现/验证文档 | 专项测试 |
| --- | --- | --- | --- | --- |
| WEI001 | 曹操 | 奸雄 | [受伤/伤害组](wei-damage.md) | `tests/wei_damage.lua` |
| WEI002 | 司马懿 | 狼顾、鹰视、应期 | 狼顾见[受伤/伤害组](wei-damage.md)；鹰视见[改判组](wei-retrial.md)；应期见[配将体力组](wei-pair-hp.md) | `tests/wei_damage.lua`、`tests/wei_retrial.lua`、`tests/wei_pair_hp.lua` |
| WEI003 | 夏侯惇 | 刚烈、持重 | 刚烈见[受伤/伤害组](wei-damage.md)；持重见[持重组](wei-support.md) | `tests/wei_damage.lua`、`tests/wei_support.lua` |
| WEI004 | 张辽 | 突袭 | [持重组](wei-support.md) | `tests/wei_support.lua` |
| WEI005 | 许褚 | 裸衣 | [受伤/伤害组](wei-damage.md) | `tests/wei_damage.lua` |
| WEI006 | 郭嘉 | 轻辎、遗计 | 轻辎见[阶段/转换组](wei-phases.md)；遗计见[受伤/伤害组](wei-damage.md) | `tests/wei_phases.lua`、`tests/wei_damage.lua` |
| WEI007 | 甄姬 | 倾国、洛神 | [阶段/转换组](wei-phases.md) | `tests/wei_phases.lua` |
| WEI008 | 夏侯渊 | 神速、设变 | [阶段/转换组](wei-phases.md) | `tests/wei_phases.lua` |
| WEI009 | 张郃 | 巧变 | [阶段/转换组](wei-phases.md) | `tests/wei_phases.lua` |
| WEI010 | 徐晃 | 断粮、长驱 | 断粮见[阶段/转换组](wei-phases.md)；长驱见[主动/距离组](wei-active.md) | `tests/wei_phases.lua`、`tests/wei_active.lua` |
| WEI011 | 曹仁 | 伪溃、励战 | 伪溃见[主动/距离组](wei-active.md)；励战见[阶段/转换组](wei-phases.md) | `tests/wei_active.lua`、`tests/wei_phases.lua` |
| WEI012 | 典韦 | 强袭 | [主动/距离组](wei-active.md) | `tests/wei_active.lua` |
| WEI013 | 荀彧 | 驱虎、节命 | 驱虎见[主动/距离组](wei-active.md)；节命见[受伤/伤害组](wei-damage.md) | `tests/wei_active.lua`、`tests/wei_damage.lua` |
| WEI014 | 曹丕 | 行殇、放逐 | 行殇见[受伤/伤害组](wei-damage.md)；放逐见[持重组](wei-support.md) | `tests/wei_damage.lua`、`tests/wei_support.lua` |
| WEI016 | 乐进 | 骁果 | [受伤/伤害组](wei-damage.md) | `tests/wei_damage.lua` |

## 2. 魏关联翼从

| 翼从 | 技能要点 | 实现/验证文档 | 专项测试 |
| --- | --- | --- | --- |
| 并州狼骑 | 出牌阶段限一次，令一名其他角色视为对你使用【决斗】，本回合距离视为1 | [翼从组](wei-retinues.md) | `tests/wei_retinues.lua` |
| 虎卫军 | 每回合结束时，若本回合造成和受到的伤害数合计大于1，可移动场上一张牌 | [翼从组](wei-retinues.md) | `tests/wei_retinues.lua` |
| 牛金 | 同势力角色回合结束时，可使用每种类别至多各一张牌；以此法杀死角色后摸三张牌 | [翼从组](wei-retinues.md) | `tests/wei_retinues.lua` |

## 3. 真实验证状态

2026-11-14，DSH 工具原生检查确认以下专项全部通过；七个文件已加入默认国战套件。

| 专项 | 用例数 | 核心覆盖 |
| --- | --- | --- |
| `tests/wei_damage.lua` | 8 | 受伤事件与按点节命、遗计分配、裸衣持续、行殇牌区、骁果分支 |
| `tests/wei_support.lua` | 3 | 持重数量与分配、突袭转换接线、放逐原生定向叠／平置 |
| `tests/wei_phases.lua` | 14 | 神速三时机、设变／巧变真实移牌、洛神一次性获得、轻辎来源与到期、倾国／断粮／励战 |
| `tests/wei_pair_hp.lua` | 4 | 应期开局体力贡献、多势力／客将身份、升变复用 |
| `tests/wei_active.lua` | 6 | 长驱同步标记与客户端读取、强袭、伪溃私看及真实用杀、驱虎平局真实拼点与用杀 |
| `tests/wei_retrial.lua` | 2 | 鹰视真实判定与打出改判、禁止打出过滤 |
| `tests/wei_retinues.lua` | 3 | 并州狼骑决斗来源／距离／次数、虎卫军他人回合移牌、牛金击杀奖励只结算一次 |

最终验收命令与原生结果：

- `python scripts/test.py --timeout 180`：608 项通过，0 失败，退出码 0。包含原有回归、新增魏包 40 项及正式将表新增的应期组合断言。
- `python scripts/build_release.py`：构建 `.dev/dist/hanjin.zip`，446 个文件，退出码 0。
- Codex 核对发布包中魏区技能、三翼从、距离辅助骨架、共享工具及模式接线均与工作区一致，且不包含测试与开发脚本。

自动化和包内容核对不代替真实客户端点击、联网、重连及干净本体安装人工验收。

## 4. 接线与数据

- `pkg/hanjin_generals/skills/`：25 个魏技能与 3 个翼从技能均 `hanjinImplemented = true`，骨架含 effect；`init.lua` 的加载断言会检查已实装条目确有 effect。
- `pkg/hanjin_generals/data/standard.lua`：魏区 15 主称号与 25 技能原文已与 `rules/standard-generals.md` 魏区及 `docs/石激桑武将列表.json` 卡面核对，逐项差异为 0；其他势力数据未改。
- `pkg/hanjin_mode/rules/`、`skills/`：长驱的公开伤害记录、应期的配将体力、魏区阶段工具等公共接线分别见对应分组文档；本页不重复。
- `tests/all.lua`：已追加 `wei_damage`、`wei_support`、`wei_phases`、`wei_pair_hp`、`wei_active`、`wei_retrial`、`wei_retinues` 7 个专项。
- `docs/development/status.md` 与本页、各分组文档需保持一致；本页只记录可核验的实现与验证状态，不以计划或自述代替命令输出。

本分支同时包含前置规则与资料整理：外部 FAQ 的 Markdown 转换、武将表改名为 `石激桑武将列表.json`、外部参考资料登记，以及应期、骁果消耗和定向叠置／平置的已确认约定。参考资料保持原文，程序实现与验证状态分别记录。

## 5. 未完成与风险

- 未逐项完成真实客户端点击、多人联网／重连和未应用开发适配的干净本体安装验收。
- 定向用例验证主要效果及本轮发现的实质问题；部分少见组合依赖既有公共机制覆盖，不宣称穷举所有边界。
- 晋司马懿仅同步同文应期接线，其余晋技能不在魏包实装范围。
