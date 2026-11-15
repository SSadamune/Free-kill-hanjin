# 晋势力标准包：逐将检索与验证入口

本页覆盖晋标准包15将、29条天生技能记录及腹心死士、文虎两种翼从，均已有正式实现。应期直接引用 WEI002 的同一技能 ID；其余技能按以下主记录检索，不重复正文。泰然后续时机尚未定案，当前按用户暂行指示在回合结束时逐次结算。规则依据见逐将页，当前验证与人工边界见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| JIN001 | 司马炎 | [垂统](support.md#jin001-1)、[兴图](conversion.md#jin001-2) |
| JIN002 | 司马师 | [泰然](support.md#jin002-1)、[夷灭](damage.md#jin002-2) |
| JIN003 | 司马昭 | [昭然](support.md#jin003-1)、[挟征](active.md#jin003-2) |
| JIN004 | 贾充 | [通法](support.md#jin004-1)、[悖弑](damage.md#jin004-2) |
| JIN005 | 羊祜 | [柔克](conversion.md#jin005-1)、[顺流](damage.md#jin005-2) |
| JIN007 | 王元姬 | [识人](support.md#jin007-1)、[恤下](support.md#jin007-2) |
| JIN008 | 夏侯徽 | [宜室](support.md#jin008-1)、[识度](pindian.md#jin008-2) |
| JIN009 | 司马懿 | [权变](support.md#jin009-1)、[骤霆](conversion.md#jin009-2)、[应期](pair-hp.md#wei002-3) |
| JIN010 | 张春华 | [伤逝](conversion.md#jin010-1)、[扼绝](damage.md#jin010-2) |
| JIN011 | 张虎&乐綝 | [果毅](support.md#jin011-1) |
| JIN012 | 羊徽瑜 | [慈威](active.md#jin012-1)、[弘训](support.md#jin012-2) |
| JIN013 | 王濬 | [乘流](damage.md#jin013-1)、[克清](active.md#jin013-2) |
| JIN014 | 文鸯 | [膂力](support.md#jin014-1)、[夺气](phases.md#jin014-2) |
| JIN015 | 石苞 | [前驱](active.md#jin015-1) |
| JIN016 | 张华 | [复礼](support.md#jin016-1)、[风物](support.md#jin016-2) |

运行时武将 ID 为 `hanjin__jin编号`；除应期外，各技能源码为 `pkg/hanjin_generals/skills/skill_jin编号_顺序.lua`。应期仍为 `hanjin__skill_wei002_3`，不新增晋副本。

## 2. 关联翼从

[腹心死士](retinues.md#fuxin-sishi)、[文虎](retinues.md#wenhu)均已实现。三项统领能力沿用[公共机制](../commander-retinue.md)：JIN002 红桃出其不意附助战条目，JIN009 调虎离山，JIN014 限一冰杀；翼从取得和限一统领能力的计数分别处理。

<details>
<summary>2026-11-15 实装前审阅快照（保留依据，不代表当前完成度）</summary>

## 2026-11-15 晋标准包规则与实现路径审阅

范围为 JIN001、002、003、004、005、007、008、009、010、011、012、013、014、015、016，共 15 将、29 条天生技能记录及腹心死士、文虎两种关联翼从。仅司马炎两技和直接复用 WEI002 的应期已有正式效果，其余 26 条及两翼从为空壳；此为已有开发边界，不作为新发现的实现故障。没有把君主或晋魏等其他版本纳入。

本轮只维护审阅文档；未修改技能、牌面数据或测试逻辑，未运行游戏测试、未构建安装包。先前通过数仍仅代表对应历史代码及范围。

### 逐将规则入口

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| JIN001 | 司马炎 | [垂统、兴图既有约定](../../../../rules/generals/jin001-simayan.md) |
| JIN002 | 司马师 | [泰然、夷灭；腹心死士](../../../../rules/generals/jin002-simashi.md) |
| JIN003 | 司马昭 | [昭然、挟征](../../../../rules/generals/jin003-simazhao.md) |
| JIN004 | 贾充 | [通法、悖弑](../../../../rules/generals/jin004-jiachong.md) |
| JIN005 | 羊祜 | [柔克、顺流](../../../../rules/generals/jin005-yanghu.md) |
| JIN007 | 王元姬 | [识人、恤下](../../../../rules/generals/jin007-wangyuanji.md) |
| JIN008 | 夏侯徽 | [宜室、识度](../../../../rules/generals/jin008-xiahouhui.md) |
| JIN009 | 司马懿 | [权变、骤霆、应期](../../../../rules/generals/jin009-simayi.md) |
| JIN010 | 张春华 | [伤逝、扼绝](../../../../rules/generals/jin010-zhangchunhua.md) |
| JIN011 | 张虎&乐綝 | [果毅](../../../../rules/generals/jin011-zhanghu-yuechen.md) |
| JIN012 | 羊徽瑜 | [慈威、弘训](../../../../rules/generals/jin012-yanghuiyu.md) |
| JIN013 | 王濬 | [乘流、克清](../../../../rules/generals/jin013-wangjun.md) |
| JIN014 | 文鸯 | [膂力、夺气；文虎](../../../../rules/generals/jin014-wenyang.md) |
| JIN015 | 石苞 | [前驱](../../../../rules/generals/jin015-shibao.md) |
| JIN016 | 张华 | [复礼、风物](../../../../rules/generals/jin016-zhanghua.md) |

### 实质发现与来源边界

- **需修正的登记**：`pkg/hanjin_generals/data/standard.lua` 的 JIN003 `companions` 为空；标准表及 JSON `zhulian_ke` 均有 JIN002，当前 `init.lua` 只把该空表加载并自校验，不能检查出来源漏项。影响真实珠联璧合组合。
- **需修正的文本**：JIN007 恤下运行时写“交给其两张牌并摸两张牌”，来源是“交给其两张牌，然后摸两张牌”。不应将顺序和连接关系改写。JIN003 昭然亦有“此阶段内／省略你”的非逐字改写，应恢复来源；JIN005 顺流体力括注是旧解释，采用现有已确认配将修正规则，保持 `deputyHpAdjust = -1`。尖括号样式差异另与语义差异区分，不作为新增效果。
- **次要展示差异**：JIN002、003、008、009、010、011、014 的运行时称号均只保留来源首项，漏第二项；另有繁简字差异。标准表已保留完整来源，不应从 CSV 的其他称号补写替换。属于数据展示待修正，不与技能效果缺失混为一项故障。
- **版本差异**：泰然 JSON 写结束阶段、CSV 写回合结束时；用户于 2026-11-15 明确时机尚未定案，**暂按回合结束时**（对应规则集回合结束前），标准表及逐将约定已标明暂行性质，不能把暂行口径写成最终裁定。当前运行时 `data/standard.lua` 仍显示旧“结束阶段”，后续实装须同步修正。骤霆仍采用标准表／JSON 的亮出与角色数上限，不采用 CSV 无该上限的版本；外部资料保留原样。
- **三项已回复**：泰然后续在回合结束时暂按每次发动记录分别结算；柔克必须实际改为冰杀才有未造成伤害后的横置／重置机会；顺流受伤者通常已在扣减体力流程中重置，若造成属性伤害后仍横置，则在受伤者部分与横置角色部分各弃一张。具体依据见对应逐将页；前两项涉及的时机映射与“然后”依赖关系已写入[公共约定](../../../../rules/general-principles.md#易读描述的时机与然后)，柔克与顺流的问题已闭合，泰然的具体后续时机仍待定，暂行执行方式已有明确指示。

### 已核对的实现接口与复用路径

基准为 `dependencies.lock.json` 的引擎 0.5.25、hegemony `e8d93ac`、utility `b14e45d`。以下为本次实际读取的源码与拟议接入点，不声称新技能已经验证。

- `.dev/runtime/FreeKill-release/ltk/server/room.lua`：`askToUseCard` 返回待执行数据；`askToUseRealCard` 默认已执行，`skip=true` 才只选择；`askToUseActiveSkill` 默认执行主动技的 `onUse`。悖弑、骤霆、风物等必须选定一种执行契约，不能拿返回值再重复用一次。骤霆额外开放处理区顶牌，通过 `expand_pile` 等正式参数授权，不先放手牌。
- 同文件 `askToGuanxing` 默认完成置顶／置底，返回 `top`、`bottom`；权变可复用项目 `skill_shu004_1.lua` 的观星交互，不重写牌堆排序。
- `.dev/runtime/FreeKill-release/ltk/core/events/usecard.lua`：`UseCardData:isUsingHandcard()` 读取素材来源；`changeCard()` 保留使用身份、实体材料等；`damageDealt` 为角色对象键。权变、柔克及用牌后伤害关联均据此适配，不能用已经离开手牌的实时牌区或角色 ID 键误读。
- `pkg/hanjin_mode/rules/adaptation.lua`：`addEntry`、`grantIgnore`、`registerEffect`；通法复用一令牌一条件，乘流和前驱需新增雷电属性／弃装备效果处理，再通过统一 prepare／resolve 时点执行。现有 effect 表没有这两个专属效果，仅登记卡面不构成实现。
- `retinue_skill_xiyuanjun.lua` 的正式 `visibility`／`prohibit` 接线可供昭然、复礼参考；昭然公开范围须随手牌流动变化，复礼是花色禁用／禁打出，不能误改为仅锁定被展示的一张牌。
- `skill_qun012_2.lua` 及其 `qun_duanchang` 来源维护可供扼绝核对，但断肠是整张将牌失技，扼绝须选择并失去一个技能，不能直接调用整将删除。须区分将牌上的技能与非将牌技能：前者按将牌及技能保存失去状态并接入交换来源过滤，后者依实际授予来源处理、不随将牌转移。现有断肠模块提供整将失技的参考，但不表示扼绝的单技能失去与非将牌来源已接入或验证。
- `commander_retinue.lua` 已登记 JIN002 的红桃与助战条目、JIN009 的调虎离山及文鸯的限一来源；复用公共能力，新增翼从专属效果，不另造移将、选兵种、限一计数。

### 实装与核心验收方向（尚未执行）

先处理资料差异；常规伤害／摸牌／拼点技能可合批。昭然公开手牌、识人隐藏选牌与声明、骤霆处理区强制连续用牌分别先打通一个真实入口再扩展。通法、乘流、前驱先核对公共应变接线，再按专属效果接入。泰然按用户暂定的逐次结算处理，柔克与顺流依本轮已回复结论接线。

核心关注：真实支付与来源明置；阶段／回合首次事实不因晚取得技能重置；连续用牌每张执行一次；本次使用伤害关联；应变逐项与一令牌一条件；文虎区域计数及两个限一记录独立。既有司马炎、应期与公共机制覆盖可复用，不把整份规则场景当作新增测试配额。全部新效果稳定后再跑默认全量与安装包检查。

本轮静态核验：程序读取 JSON 与运行时晋区数据，确认 15 将共 29 条技能记录、28 个晋专属技能骨架中 26 个没有 `addEffect`（应期另复用魏技能）；检查本轮 17 个新增／修改 Markdown 文件的本地链接路径，未发现断链；`git diff --check` 通过。这些检查不验证未实现技能的游戏效果。

</details>

## 3. 接线

晋新增技能及两翼从均在骨架上设置 `hanjinImplemented = true`，加载断言核对实际 effect。既有司马炎保留白名单；应期共用魏技能。

`mode.lua` 正式注册 `hanjin__jin_resources_rule`（泰然及限定技事实）、`hanjin__jin_deck_rule`（权变已建立禁用）、`hanjin__jin_information_rule`（昭然持续可见）、`hanjin__jin_adaptation_rule`（本次用牌雷伤）、`hanjin__jin_sources_rule`（复礼承诺与花色禁用）。柔克、克清的持续监听按需安装在房间中；扼绝复用单技能失去入口及交换来源过滤，保留将牌失技状态。正式卡包依锁定应变参考登记冰伤属性，真实冰伤重置有定向回归。

默认 `tests/all.lua` 接入八套新增晋专项：`jin_basic`、`jin_resources`、`jin_deck`、`jin_information`、`jin_reactive`、`jin_adaptation`、`jin_chain`、`jin_sources`。原 `jin001_simayan` 与 `wei_pair_hp` 覆盖继续复用。

## 4. 验证

2026-11-16 新增八套定向共65项通过（basic19、resources15、deck3、information2、reactive6、adaptation5、chain6、sources9）。资源及反制最终修复由 Codex 执行，其余由 DSH 执行；具体命令、时间与复用回归见[晋共享证据](verification-evidence.md#jin-standard)。最终默认831/831（158.697秒）通过，安装包477文件逐字节一致；不得以本段定向结果推定客户端点击、联网／重连或干净本体安装人工验收。

### 司马炎既有专项与历史验证

常规专项验收入口：

```text
python scripts/test.py --file tests/jin001_simayan.lua --timeout 120
```

最近一次由 DSH 直接通过同一 runtime 的 `FreeKill.exe --testfile` 执行专项（当时用户正在运行游戏，未重复同步运行环境），原记录为 `Ran 17 tests ... 17 successes, 0 failures`（原文省略运行时间）。覆盖垂统的濒死移装与各类不移动边界、兴图的应变牌事实／回合清空／两项执行／主副将与暗置来源，以及真实 `ClientPlayer` 请求处理器中装备牌／非装备牌与目标的可选性。默认全量套件通过 507/507（该批次）；安装包已构建。原始执行记录见[共享验证证据](verification-evidence.md#jin001_simayan)。

## 5. 未完成与边界

未应用开发适配的本体人工交互验收尚未执行。全局记录以使用牌事件为准，未覆盖“无任何目标但被使用”的边缘牌型，后续如出现具体用例再补。用户曾报告“应变牌后的下一回合，敌方普通杀→八卦阵视为闪，兴图误触发”，自动化未能复现；真实连续回合回归及虚拟闪无应变条目检查通过，2026-11-13 用户复测确认已无异常，该反馈关闭，不据此追认具体根因，也未保留无复现依据的回合序号补丁。用户同时确认当轮界面调整无异常；该复测不代表完整联网、重连或未应用开发适配的独立本体验收。

### 规范化描述待办

<a id="jin001-todo"></a>

- [ ] 编写垂统、兴图各自的规范化描述，使用规则集定义的术语与结构，精确表达时机、条件、消耗和效果，并核对项目已确认裁定与实际代码。
- [ ] 将审定后的规范化描述纳入《汉晋规则集》对应武将资料；保留面向玩家的卡面描述。本页的实现说明及 `rules/generals/jin001-simayan.md` 的结算约定均不替代规范化描述，未决裁定须明确标注。
