# 汉晋项目设计与裁定规范

本目录记录汉晋的设计、机制约定、内容资料与逐将裁定，供程序开发和规则集编纂使用。它不是《汉晋规则集》，也不会通过迁移实现章节自动变成正式条文。

未来高度精炼、成体系的《汉晋规则集》在 [`rulebook/`](../../rulebook/README.md) 独立编纂。当前以复制到 [`rulebook/`](../../rulebook/README.md) 的基础条文为起点，按本目录已确认的汉晋差异开发。明确标为建议或待审阅的内容保持待裁定，不因代码或测试存在而获批。项目长期方向见[愿景说明](../vision.md)。

## 项目规范索引

- 四位君主技能审阅：[君孙权](generals/em-wu001-sunquan.md)、[君曹操](generals/em-wei001-caocao.md)、[君司马炎](generals/em-jin001-simayan.md)、[君刘协](generals/em-han001-liuxie.md)。以石激桑 JSON 为基准；“赐”由旗拥有者持有，变更分支每名角色整局限一次且消耗标记；诏书是特殊标记，始终不进入玩家区域。实现与验收见[开发状态](../development/status.md)。

- [六势力阵包、势包审阅](zhen-shi-generals.md)：24 张普通武将与两张君主的来源、逐将结算及待明确边界。

