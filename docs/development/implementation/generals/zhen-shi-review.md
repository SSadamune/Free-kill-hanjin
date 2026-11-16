# 六势力阵包、势包：实现路径审阅

## 标识与依据

内容以[石激桑武将列表](../../../../docs/石激桑武将列表.json)为来源，阵、势包各13张，共24张普通武将及两张君主。将牌技能57条（普通51、君主6），关联三种新翼从、黄巾雷使、两旗及所授技能另列。[来源和逐将索引](../../../../rules/zhen-shi-generals.md)记录游戏语义，本页记录工程入口与验证边界。

正式入口`pkg/hanjin_generals/init.lua`目前只读`data/standard.lua`，本批武将尚未登记。现有同文技能是复用基础，不代表新武将已经完成。

本地核对版本：runtime的`fk_ver`为0.5.25；hegemony提交为`e8d93acd34a357f96b0105aef7d661708c211626`，utility为`b14e45d9adf67b06bf150f71022e8f1dc0e26116`，均与`dependencies.lock.json`一致。以下上游路径相对`.dev/runtime/FreeKill-release/`，均为只读参考。

## 实现与接口

### 阵法与技能来源

已阅读`packages/hegemony/util.lua`的`getFormationRelation`、`inFormationRelation`、`inSiegeRelation`。队列列表返回其他成员，自身参与队列须确实存在同队列者；围攻接口分别接收两名围攻者与被围攻者，持技者不一定是实际用杀者。少人数阵法及召唤时机须处理汉晋规则差异，不能只复制上游。

| 实际阅读的上游路径 | 可参考部分及汉晋差异 |
| --- | --- |
| `packages/hegemony/pkg/mobile_heg/skills/heyi.lua` | 技能来源刷新；上游无队列时给自己、有队列时给其他角色，汉晋按真实队列成员处理 |
| `packages/hegemony/pkg/formation/skills/tianfu.lua` | 主将标签、formation召唤及队列判断；汉晋效果是全场攻击范围+2，不是获得看破 |
| `packages/hegemony/pkg/formation/skills/niaoxiang.lua` | 围攻及指定目标入口；上游固定两闪，汉晋是在已有要求上多一闪 |
| `packages/hegemony/pkg/mobile_heg/skills/niaoxiang.lua` | 红杀条件与汉晋不同，仅作版本辨识 |
| `packages/hegemony/pkg/formation/skills/qianhuan.lua` | 置将牌、唯一目标取消及延时锦囊入口；汉晋限体力上限，不要求四花色各异 |
| `packages/hegemony/pkg/hegemony_nos/skills/huyuan.lua` | 选择装备及置入流程；汉晋有回合内任意装备置入后触发，距离从被装备者计算，弃牌可含判定区 |
| `packages/hegemony/pkg/formation/skills/huyuan.lua` | 实为转化调虎离山，不能当本次护援效果 |
| `packages/hegemony/pkg/mobile_heg/skills/chuanxin.lua` | 实为伤害后弃牌／乘势移将，不是汉晋穿心的伤害前翼从分支 |
| `packages/hegemony/pkg/momentum/skills/hongfa.lua` | 旗来源结构；上游天兵当杀、防失体力等能力不能附加到汉晋正文 |
| `packages/hegemony/pkg/momentum/skills/yingyang.lua` | `PindianCardsDisplayed`与`changePindianNumber`，主要效果可适配 |

虎翼、鹤翼、天覆、鸟翔、锥形、龙飞均须核对阵法及所属将牌。明暗置、失技、死亡、改势力、座次和移出游戏后即时重算状态，只在回合末刷新不足。多来源授予不能用全局删除同名技能误伤独立来源。摧破、激昂、剽戮等按实际逐目标时机，不能无依据增加firstTarget条件。

### 用牌与延时效果

已核对`ltk/server/room.lua`：`askToUseCard`返回待执行`UseCardDataSpec`，`askToResponse`返回待执行`RespondCardDataSpec`。`ltk/core/events/misc.lua`中的请求数据含`user`、`pattern`、`eventData`和`result`。屏御须保持原闪请求与多闪语境，完成郭淮打出、请求者使用的归属，不把普通虚拟闪结果当成已经执行。

原始`Room:askToUseVirtualCard`可由skip控制执行；项目`pkg/hanjin_mode/rules/card_use_targets.lua`的封装契约为：`selectVirtualCard`只选择复核，`askToUseVirtualCard`选择并执行一次。交回引擎的数据用选择接口，不得重复使用已执行返回值，详见[公共入口](../card-use-targets.md)。

用良按明示目标策略；挑衅最多两名角色分别追踪真实用杀伤害；虎翼是技能回合限一次；尚义含响应后入口，须同时考虑使用型响应与打出型响应。锋械按各一张确定牌交换经处理区入对方手牌，再按单人／队列目标组接杀，不只提高普通杀目标上限。

