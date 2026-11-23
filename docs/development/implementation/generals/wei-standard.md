# 魏势力标准包：逐将检索与验证入口

本页是魏势力标准包 15 将 25 技能与并州狼骑、虎卫军、牛金 3 张魏关联翼从的逐将检索入口，统一列出编号、运行时 ID、源码、逐技能实现详情与验证依据；技能正文只在机制页维护一份，本页不重复。规则表见[标准武将表](../../../rules/standard-generals.md)，牌面数据来源为 `assets/docs/石激桑武将列表.json`（外部资料只读），逐将裁定以 `docs/rules/generals/` 的已确认文件为准，不替代规则条文。当前完成度见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| WEI001 | 曹操 | [奸雄](damage.md#wei001-1) |
| WEI002 | 司马懿 | [狼顾](damage.md#wei002-1)、[鹰视](retrial.md#wei002-2)、[应期](pair-hp.md#wei002-3) |
| WEI003 | 夏侯惇 | [刚烈](damage.md#wei003-1)、[持重](support.md#wei003-2) |
| WEI004 | 张辽 | [突袭](support.md#wei004-1)、[并州狼骑](retinues.md#bingzhou-langqi)（关联翼从） |
| WEI005 | 许褚 | [裸衣](damage.md#wei005-1)、[虎卫军](retinues.md#huweijun)（关联翼从） |
| WEI006 | 郭嘉 | [轻辎](support.md#wei006-1)、[遗计](damage.md#wei006-2) |
| WEI007 | 甄姬 | [倾国](conversion.md#wei007-1)、[洛神](retrial.md#wei007-2) |
| WEI008 | 夏侯渊 | [神速](phases.md#wei008-1)、[设变](support.md#wei008-2) |
| WEI009 | 张郃 | [巧变](phases.md#wei009-1) |
| WEI010 | 徐晃 | [断粮](conversion.md#wei010-1)、[长驱](active.md#wei010-2) |
| WEI011 | 曹仁 | [伪溃](active.md#wei011-1)、[励战](support.md#wei011-2)、[牛金](retinues.md#niujin)（关联翼从） |
| WEI012 | 典韦 | [强袭](damage.md#wei012-1)、[虎卫军](retinues.md#huweijun)（关联翼从） |
| WEI013 | 荀彧 | [驱虎](pindian.md#wei013-1)、[节命](damage.md#wei013-2) |
| WEI014 | 曹丕 | [行殇](damage.md#wei014-1)、[放逐](support.md#wei014-2) |
| WEI016 | 乐进 | [骁果](damage.md#wei016-1) |

保留 `WEI016` 乐进及原编号缺号，不改运行时 ID。

## 2. 关联翼从

| 翼从 | 运行时 ID | 实现详情 | 验证 |
| --- | --- | --- | --- |
| 并州狼骑 | `qiao_heg__retinue_bingzhou_langqi` | [翼从专属技能](retinues.md#bingzhou-langqi)（多来源张辽／吕布，已在条目交叉注明） | [wei_retinues](../../../../tests/wei_retinues.lua) |
| 虎卫军 | `qiao_heg__retinue_huweijun` | [翼从专属技能](retinues.md#huweijun) | [wei_retinues](../../../../tests/wei_retinues.lua) |
| 牛金 | `qiao_heg__retinue_niujin` | [翼从专属技能](retinues.md#niujin) | [wei_retinues](../../../../tests/wei_retinues.lua) |

## 3. 接线

- [skills/](../../../../pkg/qiao_generals/skills)：25 个魏技能与 3 个翼从技能均 `qiaoImplemented = true`，骨架含 effect；`init.lua` 的加载断言会检查已实装条目确有 effect。应期只保留 `qiao__skill_wei002_3` 一份骨架，晋司马懿直接引用同一 ID，不另设薄包装；两处卡面文本统一为魏文本“☯️+2”。
- [standard.lua](../../../../pkg/qiao_generals/data/standard.lua)：魏区 15 主称号与 25 技能原文已与 `docs/rules/standard-generals.md` 魏区及 `assets/docs/石激桑武将列表.json` 卡面核对，逐项差异为 0；其他势力数据未改。
- [all.lua](../../../../tests/all.lua)：已追加 `wei_damage`、`wei_support`、`wei_phases`、`wei_pair_hp`、`wei_active`、`wei_retrial`、`wei_retinues` 7 个专项。
- 本批实质修正：伪溃私看由全体展示 `room:showCards(hand, player)` 改为真实私看 `room:viewCards(player, { cards = hand, skill_name = ..., prompt = ... })`，测试记录收件角色与牌集；长驱不再使用私有 `room:getTag`，新增公开事实层（`qiao_wei_damage_targets`）与模式级 `fk.Damage` 记录器，客户端与服务端读同一公开数据；伪溃 `can_use` 要求 `player.hp >= 1`，强袭要求体力至少 1 或拥有可弃武器牌（失去体力消耗不得超过当前体力，不把有可弃武器的强袭一并限制为体力至少 1）；驱虎 `winner ~= player`（含平局／空结果）走真实视为【杀】分支；鹰视新增 `skill_wei002_2.lua`。
- 共享模块与发布接线：

| 内容 | 正式实现文件 | 接线与验证入口 |
| --- | --- | --- |
| 正式将与翼从注册、展示文本 | [init.lua](../../../../pkg/qiao_generals/init.lua)、[standard.lua](../../../../pkg/qiao_generals/data/standard.lua) | 既有骨架加载与 `qiaoImplemented` 断言；[正式将表测试](../../../../tests/standard_generals.lua) |
| 开局配将体力 | [pair_hp.lua](../../../../pkg/qiao_mode/rules/pair_hp.lua)、[mode.lua](../../../../pkg/qiao_mode/mode.lua) | `broadcastGeneral → apply_start`；[应期专项](../../../../tests/wei_pair_hp.lua) |
| 升变体力复用 | [ascension.lua](../../../../pkg/qiao_mode/rules/ascension.lua) | 升变前后调用同一组合计算；普通换将不接重算 |
| 长驱公开伤害事实 | [wei_history.lua](../../../../pkg/qiao_mode/rules/wei_history.lua)、[wei_damage_history.lua](../../../../pkg/qiao_mode/skills/wei_damage_history.lua) | 模式启动即安装；同步玩家标记供客户端、服务端读取；[主动组专项](../../../../tests/wei_active.lua) |
| 伪溃持续固定距离 | [wei_distance_effects.lua](../../../../pkg/qiao_mode/skills/wei_distance_effects.lua) | 模式级状态技只读回合标记，失去原技能不提前结束效果 |
| 阶段组与虎卫军移牌 | [wei_phases.lua](../../../../pkg/qiao_generals/util/wei_phases.lua) | 公开势力预测、引擎两步移牌；[阶段专项](../../../../tests/wei_phases.lua)、[翼从专项](../../../../tests/wei_retinues.lua) |
| 并州狼骑持续双向距离 | [retinue_skill_bingzhou_distance.lua](../../../../pkg/qiao_generals/skills/retinue_skill_bingzhou_distance.lua) | 随包加载辅助骨架；双方关系表与回合末清理 |
| 突袭用途限制 | [only_as.lua](../../../../pkg/qiao_mode/rules/only_as.lua) | 复用已有 `tuxi` 定义，在展示后登记独立回合来源；[辅助组专项](../../../../tests/wei_support.lua) |

- 与汉包一样，正式安装包包含技能骨架、共享模块和客户端可读的状态接线，不包含测试内容或开发本体补丁。
- 牌面数据同步范围：相对汉包提交 `27da26b`，仅修订魏区 15 条称号及 3 条技能文本——应期“阴阳鱼+2”改回来源符号“☯️+2”，刚烈“伤害来源”改回“来源”，行殇改回完整原文；25 条魏技能文本均已核对。本分支同时包含前置规则与资料整理（外部 FAQ 的 Markdown 转换、武将表改名为 `石激桑武将列表.json`、外部参考资料登记，以及应期、骁果消耗和定向叠置／平置的已确认约定）；参考资料保持原文。

## 4. 验证

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的魏区](verification-evidence.md#魏区)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

## 5. 未完成与边界

- 未逐项完成真实客户端点击、多人联网／重连和未应用开发适配的干净本体安装验收。
- 定向用例验证主要效果及本批发现的实质问题；部分少见组合依赖既有公共机制覆盖，不宣称穷举所有边界。
- 晋司马懿仅同步同文应期接线，其余晋技能不在魏包实装范围；应期正文见[配将体力](pair-hp.md#wei002-3)。
