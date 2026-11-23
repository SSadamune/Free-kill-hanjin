# 晋势力标准包：逐将检索与验证入口

本页覆盖晋标准包15将、29条天生技能记录及腹心死士、文虎两种翼从，均已有正式实现。应期直接引用 WEI002 的同一技能 ID；其余技能按以下主记录检索，不重复正文。泰然后续时机尚未定案，当前按用户暂行指示在回合结束时逐次结算。规则依据见逐将页，当前验证与人工边界见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| JIN001 | [司马炎](standard/jin001.md) | [垂统](standard/jin001.md#jin001-1)、[兴图](standard/jin001.md#jin001-2) |
| JIN002 | [司马师](standard/jin002.md) | [泰然](standard/jin002.md#jin002-1)、[夷灭](standard/jin002.md#jin002-2)、[腹心死士](standard/retinue-fuxin-sishi.md#fuxin-sishi)（关联翼从） |
| JIN003 | [司马昭](standard/jin003.md) | [昭然](standard/jin003.md#jin003-1)、[挟征](standard/jin003.md#jin003-2) |
| JIN004 | [贾充](standard/jin004.md) | [通法](standard/jin004.md#jin004-1)、[悖弑](standard/jin004.md#jin004-2) |
| JIN005 | [羊祜](standard/jin005.md) | [柔克](standard/jin005.md#jin005-1)、[顺流](standard/jin005.md#jin005-2) |
| JIN007 | [王元姬](standard/jin007.md) | [识人](standard/jin007.md#jin007-1)、[恤下](standard/jin007.md#jin007-2) |
| JIN008 | [夏侯徽](standard/jin008.md) | [宜室](standard/jin008.md#jin008-1)、[识度](standard/jin008.md#jin008-2) |
| JIN009 | [司马懿](standard/jin009.md) | [权变](standard/jin009.md#jin009-1)、[骤霆](standard/jin009.md#jin009-2)、[应期](standard/wei002.md#wei002-3)、[腹心死士](standard/retinue-fuxin-sishi.md#fuxin-sishi)（关联翼从） |
| JIN010 | [张春华](standard/jin010.md) | [伤逝](standard/jin010.md#jin010-1)、[扼绝](standard/jin010.md#jin010-2) |
| JIN011 | [张虎&乐綝](standard/jin011.md) | [果毅](standard/jin011.md#jin011-1) |
| JIN012 | [羊徽瑜](standard/jin012.md) | [慈威](standard/jin012.md#jin012-1)、[弘训](standard/jin012.md#jin012-2) |
| JIN013 | [王濬](standard/jin013.md) | [乘流](standard/jin013.md#jin013-1)、[克清](standard/jin013.md#jin013-2) |
| JIN014 | [文鸯](standard/jin014.md) | [膂力](standard/jin014.md#jin014-1)、[夺气](standard/jin014.md#jin014-2)、[文虎](standard/retinue-wenhu.md#wenhu)（关联翼从） |
| JIN015 | [石苞](standard/jin015.md) | [前驱](standard/jin015.md#jin015-1) |
| JIN016 | [张华](standard/jin016.md) | [复礼](standard/jin016.md#jin016-1)、[风物](standard/jin016.md#jin016-2) |

运行时武将 ID 采用 `qiao_heg__` 前缀，例如 `qiao_heg__jin001`。除应期外，各技能源码为 `pkg/qiao_generals/skills/skill_jin编号_顺序.lua`。应期共用 `qiao__skill_wei002_3`。

## 2. 关联翼从

[腹心死士](standard/retinue-fuxin-sishi.md#fuxin-sishi)、[文虎](standard/retinue-wenhu.md#wenhu)均已实现。三项统领能力沿用[公共机制](../commander-retinue.md)：JIN002 红桃出其不意附助战条目，JIN009 调虎离山，JIN014 限一冰杀；翼从取得和限一统领能力的计数分别处理。

## 3. 接线

晋新增技能及两翼从均在骨架上设置 `qiaoImplemented = true`，加载断言核对实际 effect。既有司马炎保留白名单；应期共用魏技能。

`mode.lua` 正式注册 `qiao__jin_resources_rule`（泰然及限定技事实）、`qiao__jin_deck_rule`（权变已建立禁用）、`qiao__jin_information_rule`（昭然持续可见）、`qiao__jin_adaptation_rule`（本次用牌雷伤）、`qiao__jin_sources_rule`（复礼承诺与花色禁用）。柔克、克清的持续监听按需安装在房间中；扼绝复用单技能失去入口及交换来源过滤，保留将牌失技状态。正式卡包依锁定应变参考登记冰伤属性，真实冰伤重置有定向回归。

默认 `tests/all.lua` 接入八套新增晋专项：`jin_basic`、`jin_resources`、`jin_deck`、`jin_information`、`jin_reactive`、`jin_adaptation`、`jin_chain`、`jin_sources`。原 `jin001_simayan` 与 `wei_pair_hp` 覆盖继续复用。

## 4. 验证

[实装前审阅快照](verification-evidence.md#2026-11-15-晋标准包规则与实现路径审阅)保留当时的来源差异和接口考察。

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的晋包最终验收](verification-evidence.md#jin-standard)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

普通司马炎的垂统、兴图分别见[垂统](standard/jin001.md#jin001-1)与[兴图](standard/jin001.md#jin001-2)。君主版的实装与回归见[弩包君司马炎](nu/em-jin001.md)。

## 5. 未完成与边界

未应用开发适配的本体人工交互验收尚未执行。全局记录以使用牌事件为准，未覆盖“无任何目标但被使用”的边缘牌型，后续如出现具体用例再补。用户曾报告“应变牌后的下一回合，敌方普通杀→八卦阵视为闪，兴图误触发”，自动化未能复现；真实连续回合回归及虚拟闪无应变条目检查通过，2026-11-13 用户复测确认已无异常，该反馈关闭，不据此追认具体根因，也未保留无复现依据的回合序号补丁。用户同时确认当轮界面调整无异常；该复测不代表完整联网、重连或未应用开发适配的独立本体验收。

### 规范化描述待办
