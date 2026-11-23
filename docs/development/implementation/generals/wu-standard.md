# 吴势力标准包：逐将检索与验证入口

本页是吴包 15 将、27 个天生技能、后天技能涉猎及锦帆军／曲阿小将两翼从的逐将检索入口，武将和卡面技能链接到逐将页，运行时 ID、源码和验证依据随对应条目维护。规则依据见[标准武将表](../../../rules/standard-generals.md)与逐将规范，规则确认、实现与人工验收分别记录，当前完成度见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| WU001 | [孙权](standard/wu001.md) | [制衡](standard/wu001.md#wu001-1) |
| WU002 | [甘宁](standard/wu002.md) | [奇袭](standard/wu002.md#wu002-1)、[锦帆军](standard/retinue-jinfanjun.md#jinfanjun)（关联翼从） |
| WU003 | [吕蒙](standard/wu003.md) | [克己](standard/wu003.md#wu003-1)、[谋断](standard/wu003.md#wu003-2)、[涉猎](standard/wu003.md#wu003-3)（关联） |
| WU004 | [黄盖](standard/wu004.md) | [苦肉](standard/wu004.md#wu004-1)、[诈降](standard/wu004.md#wu004-2) |
| WU005 | [周瑜](standard/wu005.md) | [英姿](standard/wu005.md#wu005-1)、[反间](standard/wu005.md#wu005-2) |
| WU006 | [大乔](standard/wu006.md) | [国色](standard/wu006.md#wu006-1)、[流离](standard/wu006.md#wu006-2) |
| WU007 | [陆逊](standard/wu007.md) | [谦逊](standard/wu007.md#wu007-1)、[度势](standard/wu007.md#wu007-2) |
| WU008 | [孙尚香](standard/wu008.md) | [结姻](standard/wu008.md#wu008-1)、[枭姬](standard/wu008.md#wu008-2) |
| WU009 | [孙坚](standard/wu009.md) | [英魂](standard/wu009.md#wu009-1) |
| WU011 | [小乔](standard/wu011.md) | [天香](standard/wu011.md#wu011-1)、[红颜](standard/wu011.md#wu011-2) |
| WU012 | [太史慈](standard/wu012.md) | [天义](standard/wu012.md#wu012-1)、[酣战](standard/wu012.md#wu012-2)、[曲阿小将](standard/retinue-quaxiaojiang.md#quaxiaojiang)（关联翼从） |
| WU013 | [周泰](standard/wu013.md) | [不屈](standard/wu013.md#wu013-1)、[奋激](standard/wu013.md#wu013-2) |
| WU014 | [鲁肃](standard/wu014.md) | [好施](standard/wu014.md#wu014-1)、[缔盟](standard/wu014.md#wu014-2) |
| WU015A | [张昭](standard/wu015a.md) | [直谏](standard/wu015a.md#wu015a-1)、[固政](standard/wu015a.md#wu015a-2) |
| WU016 | [丁奉](standard/wu016.md) | [短兵](standard/wu016.md#wu016-1)、[奋迅](standard/wu016.md#wu016-2) |

涉猎以 `related = true` 登记，仅通过谋断获得，不计入天生技能数。

## 2. 关联翼从

| 翼从 | 运行时 ID | 实现详情 | 验证 |
| --- | --- | --- | --- |
| 锦帆军 | `qiao_heg__retinue_jinfanjun` | [翼从专属技能](standard/retinue-jinfanjun.md#jinfanjun) | [wu_damage](../../../../tests/wu_damage.lua) |
| 曲阿小将 | `qiao_heg__retinue_quaxiaojiang` | [翼从专属技能](standard/retinue-quaxiaojiang.md#quaxiaojiang) | [wu_damage](../../../../tests/wu_damage.lua) |

统领能力和翼从效果由[公共机制](../commander-retinue.md)与[规则](../../../rules/commander-retinue.md)提供，不在翼从专属技能中重写。

## 3. 接线

- [standard.lua](../../../../pkg/qiao_generals/data/standard.lua)：吴区 15 个主称号、27 条天生技能原文与标准表核对一致；多称号只取首项。涉猎仍为后天相关技能，`M.skillCount = 160` 原口径不变；其他 75 张武将数据块未改。
- 技能骨架均显式 `qiaoImplemented = true`；[init.lua](../../../../pkg/qiao_generals/init.lua) 既有加载断言确认有实际 effect。技能独立注册，仅用于汉晋模式。
- [mode.lua](../../../../pkg/qiao_mode/mode.lua) 在启动时安装公开历史、奋迅距离、诈降／天义／好施持续效果及缔盟到期辅助；对应文件在 `pkg/qiao_mode/skills/wu_*.lua`，公开事实层在 `rules/wu_history.lua`。客户端读取同步状态，不读取服务端事件树；涉猎整理规则随共享工具在正式扩展注册。
- 初始开发前先由 Codex 整理规则要点、公共接口方向及少量核心验收，DSH 分批实现并依审阅修正；采用按风险分层的验证，不将规则场景逐项变成新增测试义务。

## 4. 验证

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的吴区](verification-evidence.md#吴区)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

<a id="wu-standard-boundary"></a>

## 5. 未完成与边界

未进行真实客户端逐项点击、多人联网／重连和干净本体安装运行验收。服务端真实请求及代表性 ClientPlayer 自动化不代替这些人工结果。少见红颜／禁弃组合、多次濒死完整求桃链、复杂嵌套与改目标组合未穷举，具体边界见所属机制专项；不因默认全量通过而宣称所有组合已验证。
