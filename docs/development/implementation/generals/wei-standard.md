# 魏势力标准包：逐将检索与验证入口

本页是魏势力标准包 15 将 25 技能与并州狼骑、虎卫军、牛金 3 张魏关联翼从的逐将检索入口，武将和卡面技能链接到逐将页，运行时 ID、源码和验证依据随对应条目维护。规则表见[标准武将表](../../../rules/standard-generals.md)，牌面数据来源为 `assets/docs/石激桑武将列表.json`（外部资料只读），逐将裁定以 `docs/rules/generals/` 的已确认文件为准，不替代规则条文。当前完成度见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| WEI001 | [曹操](standard/wei001.md) | [奸雄](standard/wei001.md#wei001-1) |
| WEI002 | [司马懿](standard/wei002.md) | [狼顾](standard/wei002.md#wei002-1)、[鹰视](standard/wei002.md#wei002-2)、[应期](standard/wei002.md#wei002-3) |
| WEI003 | [夏侯惇](standard/wei003.md) | [刚烈](standard/wei003.md#wei003-1)、[持重](standard/wei003.md#wei003-2) |
| WEI004 | [张辽](standard/wei004.md) | [突袭](standard/wei004.md#wei004-1)、[并州狼骑](standard/retinue-bingzhou-langqi.md#bingzhou-langqi)（关联翼从） |
| WEI005 | [许褚](standard/wei005.md) | [裸衣](standard/wei005.md#wei005-1)、[虎卫军](standard/retinue-huweijun.md#huweijun)（关联翼从） |
| WEI006 | [郭嘉](standard/wei006.md) | [轻辎](standard/wei006.md#wei006-1)、[遗计](standard/wei006.md#wei006-2) |
| WEI007 | [甄姬](standard/wei007.md) | [倾国](standard/wei007.md#wei007-1)、[洛神](standard/wei007.md#wei007-2) |
| WEI008 | [夏侯渊](standard/wei008.md) | [神速](standard/wei008.md#wei008-1)、[设变](standard/wei008.md#wei008-2) |
| WEI009 | [张郃](standard/wei009.md) | [巧变](standard/wei009.md#wei009-1) |
| WEI010 | [徐晃](standard/wei010.md) | [断粮](standard/wei010.md#wei010-1)、[长驱](standard/wei010.md#wei010-2) |
| WEI011 | [曹仁](standard/wei011.md) | [伪溃](standard/wei011.md#wei011-1)、[励战](standard/wei011.md#wei011-2)、[牛金](standard/retinue-niujin.md#niujin)（关联翼从） |
| WEI012 | [典韦](standard/wei012.md) | [强袭](standard/wei012.md#wei012-1)、[虎卫军](standard/retinue-huweijun.md#huweijun)（关联翼从） |
| WEI013 | [荀彧](standard/wei013.md) | [驱虎](standard/wei013.md#wei013-1)、[节命](standard/wei013.md#wei013-2) |
| WEI014 | [曹丕](standard/wei014.md) | [行殇](standard/wei014.md#wei014-1)、[放逐](standard/wei014.md#wei014-2) |
| WEI016 | [乐进](standard/wei016.md) | [骁果](standard/wei016.md#wei016-1) |

保留 `WEI016` 乐进及原编号缺号，不改运行时 ID。

## 2. 关联翼从

| 翼从 | 运行时 ID | 实现详情 | 验证 |
| --- | --- | --- | --- |
| 并州狼骑 | `qiao_heg__retinue_bingzhou_langqi` | [翼从专属技能](standard/retinue-bingzhou-langqi.md#bingzhou-langqi)（多来源张辽／吕布，已在条目交叉注明） | [wei_retinues](../../../../tests/wei_retinues.lua) |
| 虎卫军 | `qiao_heg__retinue_huweijun` | [翼从专属技能](standard/retinue-huweijun.md#huweijun) | [wei_retinues](../../../../tests/wei_retinues.lua) |
| 牛金 | `qiao_heg__retinue_niujin` | [翼从专属技能](standard/retinue-niujin.md#niujin) | [wei_retinues](../../../../tests/wei_retinues.lua) |

## 3. 接线

- [skills/](../../../../pkg/qiao_generals/skills)：25 个魏技能与 3 个翼从技能均 `qiaoImplemented = true`，骨架含 effect；`init.lua` 的加载断言会检查已实装条目确有 effect。应期只保留 `qiao__skill_wei002_3` 一份骨架，晋司马懿直接引用同一 ID，不另设薄包装；两处卡面文本统一为魏文本“☯️+2”。
- [standard.lua](../../../../pkg/qiao_generals/data/standard.lua)：魏区 15 主称号与 25 技能原文已与 `docs/rules/standard-generals.md` 魏区及 `assets/docs/石激桑武将列表.json` 卡面核对，逐项差异为 0；其他势力数据未改。
- [all.lua](../../../../tests/all.lua)：已追加 `wei_damage`、`wei_support`、`wei_phases`、`wei_pair_hp`、`wei_active`、`wei_retrial`、`wei_retinues` 7 个专项。
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
- 晋司马懿仅同步同文应期接线，其余晋技能不在魏包实装范围；应期正文见[配将体力](standard/wei002.md#wei002-3)。
