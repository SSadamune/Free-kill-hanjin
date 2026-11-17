# 六势力阵包、势包：来源与审阅索引

以[石激桑武将列表](../docs/石激桑武将列表.json)的阵、势包记录为依据。每包12张普通武将及1张君主，两包共26张；六势力各两阵、两势，共24张普通武将。将牌技能共57条（普通51条、君主6条），所授技能、旗及关联翼从另列。原始资料保留来源内容，不直接改写。

## 普通武将

| 势力 | 阵包 | 势包 |
| --- | --- | --- |
| 汉 | [朱儁（HAN014）](generals/han014-zhujun.md)、[卢植（HAN015）](generals/han015-luzhi.md) | [吉平（HAN019）](generals/han019-jiping.md)、[刘虞（HAN022）](generals/han022-liuyu.md) |
| 魏 | [曹洪（WEI018）](generals/wei018-caohong.md)、[郭淮（WEI032）](generals/wei032-guohuai.md) | [李典（WEI017）](generals/wei017-lidian.md)、[臧霸（WEI023）](generals/wei023-zangba.md) |
| 蜀 | [姜维（SHU012）](generals/shu012-jiangwei.md)、[费祎（SHU018B）](generals/shu018b-feiyi.md) | [马岱（SHU019）](generals/shu019-madai.md)、[糜夫人（SHU021）](generals/shu021-mifuren.md) |
| 吴 | [蒋钦（WU017）](generals/wu017-jiangqin.md)、[徐盛（WU020）](generals/wu020-xusheng.md) | [孙策（WU010）](generals/wu010-sunce.md)、[陈武&董袭（WU023）](generals/wu023-chenwu-dongxi.md) |
| 群 | [于吉（QUN011）](generals/qun011-yuji.md)、[徐荣（QUN081）](generals/qun081-xurong.md) | [董卓（QUN006）](generals/qun006-dongzhuo.md)、[张任（QUN024）](generals/qun024-zhangren.md) |
| 晋 | [杜预（JIN006）](generals/jin006-duyu.md)、[马隆（JIN023）](generals/jin023-malong.md) | [王浑（JIN017）](generals/jin017-wanghun.md)、[牵弘（JIN022B）](generals/jin022b-qianhong.md) |

## 君主

- 阵：[君刘备 EM(SHU001)](generals/em-shu001-liubei.md)：章武、天钺、激诏及六师率义旗。
- 势：[君张角 EM(QUN010)](generals/em-qun010-zhangjiao.md)：弘法、悟心、问道及黄巾天兵符。

君主纳入内容审阅，按升变与继位流程取得，不进入普通武将选择池。24张普通武将、两张君主、三种新翼从及五条统领来源已接入正式阵势包，并有分批技能定向验证；完整验收范围见开发记录。复用同文技能的能力不等于新牌已经实装。

## 公共结算依据

- 时机、消耗、次数及“然后”依[通用约定](general-principles.md)，使用／打出／响应依[使用牌事件](../rulebook/events/use-card.md)分别处理。“指定目标后”逐目标产生，不自行以firstTarget限制为整张牌一次。
- 主将、副将是位置。普通士兵、翼从、偏将均为士兵牌，不是武将牌。变更主将／副将／武将允许操作士兵占据的位置；明确变更或移除武将牌则必须有武将牌。穿心的“副将武将牌”不包含副将位置上的士兵，其不能执行变更分支时结算“否则”。详见[位置与牌类别](general-principles.md#武将位置武将牌与士兵牌)、[变更](../rulebook/terms/general-op-terms/change.md)及[移除](../rulebook/terms/general-op-terms/remove.md)。
- 队列与围攻分别依[队列](../rulebook/terms/description-terms/queue.md)、[围攻](../rulebook/terms/description-terms/siege.md)，不能仅按同势力或攻击范围判断。[阵法技](../rulebook/terms/description-terms/array.md)底稿的少于四人无效，与[汉晋FAQ](../docs/规则向FAQ文件.md#阵法技阵法阵法召唤)四人及以下仍有效存在差异；阵法召唤另有出牌阶段限一次口径，须在公共实现中显式处理。
- 关系判断采用当前国战势力与座次；移出游戏角色依[FAQ](../docs/规则向FAQ文件.md#将角色移出游戏)处理，不借私有暗将资料公开形成同势力关系。状态授予与已建立回合效果依[效果分类](../rulebook/topics/skill-effect-classification.md)区分。
- 装备置入按[空栏规则](equipment-movement.md)；锋械各一张牌交换按[交换](../rulebook/terms/card-op-terms/swap.md)经处理区入对方手牌。若效果明确另定区域则依其明文。“至多”按[数值定义](../rulebook/terms/value-terms/atMost.md)不含0。
- 大小势力按[大势力](../rulebook/terms/description-terms/dashili.md)、[小势力](../rulebook/terms/description-terms/xiaoshili.md)定义；没有大势力时不能把全场归为小势力。旗修正的计算人数与实际角色列表区分。
- [统领与翼从](commander-retinue.md)集中处理来源、兵种和唯一性，不把拥有翼从解释为取得统领能力；[交换](general-exchange.md)保存牌的独立来源与状态。
- 烈戎、勤边及献捷依[汉晋应变](adaptation.md)登记完整条件／效果，牌的应变身份与实际触发分开，材料上的应变不自动继承。

## 实装约束

- 翼从按实际拥有实例计数，允许同名多份，包含龙飞共享，每份提供独立技能；普通翼从无限供应，偏将保持唯一性，候选不足三种取全部、无候选不能发动。详见[翼从实例规则](commander-retinue.md#拥有数量与独立实例)。
- 崩坏按董卓逐将页的完整定义；修体重复明置同一将牌暂不增加，武库暂向前追溯本回合最近合格牌。暂行口径仍应实现，不作为等待确认的阻塞。
- 疲攻不足给牌按座次优先、能给几张给几张；三陈全回合包括额外发动均禁止重复选人；横江每个弃牌阶段结束执行对应后续；破军返还手牌，死亡置弃牌堆。
- 场上不包含非公开信息；六师率义旗不检查暗将隐藏技能。天兵参与大小势力及悟心相关人数计算；承志包含主将后天获得的观星。所有属性杀的牌名为“杀”，牌名字数为1。
- 飞龙夺凤、太平要术沿用[基础牌表已选国战君主版](card-deck.md#6-卡牌版本选择)。技能与客户端交互须随正式扩展发布，不以开发本体补丁交付。

逐将页保存卡面原文和结算分析；接口及实际验证范围见[开发审阅记录](../docs/development/implementation/generals/zhen-shi-review.md)。本批规则已具备实施依据，运行验证仍需按实际交付记录。
