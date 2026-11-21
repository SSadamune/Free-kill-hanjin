# 六势力阵包、势包：实现路径审阅

## 标识与依据

内容以[石激桑武将列表](../../../../assets/docs/石激桑武将列表.json)为来源，阵、势包各13张，共24张普通武将及两张君主。将牌技能57条（普通51、君主6），关联三种新翼从、黄巾雷使、两旗及所授技能另列。[来源和逐将索引](../../../rules/zhen-shi-generals.md)记录游戏语义，本页记录工程入口与验证边界。

正式入口 `pkg/qiao_generals/init.lua` 将标准包与阵势包各数据片段合并加载。标准90将数据及其包计数不变；阵、势包以独立正式 `Package` `qiao_zhenshi` 接入。已验证内容与待完成项见下文；登记、代码存在和运行验证分别记录。

本地核对版本：runtime的`fk_ver`为0.5.25；hegemony提交为`e8d93acd34a357f96b0105aef7d661708c211626`，utility为`b14e45d9adf67b06bf150f71022e8f1dc0e26116`，均与`dependencies.lock.json`一致。以下上游路径相对`.dev/runtime/FreeKill-release/`，均为只读参考。

## 实现与接口

### 阵法与技能来源

汉晋两种模式共用独立主动技 `qiao__array_summon`。鹤翼、天覆、龙飞提供队列入口，虎翼、鸟翔、锥形提供围攻入口。阵法来源随明置将牌同步，包括附在将牌上的后天技能与主副将位置限制。一个阶段共用一份召唤历史，虎翼等本技另行计次。

`pkg/qiao_mode/rules/array_summon.lua` 复用国战座次与势力比较，以及引擎的单亮、双亮事件。它按下家、上家分别结算，并记录本次已询问角色。上游 `ArraySummonSkill` 的围攻结算只取一侧，通用亮将请求超时可能随机选项。汉晋对座次命中的暗将发送可取消的私有询问，依据本局选定势力和禁亮状态提供选项。无人同意时照常消耗发动次数。