`ltk/core/events/hp.lua`的`PreHpRecover`可用于蛊毒防止整次回复；`ltk/core/events/movecard.lua`的`BeforeDrawCard`对应恂恂首次摸牌前，不能只接摸牌阶段。忘隙按伤害事件，横江按每点伤害，两者计次不同；疲攻含使用及打出基本牌。

疑城是使用装备／回合末弃1二选一；守成每回合每名角色一次摸2弃1；存嗣按轮分别记录回合内杀及回合外桃。横江在弃牌阶段结束检查，蛊毒在回合结束结算，破军的牌返还晚于角色移回。已建立效果按公共分类处理，不能一概要求技能仍在。

### 武将位置与牌类别

`H.removeGeneral(player,isDeputy)`默认主将；`H.transformGeneral(room,player,isMain,isHidden,num,generals)`的位置参数含义相反，默认候选数为1。原始变更遇暗将会先revealGeneral，与汉晋暗将无须验明、不触发明置后存在差异，须适配。

位置与牌类别的合法性必须在调用前区分：

- 变更主将／副将／武将是位置操作，允许位置上的普通士兵、翼从、偏将被变更。
- 明确要求变更或移除武将牌，必须实际存在武将牌，士兵不能代替。
- 穿心明确要求副将武将牌；其为士兵时仍可发动穿心，但直接执行否则分支：伤害+1，张任本局拥有所选翼从。不得调用宽泛的位置变更把士兵变更为翼从后判作成功。
- 勇决、蛊毒锚定此武将牌，交换后不得误操作原位置的新牌；移除将牌和变更位置的事件分别走公共流程。

详见[公共定义](../../../../rules/general-principles.md#武将位置武将牌与士兵牌)。客户端合法性须只读公开位置与类别，不依赖服务端私有暗将字段；服务端执行前复核。

`pkg/hanjin_mode/rules/commander_retinue.lua`已有assignRetinue、convertPosition及来源登记，主要服务实体士兵转换。穿心额外拥有和龙飞共享不能冒充普通统领来源，接入时按独立实例计数和授技，普通翼从无限供应，不以同名技能ID合并来源。

### 复用、应变与关联内容

项目同文入口位于`pkg/hanjin_generals/skills/`：马术`skill_shu006_1.lua`、观星`skill_shu004_1.lua`、英魂`skill_wu009_1.lua`、英姿`skill_wu005_1.lua`、仁德`skill_shu001_1.lua`。观星正文与实现已读，其卜算数目前写在技能内，承志按主将印刷或后天观星来源接入数值；其他条目核对了文件和技能身份，未重审全部既有效果。

已核对`pkg/hanjin_mode/rules/adaptation.lua`的setCardEntries、addEntry、isAdaptationCard。烈戎、勤边、献捷须赋完整应变条目；总戎是状态型无次数限制，正常计实际使用，不当成应变ignore_times。遄征为限定技，改本回合击杀奖惩而不只下一次，所获献捷未限本回合。

关联内容：八阵兵由姜维与马隆提供，轮次视为使用调虎离山并为该次结算提供杀当无懈；青州精锐由臧霸提供，统领牌为雷杀；庐江上甲由陈武董袭提供，实际弃牌才增加阶段杀次数；君张角提供黄巾雷使与铁索连环，复用现有同文翼从技能。各兵种技能正文见逐将页，统领能力不与翼从效果混用。

六师率义旗按来源两牌换一项场上没有的指定技能；黄巾天兵符按来源补天兵与计算群人数修正，不引入上游附加能力。旗人数计算含天兵修正，技能候选只检查公开信息；飞龙夺凤、太平要术沿用[基础牌表已选国战君主版本](../../../../rules/card-deck.md#6-卡牌版本选择)，核对正式独立牌接线。

## 验证依据

来源解析确认26张牌、57条将牌技能，逐将保留完整原文；静态审阅核对锁定版本、正式入口、同名上游和公共接口。文档验收检查技能顺序、原文完整性、相对文件链接及git diff --check。

未修改技能实现、测试或外部原始数据；未运行python scripts/test.py、安装包构建或客户端／联网／重连人工验收。规则明确不等于接口已通过运行验证。

## 未完成与边界

规则依据见[实装约束](../../../../rules/zhen-shi-generals.md#实装约束)。修体、武库按逐将页暂行口径实现；翼从同名技能实例、座次给牌、阶段重复后续及牌返还是核心接线约束。开发先打通少量真实流程，再处理屏御、穿心／龙飞、破军等复杂入口；不把所有规则场景当逐项测试义务。复用公共机制覆盖，具体风险才新增边界测试。稳定后由唯一测试执行者运行默认套件，新增正式注册及客户端入口时构建并检查安装包。
