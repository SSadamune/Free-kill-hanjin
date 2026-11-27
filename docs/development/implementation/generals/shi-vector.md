# 矢包

君刘协与十二名普通武将均在兵情篇登记。逐将页收录卡面原文、实现入口和测试依据。[牌面与客籍登记](../../../../pkg/qiao_bingqing/data/shi_vector.lua) · [矢包专项测试](../../../../tests/shi_vector.lua)

## 逐将检索

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| EM(HAN001) | [君刘协](shi-vector/em-han001.md) | [初平](shi-vector/em-han001.md#em-han001-1)、[转蓬](shi-vector/em-han001.md#em-han001-2)、[天授](shi-vector/em-han001.md#em-han001-3)、[诏书](shi-vector/em-han001.md#em-han001-banner)（派生／标记） |
| HAN047 | [田畴](shi-vector/han047.md) | [锋引](shi-vector/han047.md#han047-1)、[径出](shi-vector/han047.md#han047-2) |
| HAN051 | [袁隗](shi-vector/han051.md) | [唆令](shi-vector/han051.md#han051-1)、[趋奉](shi-vector/han051.md#han051-2) |
| JIN037 | [成济&成倅](shi-vector/jin037.md) | [养刀](shi-vector/jin037.md#jin037-1)、[畜鸣](shi-vector/jin037.md#jin037-2) |
| JIN066 | [胡奋](shi-vector/jin066.md) | [威惠](shi-vector/jin066.md#jin066-1)、[练战](shi-vector/jin066.md#jin066-2)、[转征](shi-vector/jin066.md#jin066-3) |
| QUN033 | [蔡夫人](shi-vector/qun033.md) | [窃听](shi-vector/qun033.md#qun033-1)、[献州](shi-vector/qun033.md#qun033-2) |
| QUN079 | [高览](shi-vector/qun079.md) | [袭阵](shi-vector/qun079.md#qun079-1)、[芟敌](shi-vector/qun079.md#qun079-2) |
| SHU048 | [董允](shi-vector/shu048.md) | [秉正](shi-vector/shu048.md#shu048-1)、[舍宴](shi-vector/shu048.md#shu048-2) |
| SHU091 | [杨仪](shi-vector/shu091.md) | [度断](shi-vector/shu091.md#shu091-1)、[孤忿](shi-vector/shu091.md#shu091-2) |
| WEI035 | [陈群](shi-vector/wei035.md) | [品第](shi-vector/wei035.md#wei035-1)、[法恩](shi-vector/wei035.md#wei035-2) |
| WEI044 | [程昱](shi-vector/wei044.md) | [胆戾](shi-vector/wei044.md#wei044-1)、[脱先](shi-vector/wei044.md#wei044-2) |
| WU027 | [程普](shi-vector/wu027.md) | [铁脊](shi-vector/wu027.md#wu027-1)、[醇义](shi-vector/wu027.md#wu027-2) |
| WU032 | [顾雍](shi-vector/wu032.md) | [密重](shi-vector/wu032.md#wu032-1)、[秉壹](shi-vector/wu032.md#wu032-2) |

## 本地验证（2026-11-27）

[矢包原生专项](../../../../tests/shi_vector.lua)共 26 项，全部通过。覆盖客将势力与珠联、移将与暗置、跨角色响应、临时授技及袁隗【唆令】连续使用转化的属性【杀】。

另测三项交互。蔡夫人遇到仅有受保护宝物的君孙权时正常摸牌；袁隗交出黑牌后，只改变收牌人原手牌颜色，两次均收到相同的公开读条；成济＆成倅的【借刀杀人】使用普通牌的次目标候选。

以主线 1b137f2 为基线，默认原生全量 1,508/1,508 通过，包含已经合入主线的【三陈】暗置重连用例。