`tests/array_summon.lua` 覆盖客户端确认回包、双侧队列与围攻、四人及三人残局、重叠座次、超时、禁亮、客将、野心家主将、附将来源及人数上限。最近全量结果见[开发状态](../../status.md#当前验收基线)。

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
| `packages/hegemony/pkg/formation/skills/shengxi.lua` | 上游为弃牌阶段开始且无“可以”询问；汉晋改为结束阶段、可选，在未造成伤害时摸两张 |
| `packages/hegemony/pkg/formation/skills/shoucheng.lua` | 上游只摸一张且不限次；汉晋每回合每名角色限一次，摸两张后弃一张 |
| `packages/hegemony/pkg/mobile_heg/skills/chuanxin.lua` | 实为伤害后弃牌／乘势移将，不是汉晋穿心的伤害前翼从分支 |
| `packages/hegemony/pkg/momentum/skills/hongfa.lua` | 旗来源结构与派生入口参考。天兵转化牌名和防止失去体力的适用范围以[汉晋完整旗牌面](../../../rules/generals/em-qun010-zhangjiao.md#旗与专属装备)为准 |
| `packages/hegemony/pkg/momentum/skills/yingyang.lua` | `PindianCardsDisplayed`与`changePindianNumber`，主要效果可适配 |

虎翼、鹤翼、天覆、鸟翔、锥形、龙飞均须核对阵法及所属将牌。明暗置、失技、死亡、改势力、座次和移出游戏后即时重算状态，只在回合末刷新不足。多来源授予不能用全局删除同名技能误伤独立来源。摧破、激昂、剽戮等按实际逐目标时机，不能无依据增加firstTarget条件。

### 用牌与延时效果

已核对`ltk/server/room.lua`：`askToUseCard`返回待执行`UseCardDataSpec`，`askToResponse`返回待执行`RespondCardDataSpec`。`ltk/core/events/misc.lua`中的请求数据含`user`、`pattern`、`eventData`和`result`。屏御须保持原闪请求与多闪语境，完成郭淮打出、请求者使用的归属，不把普通虚拟闪结果当成已经执行。

原始`Room:askToUseVirtualCard`可由skip控制执行；项目`pkg/qiao_mode/rules/card_use_targets.lua`的封装契约为：`selectVirtualCard`只选择复核，`askToUseVirtualCard`选择并执行一次。交回引擎的数据用选择接口，不得重复使用已执行返回值，详见[公共入口](../card-use-targets.md)。

用良按明示目标策略；挑衅最多两名角色分别追踪真实用杀伤害；虎翼是技能回合限一次；尚义含响应后入口，须同时考虑使用型响应与打出型响应。锋械按各一张确定牌交换经处理区入对方手牌，再按单人／队列目标组接杀，不只提高普通杀目标上限。

`ltk/core/events/hp.lua`的`PreHpRecover`可用于蛊毒防止整次回复；`ltk/core/events/movecard.lua`的`BeforeDrawCard`对应恂恂首次摸牌前，不能只接摸牌阶段。忘隙按伤害事件，横江按每点伤害，两者计次不同；疲攻含使用及打出基本牌。

疑城是使用装备／回合末弃1二选一；守成每回合每名角色一次摸2弃1；存嗣按轮分别记录回合内杀及回合外桃。横江在弃牌阶段结束检查，蛊毒在回合结束结算，破军的牌返还晚于角色移回。已建立效果按公共分类处理，不能一概要求技能仍在。

守成回归固定从牌堆顶摸到【敕令】，在弃置完成时验证该牌进入弃牌堆，并在回合结束后验证它因全场势力已确定而移出游戏。旧用例在回合末仍要求随机弃置的牌留在弃牌堆，遇到【敕令】会误报。参见 [`shu018b_feiyi.lua`](../../../../tests/shu018b_feiyi.lua) 与[敕令结算](../../../rules/card-deck.md#普通锦囊与装备的审阅结论)。

### 武将位置与牌类别

`H.removeGeneral(player,isDeputy)`默认主将；`H.transformGeneral(room,player,isMain,isHidden,num,generals)`的位置参数含义相反，默认候选数为1。原始变更遇暗将会先revealGeneral，与汉晋暗将无须验明、不触发明置后存在差异，须适配。

位置与牌类别的合法性必须在调用前区分：

- 变更主将／副将／武将是位置操作，允许位置上的普通士兵、翼从、偏将被变更。
- 明确要求变更或移除武将牌，必须实际存在武将牌，士兵不能代替。
- 穿心明确要求副将武将牌；其为士兵时仍可发动穿心，但直接执行否则分支：伤害+1，张任本局拥有所选翼从。不得调用宽泛的位置变更把士兵变更为翼从后判作成功。
- 勇决、蛊毒锚定此武将牌，交换后不得误操作原位置的新牌；移除将牌和变更位置的事件分别走公共流程。

详见[公共定义](../../../rules/general-principles.md#武将位置武将牌与士兵牌)。客户端合法性须只读公开位置与类别，不依赖服务端私有暗将字段；服务端执行前复核。

`pkg/qiao_mode/rules/commander_retinue.lua`已有assignRetinue、convertPosition及来源登记，主要服务实体士兵转换。穿心额外拥有和龙飞共享不能冒充普通统领来源，接入时按独立实例计数和授技，普通翼从无限供应，不以同名技能ID合并来源。

### 复用、应变与关联内容

项目同文入口位于`pkg/qiao_generals/skills/`：马术`skill_shu006_1.lua`、观星`skill_shu004_1.lua`、英魂`skill_wu009_1.lua`、英姿`skill_wu005_1.lua`、仁德`skill_shu001_1.lua`。观星正文与实现已读，其卜算数目前写在技能内，承志按主将印刷或后天观星来源接入数值；其他条目核对了文件和技能身份，未重审全部既有效果。

已核对`pkg/qiao_mode/rules/adaptation.lua`的setCardEntries、addEntry、isAdaptationCard。烈戎、勤边、献捷须赋完整应变条目；总戎是状态型无次数限制，正常计实际使用，不当成应变ignore_times。遄征为限定技，改本回合击杀奖惩而不只下一次，所获献捷未限本回合。

关联内容：八阵兵由姜维与马隆提供，轮次视为使用调虎离山并为该次结算提供杀当无懈；青州精锐由臧霸提供，统领牌为雷杀；庐江上甲由陈武董袭提供，实际弃牌才增加阶段杀次数；君张角提供黄巾雷使与铁索连环，复用现有同文翼从技能。各兵种技能正文见逐将页，统领能力不与翼从效果混用。

六师率义旗按来源两牌换一项场上没有的指定技能。黄巾天兵符按完整旗牌面处理补天兵、群人数修正、群角色以旗上天兵转化正式雷【杀】，以及持旗者支付天兵防止一次失去体力。旗与天兵候选只读取公开信息，使用和打出的天兵作为实体子牌交给引擎移动，防止失去体力时则主动移出旗牌堆。两条路径的实际移动均由悟心监听。飞龙夺凤、太平要术按独立汉晋牌名接线，目标效果见[汉晋版卡牌规则](../../../rules/card-deck.md#6-卡牌版本与结算)。

### 已验证武将

24张普通武将及两张君主均已正式登记，57条印刷技能已有实现；三种新翼从和五条统领来源另行登记。各将及关联内容已有分批定向运行结果。关联统领、所授技能和复杂入口的覆盖范围须分别核对，不以武将登记代替全部验证。

- 屏御复用锁定引擎 `standard/pkg/skills/hujia.lua` 的材料生命周期：郭淮 `RespondCard(skipDrop=true)`，再以处理区材料构造请求者的闪。实体牌材料使用 `Card:getIdList`，不能用空 `subcards` 判断无实体牌。
- 尚义分别监听 `CardUseFinished`、`CardRespondFinished`，真实响应后让原牌使用者先看蒋钦手牌。随后蒋钦在[同一私密面板](../skill-ui.md#私看手牌并操作其中的牌)观看对方手牌并选择弃牌，黑桃、梅花各至多一张。
- 鹤翼为每名角色分配本局固定的预注册派生技能槽位。角色 ID 可为负数，换座也不改变已分配槽位。客户端从公开层数标记读距离层数，移除来源时保留其他鹤翼和独立飞影。[#25 日志截图](https://github.com/user-attachments/assets/6b90c036-cf2f-4469-9b69-64ef49f829ac)
- 翼从实例模块分别保存实体、授予、共享来源及独立次数；交换迁移实体实例，龙飞共享须避免递归。
- 承志撤回自身派生观星后，若明置主将仍提供印刷或附着观星，恢复对应主将来源；变更主将时不能因同名派生技能尚在而漏装主将技能。该流程由实际变更主将并卜算7张的用例回归。
- 于吉改编锁定 `hegemony/pkg/formation/skills/qianhuan.lua` 的收牌与取消目标入口，不限制花色，上限取体力上限，不采用上游额外的判定区移入拦截。

## 验证依据

定向命令统一为 `python scripts/test.py --file tests/<文件>.lua`。以下为分批实际通过结果。测试清空生产监听器、腹心死士闭包声明顺序及承志同名来源遮蔽问题均已修复；正式登记用例明确启用六势力，暴凌验证旧将牌移除而不强制留下普通士兵。

| 范围 | 结果 |
| --- | --- |
| 李典、费祎、马岱 | 5/5、4/4、4/4 |
| 孙策、陈武董袭 | 4/4、4/4 |
| 徐荣、董卓 | 3/3、5/5 |
| 朱儁、卢植、吉平、刘虞 | 3/3、5/5、6/6、3/3 |
| 曹洪、蒋钦 | 5/5、4/4 |
| 杜预、牵弘、郭淮、糜夫人 | 5/5、3/3、5/5、4/4 |
| `retinue_instances`、`zhen_shi_retinues` | 6/6、6/6 |
| `retinue_instance_sources`、`retinue_multi_instance_triggers` | 7/7、1/1 |
| 王浑、马隆、于吉、张任、臧霸 | 2/2、4/4、2/2、4/4、1/1 |
| 徐盛、姜维、君刘备、君张角 | 2/2、5/5、4/4、4/4 |
| 君孙权 | 7/7（正式普通孙权升变、旗入口与烽火范围、嘉禾失效撤回、8人局角色数门槛、聚宝任意宝物移动区别） |
| 君曹操 | 15/15（升变、建安十项授技开放与一次结算、限制与到期、独立来源、挥鞭、总御正常/占栏；常令两分支、奇策实际转化与一材料双目标拒绝、胆戾两分支、公共变更副将入口与建安锁定拒绝） |
| 八阵兵 | 4/4（含真实杀当无懈请求） |
| `general_card_skills` | 7/7（含后天牌技失去后不因明置恢复） |
| 并州／锦帆复杂多实例 | 4/4 |
| 标准将登记、模式规则 | 12/12、10/10（糜夫人接入后） |
| 统领公共规则、武将交换 | 57/57、17/17（翼从实例来源接入时） |

王浑总戎的距离和次数回调都传入实际状态技能效果检查用牌者的持有与有效性，次数回调含引擎要求的 `scope`。王浑专项 3/3 覆盖同场非持有者、持有者失效及普通、火、冰【杀】的客户端出牌目标筛选。

牵弘用例执行真实火杀，但目标选择数据由测试构造，勤边完整主流程与复杂助战边界尚未验收。屏御已验证真实杀闪请求与材料移入弃牌堆，尚未单独验收多闪及客户端交互。激昂按[汉晋转化牌定义](../../../../rulebook/terms/description-terms/transform.md)判断：`card:isVirtual()` 且 `subcards` 非空。无材料构造牌及直接使用的实体牌不进入摸两张并失效的分支；另行弃置的技能消耗不算材料。

最终默认验收：本轮执行 `python scripts/test.py --timeout 480`，979/979通过、0失败、退出码0（280.927秒）；输出保存于 `.dev/ascension-fix-full.log`。无critical或Lua回溯，原生Distance malfunction警告仍出现。Lua语法检查通过，`git diff --check`通过。

## 未完成与边界

武将、君主、旗、新翼从及统领已接入，既有翼从已适配同名多实例。武将牌后天获得技能按汉晋原创规则记录在该牌上，承志按实际主将牌来源判断。`general_card_skills` 定向7/7通过，覆盖预亮发动明置、暗置停止生效、交换、移除、失去及外部独立来源保留；并州／锦帆复杂多实例4/4通过。

修体、武库按逐将页暂行口径实施。具体规则见[阵势包索引](../../../rules/zhen-shi-generals.md#实装约束)。

君主升变技能同步补充：公共 `GeneralCardState.clearLeavingCardState` 只清理指定离牌位置的 fake/prelight，升变与穿心共用；保留另一暗将同名合法来源和角色独立实际来源。弘法、章武改用国战君主来源获取，不再依赖身份模式 `Skill.Lord`。真实张角+暗貂蝉、暗副将同名来源和刘备升变已加入 `tests/second_lord.lua`，该套 33/33；`qun024_zhangren` 4/4，两个君主将套件各 4/4。君孙权使用同一公共升变入口：嘉禾授予缘江烽火图，旗入口覆盖当前吴势力角色（含本人），烽火数动态修正持旗者攻击范围；失去嘉禾后旗来源、入口与范围加成一并撤回。敛资的 X（吴势力攻击范围并集）只决定亮牌数，转换门槛按场上存活、未移除角色数判断；聚宝保护范围为任意宝物牌而非仅定澜夜明珠。`tests/em_wu001_sunquan.lua` 7/7。

挑衅 AI 请求修复：`C.askToUseCard` 的 `names/card_name/name` 是策略白名单，不再作为引擎 pattern 直接删除；公共转发从卡名派生 `trueName` pattern（`qiao__slash` → `slash`）。挑衅真实走 `Room:askToUseCard` 请求，AI 不再收到 nil pattern；选择端用锁定引擎的 `extra_data.exclusive_targets` 限定姜维，服务端保留 `fixed_targets` 复核。`tests/card_use_targets.lua` 36/36（含 `card_name` 别名、固定目标拒绝和 exclusive_targets 观察）、`tests/shu012_jiangwei.lua` 6/6（含取消后实际弃牌）。全库扫描中已有显式 pattern 或由上层生成请求参数的分支保留；未发现其他无证据需改的直接调用。首次全量982项981成功，唯一失败为 `shu021_mifuren`；该套记录初始珠联标记（样本 before=0/after=1）并按 before+1 修正断言，单跑4/4。两项修复后最终全量982/982通过。

2026-11-17 四君主增量验收：君孙权 7/7、君曹操 15/15、君司马炎 6/6、君刘协 7/7、双坐骑 3/3；该批默认套件 1020/1020 通过。该批的诏书验证覆盖势力锦囊的取得和使用记录，牌面效果由[后续批次](../card-deck.md#势力锦囊)接入。最新全量与人工验收范围见[开发状态](../../status.md#当前验收基线)。
