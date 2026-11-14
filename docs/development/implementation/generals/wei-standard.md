# 魏势力标准包：逐将检索与验证入口

本页是魏势力标准包 15 将 25 技能与并州狼骑、虎卫军、牛金 3 张魏关联翼从的逐将检索入口，统一列出编号、运行时 ID、源码、逐技能实现详情与验证依据；技能正文只在机制页维护一份，本页不重复。规则表见[标准武将表](../../../../rules/standard-generals.md)，牌面数据来源为 `docs/石激桑武将列表.json`（外部资料只读），逐将裁定以 `rules/generals/` 的已确认文件为准，不替代规则条文。当前完成度见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 | 运行时 ID | 源码 | 实现详情 | 验证 |
| --- | --- | --- | --- | --- | --- | --- |
| WEI001 | 曹操 | 奸雄 | `hanjin__wei001` | [skill_wei001_1](../../../../pkg/hanjin_generals/skills/skill_wei001_1.lua) | [奸雄](damage.md#wei001-1) | [wei_damage](../../../../tests/wei_damage.lua) |
| WEI002 | 司马懿 | 狼顾、鹰视、应期 | `hanjin__wei002` | [skill_wei002_1](../../../../pkg/hanjin_generals/skills/skill_wei002_1.lua)、[skill_wei002_2](../../../../pkg/hanjin_generals/skills/skill_wei002_2.lua)、[skill_wei002_3](../../../../pkg/hanjin_generals/skills/skill_wei002_3.lua) | [狼顾](damage.md#wei002-1)、[鹰视](retrial.md#wei002-2)、[应期](pair-hp.md#wei002-3) | [wei_damage](../../../../tests/wei_damage.lua)、[wei_retrial](../../../../tests/wei_retrial.lua)、[wei_pair_hp](../../../../tests/wei_pair_hp.lua) |
| WEI003 | 夏侯惇 | 刚烈、持重 | `hanjin__wei003` | [skill_wei003_1](../../../../pkg/hanjin_generals/skills/skill_wei003_1.lua)、[skill_wei003_2](../../../../pkg/hanjin_generals/skills/skill_wei003_2.lua) | [刚烈](damage.md#wei003-1)、[持重](support.md#wei003-2) | [wei_damage](../../../../tests/wei_damage.lua)、[wei_support](../../../../tests/wei_support.lua) |
| WEI004 | 张辽 | 突袭 | `hanjin__wei004` | [skill_wei004_1](../../../../pkg/hanjin_generals/skills/skill_wei004_1.lua) | [突袭](support.md#wei004-1) | [wei_support](../../../../tests/wei_support.lua) |
| WEI005 | 许褚 | 裸衣 | `hanjin__wei005` | [skill_wei005_1](../../../../pkg/hanjin_generals/skills/skill_wei005_1.lua) | [裸衣](damage.md#wei005-1) | [wei_damage](../../../../tests/wei_damage.lua) |
| WEI006 | 郭嘉 | 轻辎、遗计 | `hanjin__wei006` | [skill_wei006_1](../../../../pkg/hanjin_generals/skills/skill_wei006_1.lua)、[skill_wei006_2](../../../../pkg/hanjin_generals/skills/skill_wei006_2.lua) | [轻辎](support.md#wei006-1)、[遗计](damage.md#wei006-2) | [wei_phases](../../../../tests/wei_phases.lua)、[wei_damage](../../../../tests/wei_damage.lua) |
| WEI007 | 甄姬 | 倾国、洛神 | `hanjin__wei007` | [skill_wei007_1](../../../../pkg/hanjin_generals/skills/skill_wei007_1.lua)、[skill_wei007_2](../../../../pkg/hanjin_generals/skills/skill_wei007_2.lua) | [倾国](conversion.md#wei007-1)、[洛神](retrial.md#wei007-2) | [wei_phases](../../../../tests/wei_phases.lua) |
| WEI008 | 夏侯渊 | 神速、设变 | `hanjin__wei008` | [skill_wei008_1](../../../../pkg/hanjin_generals/skills/skill_wei008_1.lua)、[skill_wei008_2](../../../../pkg/hanjin_generals/skills/skill_wei008_2.lua) | [神速](phases.md#wei008-1)、[设变](support.md#wei008-2) | [wei_phases](../../../../tests/wei_phases.lua) |
| WEI009 | 张郃 | 巧变 | `hanjin__wei009` | [skill_wei009_1](../../../../pkg/hanjin_generals/skills/skill_wei009_1.lua) | [巧变](phases.md#wei009-1) | [wei_phases](../../../../tests/wei_phases.lua) |
| WEI010 | 徐晃 | 断粮、长驱 | `hanjin__wei010` | [skill_wei010_1](../../../../pkg/hanjin_generals/skills/skill_wei010_1.lua)、[skill_wei010_2](../../../../pkg/hanjin_generals/skills/skill_wei010_2.lua) | [断粮](conversion.md#wei010-1)、[长驱](active.md#wei010-2) | [wei_phases](../../../../tests/wei_phases.lua)、[wei_active](../../../../tests/wei_active.lua) |
| WEI011 | 曹仁 | 伪溃、励战 | `hanjin__wei011` | [skill_wei011_1](../../../../pkg/hanjin_generals/skills/skill_wei011_1.lua)、[skill_wei011_2](../../../../pkg/hanjin_generals/skills/skill_wei011_2.lua) | [伪溃](active.md#wei011-1)、[励战](support.md#wei011-2) | [wei_active](../../../../tests/wei_active.lua)、[wei_phases](../../../../tests/wei_phases.lua) |
| WEI012 | 典韦 | 强袭 | `hanjin__wei012` | [skill_wei012_1](../../../../pkg/hanjin_generals/skills/skill_wei012_1.lua) | [强袭](damage.md#wei012-1) | [wei_active](../../../../tests/wei_active.lua) |
| WEI013 | 荀彧 | 驱虎、节命 | `hanjin__wei013` | [skill_wei013_1](../../../../pkg/hanjin_generals/skills/skill_wei013_1.lua)、[skill_wei013_2](../../../../pkg/hanjin_generals/skills/skill_wei013_2.lua) | [驱虎](pindian.md#wei013-1)、[节命](damage.md#wei013-2) | [wei_active](../../../../tests/wei_active.lua)、[wei_damage](../../../../tests/wei_damage.lua) |
| WEI014 | 曹丕 | 行殇、放逐 | `hanjin__wei014` | [skill_wei014_1](../../../../pkg/hanjin_generals/skills/skill_wei014_1.lua)、[skill_wei014_2](../../../../pkg/hanjin_generals/skills/skill_wei014_2.lua) | [行殇](damage.md#wei014-1)、[放逐](support.md#wei014-2) | [wei_damage](../../../../tests/wei_damage.lua)、[wei_support](../../../../tests/wei_support.lua) |
| WEI016 | 乐进 | 骁果 | `hanjin__wei016` | [skill_wei016_1](../../../../pkg/hanjin_generals/skills/skill_wei016_1.lua) | [骁果](damage.md#wei016-1) | [wei_damage](../../../../tests/wei_damage.lua) |

保留 `WEI016` 乐进及原编号缺号，不改运行时 ID。

## 2. 关联翼从

| 翼从 | 运行时 ID | 实现详情 | 验证 |
| --- | --- | --- | --- |
| 并州狼骑 | `hanjin__retinue_bingzhou_langqi` | [翼从专属技能](retinues.md#bingzhou-langqi)（多来源张辽／吕布，已在条目交叉注明） | [wei_retinues](../../../../tests/wei_retinues.lua) |
| 虎卫军 | `hanjin__retinue_huweijun` | [翼从专属技能](retinues.md#huweijun) | [wei_retinues](../../../../tests/wei_retinues.lua) |
| 牛金 | `hanjin__retinue_niujin` | [翼从专属技能](retinues.md#niujin) | [wei_retinues](../../../../tests/wei_retinues.lua) |

## 3. 接线

- [skills/](../../../../pkg/hanjin_generals/skills/)：25 个魏技能与 3 个翼从技能均 `hanjinImplemented = true`，骨架含 effect；`init.lua` 的加载断言会检查已实装条目确有 effect。
- [standard.lua](../../../../pkg/hanjin_generals/data/standard.lua)：魏区 15 主称号与 25 技能原文已与 `rules/standard-generals.md` 魏区及 `docs/石激桑武将列表.json` 卡面核对，逐项差异为 0；其他势力数据未改。
- [all.lua](../../../../tests/all.lua)：已追加 `wei_damage`、`wei_support`、`wei_phases`、`wei_pair_hp`、`wei_active`、`wei_retrial`、`wei_retinues` 7 个专项。
- 本批实质修正：伪溃私看由全体展示 `room:showCards(hand, player)` 改为真实私看 `room:viewCards(player, { cards = hand, skill_name = ..., prompt = ... })`，测试记录收件角色与牌集；长驱不再使用私有 `room:getTag`，新增公开事实层（`hanjin_wei_damage_targets`）与模式级 `fk.Damage` 记录器，客户端与服务端读同一公开数据；伪溃 `can_use` 要求 `player.hp >= 1`，强袭要求体力至少 1 或拥有可弃武器牌（失去体力消耗不得超过当前体力，不把有可弃武器的强袭一并限制为体力至少 1）；驱虎 `winner ~= player`（含平局／空结果）走真实视为【杀】分支；鹰视新增 `skill_wei002_2.lua`。
- 共享模块与发布接线：

| 内容 | 正式实现文件 | 接线与验证入口 |
| --- | --- | --- |
| 正式将与翼从注册、展示文本 | [init.lua](../../../../pkg/hanjin_generals/init.lua)、[standard.lua](../../../../pkg/hanjin_generals/data/standard.lua) | 既有骨架加载与 `hanjinImplemented` 断言；[正式将表测试](../../../../tests/standard_generals.lua) |
| 开局配将体力 | [pair_hp.lua](../../../../pkg/hanjin_mode/rules/pair_hp.lua)、[mode.lua](../../../../pkg/hanjin_mode/mode.lua) | `broadcastGeneral → apply_start`；[应期专项](../../../../tests/wei_pair_hp.lua) |
| 升变体力复用 | [ascension.lua](../../../../pkg/hanjin_mode/rules/ascension.lua) | 升变前后调用同一组合计算；普通换将不接重算 |
| 长驱公开伤害事实 | [wei_history.lua](../../../../pkg/hanjin_mode/rules/wei_history.lua)、[wei_damage_history.lua](../../../../pkg/hanjin_mode/skills/wei_damage_history.lua) | 模式启动即安装；同步玩家标记供客户端、服务端读取；[主动组专项](../../../../tests/wei_active.lua) |
| 伪溃持续固定距离 | [wei_distance_effects.lua](../../../../pkg/hanjin_mode/skills/wei_distance_effects.lua) | 模式级状态技只读回合标记，失去原技能不提前结束效果 |
| 阶段组与虎卫军移牌 | [wei_phases.lua](../../../../pkg/hanjin_generals/util/wei_phases.lua) | 公开势力预测、引擎两步移牌；[阶段专项](../../../../tests/wei_phases.lua)、[翼从专项](../../../../tests/wei_retinues.lua) |
| 并州狼骑持续双向距离 | [retinue_skill_bingzhou_distance.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_bingzhou_distance.lua) | 随包加载辅助骨架；双方关系表与回合末清理 |
| 突袭用途限制 | [only_as.lua](../../../../pkg/hanjin_mode/rules/only_as.lua) | 复用已有 `tuxi` 定义，在展示后登记独立回合来源；[辅助组专项](../../../../tests/wei_support.lua) |

- 与汉包一样，正式安装包包含技能骨架、共享模块和客户端可读的状态接线，不包含测试内容或开发本体补丁。
- 牌面数据同步范围：相对汉包提交 `27da26b`，仅修订魏区 15 条称号及 3 条技能文本——应期“阴阳鱼+2”改回来源符号“☯️+2”，刚烈“伤害来源”改回“来源”，行殇改回完整原文；25 条魏技能文本均已核对。本分支同时包含前置规则与资料整理（外部 FAQ 的 Markdown 转换、武将表改名为 `石激桑武将列表.json`、外部参考资料登记，以及应期、骁果消耗和定向叠置／平置的已确认约定）；参考资料保持原文。

## 4. 验证

2026-11-14，DSH 工具原生检查确认以下专项全部通过；七个文件已加入默认国战套件：

| 专项 | 用例数 | 核心覆盖 |
| --- | --- | --- |
| [wei_damage.lua](../../../../tests/wei_damage.lua) | 8 | 受伤事件与按点节命、遗计分配、裸衣持续、行殇牌区、骁果分支 |
| [wei_support.lua](../../../../tests/wei_support.lua) | 3 | 持重数量与分配、突袭转换接线、放逐原生定向叠／平置 |
| [wei_phases.lua](../../../../tests/wei_phases.lua) | 14 | 神速三时机、设变／巧变真实移牌、洛神一次性获得、轻辎来源与到期、倾国／断粮／励战 |
| [wei_pair_hp.lua](../../../../tests/wei_pair_hp.lua) | 4 | 应期开局体力贡献、多势力／客将身份、升变复用 |
| [wei_active.lua](../../../../tests/wei_active.lua) | 6 | 长驱同步标记与客户端读取、强袭、伪溃私看及真实用杀、驱虎平局真实拼点与用杀 |
| [wei_retrial.lua](../../../../tests/wei_retrial.lua) | 2 | 鹰视真实判定与打出改判、禁止打出过滤 |
| [wei_retinues.lua](../../../../tests/wei_retinues.lua) | 3 | 并州狼骑决斗来源／距离／次数、虎卫军他人回合移牌、牛金击杀奖励只结算一次 |

最终验收命令与原生结果：

- `python scripts/test.py --timeout 180`：608 项通过，0 失败，退出码 0。包含原有回归、新增魏包 40 项及正式将表新增的应期组合断言。
- `python scripts/build_release.py`：构建 `.dev/dist/hanjin.zip`，446 个文件，退出码 0。
- Codex 核对发布包中魏区技能、三翼从、距离辅助骨架、共享工具及模式接线均与工作区一致，且不包含测试与开发脚本。

各文件命令与日期见[共享验证证据](verification-evidence.md#魏区)；自动化和包内容核对不代替真实客户端点击、联网、重连及干净本体安装人工验收。

## 5. 未完成与边界

- 未逐项完成真实客户端点击、多人联网／重连和未应用开发适配的干净本体安装验收。
- 定向用例验证主要效果及本批发现的实质问题；部分少见组合依赖既有公共机制覆盖，不宣称穷举所有边界。
- 晋司马懿仅同步同文应期接线，其余晋技能不在魏包实装范围；应期正文见[配将体力](pair-hp.md#wei002-3)。