- [通用约定](general-principles.md)：模式、归属、操作时机、消耗及升变共同约定。
- [装备移动与置入](equipment-movement.md)：汉晋用词默认移入空置的对应装备栏，不默认替换已有装备。
- [势力禁选](faction-ban.md)：房主候选、允许上限、跨局记录、测试用自由选将例外。
- [应变](adaptation.md)：条件、触发、忽略条件、助战及效果语义。
- [统领与翼从](commander-retinue.md)：统领能力与翼从效果、来源、兵种及身份。
- [交换武将](general-exchange.md)：合法位置、技能状态与牌堆归属。
- [第二君主](second-lord.md)：普通升变、死亡继位及超员规则。
- [野心家效忠](wild-allegiance.md)：准备阶段升变与开局版本入池。
- [客将](guest-factions.md)：本局主势力、客将启用与自愿重抽。
- [基础牌表](card-deck.md)：实体牌位、替换关系、应变登记及已选卡牌版本。
- [标准武将与翼从资料](standard-generals.md)：原编号、属性、客将势力及卡面技能原文。
- [同一张牌的多次结算](card-resolution.md)：结算循环、时机及使用方法保持。
- [指定额外目标](extra-targets.md)：默认条件、显式例外及逐牌约束。
- [效果指定的用牌目标条件](card-use-targets.md)：沿用原条件、仅放宽指定限制及显式条件。
- [“只能当”描述约定](only-as.md)：转换用途、权限、牌名与多来源共存。
- [鏖战状态](battle-royal.md)：实体桃的使用限制与转换用途。
- [HAN001 刘协裁定草案](generals/han001-liuxie.md)：六项确认裁定及仍标为建议的内容。
- [HAN004 张让结算约定](generals/han004-zhangrang.md)：同一回合多次滔乱，回合末后续效果统一结算一次，候选取本回合指定过的角色并集。
- [HAN007 王荣结算约定](generals/han007-wangrong.md)：追德提供敏思额外发动；次数原则引用通用约定。
- [HAN008 伏皇后结算约定](generals/han008-fuhuanghou.md)：求援仅调整牌效果的结算先后。
- [HAN016A 刘宠结算约定](generals/han016a-liuchong.md)：劲弩排除阶段内零用牌、威屯先选同一组目标。
- [HAN017 刘繇结算约定](generals/han017-liuyao.md)：戡难按每名角色限次；逆拒每次没赢摸牌，点数增益累计且封顶 13。
- [JIN001 司马炎结算约定](generals/jin001-simayan.md)：垂统的濒死装备移动与兴图的回合用牌检查、选项及转化用桃。
- [WEI002 司马懿结算约定](generals/wei002-simayi.md)：应期的配将体力贡献、开局判定及多势力／客将依据。
- [WEI014 曹丕结算约定](generals/wei014-caopi.md)：放逐的定向叠置／平置。
- [WEI016 乐进结算约定](generals/wei016-yuejin.md)：骁果弃置基本牌为发动消耗，不能零弃牌发动。
- [SHU007 黄月英结算约定](generals/shu007-huangyueying.md)：集智包含有对应实体牌且未经转化的普通、延时锦囊；区分玩家文本与规范描述中的“虚拟牌”。
- [JIN009 司马懿结算约定](generals/jin009-simayi.md)：权变的阶段花色事实、骤霆的亮出上限及同文应期的公共裁定。
- 晋标准包其余逐将审阅：[司马师](generals/jin002-simashi.md)、[司马昭](generals/jin003-simazhao.md)、[贾充](generals/jin004-jiachong.md)、[羊祜](generals/jin005-yanghu.md)、[王元姬](generals/jin007-wangyuanji.md)、[夏侯徽](generals/jin008-xiahouhui.md)、[张春华](generals/jin010-zhangchunhua.md)、[张虎&乐綝](generals/jin011-zhanghu-yuechen.md)、[羊徽瑜](generals/jin012-yanghuiyu.md)、[王濬](generals/jin013-wangjun.md)、[文鸯](generals/jin014-wenyang.md)、[石苞](generals/jin015-shibao.md)、[张华](generals/jin016-zhanghua.md)。待裁定项目保留在对应逐将页，腹心死士与文虎专属技能分别归入司马师、文鸯页。
- [WU003 吕蒙结算约定](generals/wu003-lvmeng.md)：谋断仅获得涉猎，涉猎为后天技能及其定义。
- [WU005 周瑜结算约定](generals/wu005-zhouyu.md)：反间响应选择及同花色手牌、装备牌的弃置范围。
- [WU013 周泰结算约定](generals/wu013-zhoutai.md)：不屈病句修正，摸牌数与置“创”张数的区别。
- [WU015A 张昭结算约定](generals/wu015a-zhangzhao.md)：直谏的原区域与摸牌者按斜线顺序对应。
- [QUN001 华佗结算约定](generals/qun001-huatuo.md)：济世受客将替换设置控制，默认开启；跨势力交换首次成功即止。
- [QUN002 吕布结算约定](generals/qun002-lvbu.md)：无双响应数增量与虓猛当前回合角色选择。
- [QUN010 张角结算约定](generals/qun010-zhangjiao.md)：鬼道的替换包含获得原判定牌。
- [QUN015 纪灵结算约定](generals/qun015-jiling.md)：双刃没赢后的转换限制至本回合结束。
- [QUN016 田丰来源基线](generals/qun016-tianfeng.md)：死谏和随势采用标准表原文，区别当前运行时资料中的版本。

## 阅读与维护

- 外部[《规则向FAQ文件》](../../assets/docs/规则向FAQ文件.md)与 `assets/docs/石激桑武将列表.json` 均可作为汉晋原创规则参考。FAQ 保留来源，不随项目维护更新；采用的规则及已确认差异在本目录另行记录。
- 《乔剪国战表格》可作《大合集》范围以外的平行时空武将设计参考。资料冲突时的优先顺序见[外部资料登记](../../assets/README.md#外部文档与数据)。
- 具体武将按编号集中在 `generals/`，引用公共规范，不重复另定通则。现有标准武将表保留卡面描述；规范描述的精确抽象写法见[编写指南](../development/normalized-descriptions.md)。
- 《汉晋规则集》采用外部基准的术语和结算结构，根据汉晋设计独立编写正式条文；本目录提供依据，不代替该成果。
- 接口、接线、测试方法、故障案例与开发完成度统一查阅[开发指南](../development/README.md)及[状态表](../development/status.md)。本索引不再重复记录测试数量或“已实现”等动态说明。
- 规则修改须核对来源和既有裁定；实现中发现歧义或偏差时反馈到相应规范，经确认后同步正式条文、代码及测试。程序行为不自动构成裁定。
