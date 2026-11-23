# 群势力标准包：逐将检索

本页是群势力标准包的逐将入口，不重复技能正文。本包正式登记 15 张武将。马术复用同一运行时 ID，关联翼从在各自统领来源的行中标出。规则依据见[标准武将表](../../../rules/standard-generals.md)及 `docs/rules/generals/qun*.md`；实现与验证在各武将页维护。

## 逐将检索

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| QUN001 | [华佗](standard/qun001.md) | [济世](standard/qun001.md#qun001-1)、[除疠](standard/qun001.md#qun001-2) |
| QUN002 | [吕布](standard/qun002.md) | [无双](standard/qun002.md#qun002-1)、[虓猛](standard/qun002.md#qun002-2)、[并州狼骑](standard/retinue-bingzhou-langqi.md#bingzhou-langqi)（关联翼从） |
| QUN003 | [貂蝉](standard/qun003.md) | [离间](standard/qun003.md#qun003-1)、[闭月](standard/qun003.md#qun003-2) |
| QUN004 | [袁绍](standard/qun004.md) | [乱击](standard/qun004.md#qun004-1) |
| QUN005 | [颜良&文丑](standard/qun005.md) | [双雄](standard/qun005.md#qun005-1) |
| QUN007 | [贾诩](standard/qun007.md) | [完杀](standard/qun007.md#qun007-1)、[乱武](standard/qun007.md#qun007-2)、[帷幕](standard/qun007.md#qun007-3) |
| QUN008 | [庞德](standard/qun008.md) | [马术](standard/shu006.md#shu006-1)、[猛撼](standard/qun008.md#qun008-2) |
| QUN010 | [张角](standard/qun010.md) | [雷击](standard/qun010.md#qun010-1)、[鬼道](standard/qun010.md#qun010-2)、[黄巾雷使](standard/retinue-huangjin-leishi.md#huangjin-leishi)（关联翼从） |
| QUN012 | [蔡文姬](standard/qun012.md) | [悲歌](standard/qun012.md#qun012-1)、[断肠](standard/qun012.md#qun012-2) |
| QUN013 | [马腾](standard/qun013.md) | [马术](standard/shu006.md#shu006-1)、[雄异](standard/qun013.md#qun013-2)、[西凉精骑](standard/retinue-xiliang-jingqi.md#xiliang-jingqi)（关联翼从） |
| QUN015 | [纪灵](standard/qun015.md) | [双刃](standard/qun015.md#qun015-1) |
| QUN016 | [田丰](standard/qun016.md) | [死谏](standard/qun016.md#qun016-1)、[随势](standard/qun016.md#qun016-2) |
| QUN017 | [潘凤](standard/qun017.md) | [狂斧](standard/qun017.md#qun017-1) |
| QUN018 | [邹氏](standard/qun018.md) | [祸水](standard/qun018.md#qun018-1)、[倾城](standard/qun018.md#qun018-2) |
| QUN027 | [韩遂](standard/qun027.md) | [马术](standard/shu006.md#shu006-1)、[骁逆](standard/qun027.md#qun027-2)、[西凉精骑](standard/retinue-xiliang-jingqi.md#xiliang-jingqi)（关联翼从） |

QUN008、QUN013、QUN027 的马术与 SHU006 马超共用 `qiao__skill_shu006_1`，不另建正文；三处逐将链接复用[同一锚点](standard/shu006.md#shu006-1)。黄巾雷使的翼从专属技能见[翼从专属技能](standard/retinue-huangjin-leishi.md#huangjin-leishi)。

## 测试入口与当前状态

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的群包历史验收](verification-evidence.md#qun-standard)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

群包专项统一从 [qun_standard.lua](../../../../tests/qun_standard.lua) 进入，单技能回归见各条目的证据。

## 版本与来源

- QUN016 的[死谏](standard/qun016.md#qun016-1)与[随势](standard/qun016.md#qun016-2)按[来源基线](../../../rules/generals/qun016-tianfeng.md)采用标准版。QUN015 的[双刃](standard/qun015.md#qun015-1)按[逐将裁定](../../../rules/generals/qun015-jiling.md)处理。
- 马术的同文共享及多来源去重见[马术](standard/shu006.md#shu006-1)。

## 模式级接线

以下技能已由 `pkg/qiao_mode/mode.lua` 在 `logic:start` 注册房间规则；文档只记必要接线，不转为正式规则：

- [qun_dying_rule](../../../../pkg/qiao_mode/skills/qun_dying_rule.lua)：完杀用桃禁止与济世濒死序号／客将交换收尾，共享状态见 [util/qun_dying](../../../../pkg/qiao_generals/util/qun_dying.lua)。
- [qun_cards_rule](../../../../pkg/qiao_mode/skills/qun_cards_rule.lua)：乱击响应摸牌、狂斧与骁逆的用牌后结算、乱击花色清理。
- [qun_damage_history](../../../../pkg/qiao_mode/skills/qun_damage_history.lua)：黄巾雷使的首个非手牌伤害机会事实。
- [qun_control_rule](../../../../pkg/qiao_mode/skills/qun_control_rule.lua)：祸水回合内禁明置的按来源维护，工具见 [util/qun_control](../../../../pkg/qiao_generals/util/qun_control.lua)。
- [qun_duanchang_rule](../../../../pkg/qiao_mode/skills/qun_duanchang_rule.lua)：断肠已失技在后续明置时的幂等兜底，失技模块见 [qun_duanchang](../../../../pkg/qiao_mode/rules/qun_duanchang.lua)。

## 实际参考

本地引擎 `fk_ver` 0.5.25；hegemony HEAD `e8d93acd34a357f96b0105aef7d661708c211626`、utility HEAD `b14e45d9adf67b06bf150f71022e8f1dc0e26116`，与 `dependencies.lock.json` 一致。以下路径相对于 `.dev/runtime/FreeKill-release/`，只读未改上游：

- `packages/standard/pkg/skills/{jijiu,lijian,wushuang}.lua`：转桃、离间用牌及响应数入口；急救限制回合外，不符合济世。
- `packages/hegemony/pkg/standard/skills/{chuli,luanji,wushuang,shuangxiong,xiongyi,shuangren,sijian,suishi,kuangfu,huoshui,qingcheng,duanchang,weimu}.lua`，另读 `pkg/mobile_heg/skills/kuangfu.lua`：同名差异明显，尤其无双写死 2、双雄时机和牌区不同、双刃两分支不同、随势缺少弃手牌、狂斧效果不同，均不可直接复制。
- `ltk/core/events/usecard.lua`：`AimData` 响应次数、`UseCardData:isUsingHandcard`、`damageDealt` 及响应关联字段；`ltk/core/events/hp.lua`：体力变化数据；`ltk/server/events/judge.lua`：`changeJudge{exchange=true}` 获得旧判定牌。
- 项目内复用：`skill_shu006_1.lua`（共享马术）、`skill_wei002_2.lua`（真实打出改判）、`general_exchange.lua`、`only_as.lua`、`card_use_targets.lua` 及 [黄巾雷使](standard/retinue-huangjin-leishi.md#huangjin-leishi)、[并州狼骑](standard/retinue-bingzhou-langqi.md#bingzhou-langqi)、[西凉精骑](standard/retinue-xiliang-jingqi.md#xiliang-jingqi) 的既有实现。

## 待验证与待办

- 定向与默认全量已通过，具体命令与覆盖以[开发状态](../../status.md)和[验证记录](verification-evidence.md#qun-standard)为准。
- 修复除疠及乱武、狂斧、祸水、倾城、骁逆的客户端房间读取；客户端按钮回归已纳入默认套件，验证记录见下述链接。默认全量 764/764 及安装包核对已完成；客户端点击、联网／重连、干净本体安装仍未人工验收。
