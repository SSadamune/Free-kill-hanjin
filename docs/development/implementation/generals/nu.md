# 弩包

兵情篇收录君司马炎与十二名弩包普通武将。九条统领来源共用七种普通翼从，【青州精锐】沿用臧霸的实现，【无当飞军】与权包王平共用。[牌面与统领登记](../../../../pkg/qiao_bingqing/data/nu.lua) · [原生专项](../../../../tests/nu_generals.lua)

## 逐将检索

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| EM(JIN001) | [君司马炎](nu/em-jin001.md) | [太康](nu/em-jin001.md#em-jin001-1)、[採幸](nu/em-jin001.md#em-jin001-2)、[鼎沸](nu/em-jin001.md#em-jin001-3)、[诸王敕封册与赐](nu/em-jin001.md#em-jin001-banner)（派生／标记） |
| HAN043 | [杨奉&韩暹](nu/han043.md) | [拔驾](nu/han043.md#han043-1) |
| HAN055 | [陶谦](nu/han055.md) | [厉治](nu/han055.md#han055-1)、[州忧](nu/han055.md#han055-2)、[丹阳青巾](nu/han055.md#retinue-danyang-qingjin)（统领） |
| JIN067 | [李秀](nu/jin067.md) | [替军](nu/jin067.md#jin067-1)、[誓众](nu/jin067.md#jin067-2) |
| JIN076 | [孟观](nu/jin076.md) | [积弩](nu/jin076.md#jin076-1)、[天述](nu/jin076.md#jin076-2)、[宿卫中军](nu/jin076.md#retinue-suwei-zhongjun)（统领） |
| QUN029 | [高顺](nu/qun029.md) | [迅击](nu/qun029.md#qun029-1)、[擐甲](nu/qun029.md#qun029-2)、[陷阵营](nu/qun029.md#retinue-xianzhenying)（统领） |
| QUN139 | [管亥](nu/qun139.md) | [卸尾](nu/qun139.md#qun139-1)、[诱阙](nu/qun139.md#qun139-2)、[青州精锐](nu/qun139.md#retinue-qingzhou-jingrui)（统领） |
| SHU036 | [张嶷](nu/shu036.md) | [越险](nu/shu036.md#shu036-1)、[无当飞军](nu/shu036.md#retinue-wudang-feijun)（统领） |
| SHU054 | [张翼](nu/shu054.md) | [殿军](nu/shu054.md#shu054-1)、[抗锐](nu/shu054.md#shu054-2) |
| WEI034 | [曹真](nu/wei034.md) | [司镇](nu/wei034.md#wei034-1)、[虎豹骑](nu/wei034.md#retinue-hubaoqi)（统领） |
| WEI061 | [曹纯](nu/wei061.md) | [督锐](nu/wei061.md#wei061-1)、[虎豹骑](nu/wei061.md#retinue-hubaoqi)（统领） |
| WU028 | [韩当](nu/wu028.md) | [弓骑](nu/wu028.md#wu028-1)、[驰援](nu/wu028.md#wu028-2)、[解烦卫](nu/wu028.md#retinue-jiefanwei)（统领） |
| WU048 | [贺齐](nu/wu048.md) | [闪击](nu/wu048.md#wu048-1)、[华甲](nu/wu048.md#wu048-2)、[丹阳青巾](nu/wu048.md#retinue-danyang-qingjin)（统领） |

## 统领与翼从

- [丹阳青巾](nu/retinue-danyang-qingjin.md#danyang-qingjin)
- [虎豹骑](nu/retinue-hubaoqi.md#hubaoqi)
- [无当飞军](../../../../pkg/qiao_generals/skills/retinue_skill_wudang_feijun.lua)
- [解烦卫](nu/retinue-jiefanwei.md#jiefanwei)
- [陷阵营](nu/retinue-xianzhenying.md#xianzhenying)
- [青州精锐](../../../../pkg/qiao_generals/skills/retinue_skill_qingzhou_jingrui.lua)
- [宿卫中军](nu/retinue-suwei-zhongjun.md#suwei-zhongjun)

## 本地验证（2026-11-27）

[弩包原生专项](../../../../tests/nu_generals.lua)共 46 项，全部通过。覆盖【越险】对原手牌和【八卦阵】的限制、实体「饵」和【积弩】随将交换、两份翼从的独立消耗、【司镇】与【督锐】的回合结算，以及【擐甲】借双栏坐骑后按两栏归还。【拔驾】另测多张「舆」分别维系、暗置或失技时保留状态、暗置副将接受或拒绝亮将、同批失去及阶段外失去。见[杨奉＆韩暹逐将页](../../../rules/generals/han043-yangfeng-hanxian.md)。

【解烦卫】按技能本身的使用限制列出可复原项。覆测君刘备【激诏】、君司马炎【鼎沸】实际再次发动，以及两份已消耗翼从先后获赠复原。两张【杀】嵌套时，【虎豹骑】追击先使用且最终只有一个目标的那张。孟观用【丈八蛇矛】转化扣置牌，两种选牌顺序均不触发【积弩】判定。

与君孙权同场时，公开【聚宝】排除不能取走和不能被替换的宝物。用李秀【替军】验证正常置入、拦下新装备和拦下旧装备三种结果，同时断言实际牌区与阶段。

弩包已接入包含权包 #75 的主线（`a4855ac`）。与最终分支代码、依赖和测试相同的集成版本通过原生全量 1,549/1,549，其中弩包专项 46/46。转向主线后，弩包、权包汉魏蜀、模式及跨包登记联合专项 73/73 通过，确认张嶷与王平都以【杀】统领同一【无当飞军】。
