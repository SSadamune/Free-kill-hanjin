# 共享验证证据

本附录按测试文件保存历史验证结果，供各武将与翼从条目引用。各结果适用于所标明的批次与覆盖范围；最新完成度见[开发状态](../../status.md)。

## 汉区

<a id="han-historical-wiring"></a>

### 汉区历史接线修订

- 本批行为修正（实质问题，不增加测试量）：求援的优先目标和本次发动记录改挂 `UseCardData` 字段，避免 `extra_data` 在目标事件结束时被 AimData 旧值覆盖；谋溃的本次发动与反弃绑定改挂 `UseCardData` 字段，修复双选后抵消不触发反弃；劲弩实际使用也带 `bypass_times`，修复本阶段已出过【杀】时目标组合校验误挡技能视为使用的【杀】；西园军测试改为在出牌阶段内部 probe 公开／锁定／转化禁用与受伤取牌，再在 TurnEnd 后断言 `-turn` 清理，未放宽生产清理。

<a id="汉区"></a>

共享文件 [han_standard.lua](../../../../tests/han_standard.lua) 覆盖汉区 25 技能中无独立专项的条目（诗怨、毒逝、集兵等），已纳入默认国战套件。汉区各专项的最终集成复核记录为“564/564 通过”，随后含滔乱每回合一次回归的默认全量为：

```text
python scripts/test.py --timeout 300
Ran 567 tests in 87.485 seconds, 567 successes, 0 failures
```

汉区定向与默认结果按文件保留在下列条目。

<a id="han004_zhangrang"></a>
### han004_zhangrang.lua

```text
python scripts/test.py --file tests/han004_zhangrang.lua --timeout 120
Ran 4 tests in 0.981 seconds, 4 successes, 0 failures
```

2026-11-13：同一命令在临时还原旧“按发动次数循环 settle”实现时失败于 `expected: 1, actual: 2`（收牌询问两次），确认新用例能区分新旧行为；恢复修复实现后复跑通过。默认全量 567/567 含同回合多次发动、回合末只结算一次的回归。

<a id="han005_hejin"></a>
### han005_hejin.lua

原文记录为“3 项通过”，未保存完整控制台输出；同轮 `han004_zhangrang.lua` 亦为 3/3。旧记录同时给出定向命令 `python scripts/test.py --file tests/han005_hejin.lua --timeout 120`，此处只按原文保留事实性描述，不补造控制台格式输出。

<a id="han007_wangrong"></a>
### han007_wangrong.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han008_fuhuanghou"></a>
### han008_fuhuanghou.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han009_fuwan"></a>
### han009_fuwan.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han012_caiyong"></a>
### han012_caiyong.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han016_liuchong"></a>
### han016_liuchong.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han017_liuyao"></a>
### han017_liuyao.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han_retinues"></a>
### han_retinues.lua

2026-11-13 汉区集成复核已覆盖本套件（默认全量 564/564 通过）；未保存独立定向运行输出。

<a id="han-run-summary"></a>
### 汉区汇总

- 最新代码验证已包含鏖战杀／闪选择修复及滔乱每回合一次的裁定：同一角色同回合多次发动滔乱，回合末后续效果只结算一次，候选取本回合指定目标并集。
- 汉区各专项最终集成复核为 564/564 通过；含滔乱每回合一次回归的默认全量为 567/567。旧记录保存的默认全量命令与结果：

```text
python scripts/test.py --timeout 120
Ran 567 tests in 83.184 seconds, 567 successes, 0 failures
```

各文件输出与日期见[共享验证证据](verification-evidence.md#汉区)。
- 滔乱专项最近一次定向验证为 4 项全部通过，包含同回合两次发动仅一次后续结算及候选合并；`han005_hejin.lua` 3/3。其余武将测试入口见上表，均由默认全量覆盖。
- 安装包已检查包含 `qiao/pkg/qiao_generals/skills/`、`util/`、`data/standard.lua`、`pkg/qiao_mode/client.lua` 与根 `qiao/init.lua`，不包含 `tests/` 或 `scripts/`。
- 不以服务端自动化通过等同于客户端人工验收完成。

<a id="han-standard-boundary"></a>

## 魏区

<a id="wei-historical-wiring"></a>

### 魏区历史接线修订

- 本批实质修正：伪溃私看由全体展示 `room:showCards(hand, player)` 改为真实私看 `room:viewCards(player, { cards = hand, skill_name = ..., prompt = ... })`，测试记录收件角色与牌集；长驱不再使用私有 `room:getTag`，新增公开事实层（`qiao_wei_damage_targets`）与模式级 `fk.Damage` 记录器，客户端与服务端读同一公开数据；伪溃 `can_use` 要求 `player.hp >= 1`，强袭要求体力至少 1 或拥有可弃武器牌（失去体力消耗不得超过当前体力，不把有可弃武器的强袭一并限制为体力至少 1）；驱虎 `winner ~= player`（含平局／空结果）走真实视为【杀】分支；鹰视新增 `skill_wei002_2.lua`。

<a id="魏区"></a>

<a id="wei_damage"></a>
### wei_damage.lua

```text
python scripts/test.py --file tests/wei_damage.lua --timeout 180
Ran 8 tests in 1.923 seconds, 8 successes, 0 failures
```

`initializeGenerals` 同步采用标记后重算 `maxHp/hp` 的夹具修正，避免同一随机初始双将问题影响行殇／节命等用例。

<a id="wei_support"></a>
### wei_support.lua

```text
python scripts/test.py --file tests/wei_support.lua --timeout 180
Ran 3 tests in 0.787 seconds, 3 successes, 0 failures
```

旧记录同时保存了 `python scripts/test.py --file tests/wei_support.lua --timeout 120` 与 `python scripts/test.py --file tests/wei_damage.lua --timeout 120` 两个执行入口。持重间歇失败根因见[持重夹具根因](#持重夹具根因)。放逐用例曾因施放者连续承受三次 1 点伤害进入濒死导致一次 `faceup` 断言失败，已固定施放者体力为 10。

<a id="wei_phases"></a>
### wei_phases.lua

```text
python scripts/test.py --file tests/wei_phases.lua --timeout 180
Ran 14 tests in 3.281 seconds, 14 successes, 0 failures
OK
```

设变、巧变 90 秒超时根因见[设变巧变超时根因](#设变巧变超时根因)。

<a id="wei_active"></a>
### wei_active.lua

```text
python scripts/test.py --file tests/wei_active.lua --timeout 180
Ran 6 tests in 1.418 seconds, 6 successes, 0 failures
```

2026-11-14 连续 4 次运行均为 6/6：1.418、1.424、1.413、1.416 秒。同轮 [wei_retrial.lua](../../../../tests/wei_retrial.lua) 2/2。测试夹具根因见[魏包白板夹具](#魏包白板夹具)。

<a id="wei_retrial"></a>
### wei_retrial.lua

```text
python scripts/test.py --file tests/wei_retrial.lua --timeout 180
Ran 2 tests in 0.202 seconds, 2 successes, 0 failures
```

连续 2 次运行均为 2/2（0.202–0.208 秒）。

<a id="wei_retinues"></a>
### wei_retinues.lua

```text
python scripts/test.py --file tests/wei_retinues.lua --timeout 180
Ran 3 tests in 0.783 seconds, 3 successes, 0 failures
```

牛金奖励根因见[牛金奖励根因](#牛金奖励根因)。

<a id="wei_pair_hp"></a>
### wei_pair_hp.lua

```text
python scripts/test.py --file tests/wei_pair_hp.lua --timeout 120
4/4 通过
```

最终 `python scripts/test.py --timeout 180` 608/608 通过（2026-11-14 DSH 工具原生检查）。

### 魏区默认全量与发布

```text
python scripts/test.py --timeout 180
608 项通过，0 失败，退出码 0

python scripts/build_release.py
Built .dev/dist/qiao.zip，退出码 0
```

## 吴区

<a id="吴区"></a>

<a id="wu_support"></a>
### wu_support.lua

```text
python scripts/test.py --file tests/wu_support.lua --timeout 180
15 项通过、0 失败
```

代表性真实 `ClientPlayer` 用例验证无 `room` 字段下的结姻可用性与直谏候选。

<a id="wu_phases"></a>
### wu_phases.lua

```text
python scripts/test.py --file tests/wu_phases.lua --timeout 180
12 项通过、0 失败
```

测试文件返回套件描述符以隔离内置上游用例；早期误混入的内置失败不作为本组验收证据。

<a id="wu_damage"></a>
### wu_damage.lua

```text
python scripts/test.py --file tests/wu_damage.lua --timeout 180
22 项通过、0 失败
```

包含本组、太史慈与两翼从。

### 吴区默认全量与发布

```text
python scripts/check_lua.py
退出码 0

python scripts/test.py --timeout 180
Ran 657 tests in 107.552 seconds, 657 successes, 0 failures
退出码 0

python scripts/build_release.py
Built .dev/dist/qiao.zip
退出码 0
```

## 晋区

## 2026-11-15 晋标准包规则与实现路径审阅

该节保存实装前的审阅记录。当前状态见[晋势力标准包](jin-standard.md)。

范围为 JIN001、002、003、004、005、007、008、009、010、011、012、013、014、015、016，共 15 将、29 条天生技能记录及腹心死士、文虎两种关联翼从。仅司马炎两技和直接复用 WEI002 的应期已有正式效果，其余 26 条及两翼从为空壳；此为已有开发边界，不作为新发现的实现故障。没有把君主或晋魏等其他版本纳入。

本轮只维护审阅文档；未修改技能、牌面数据或测试逻辑，未运行游戏测试、未构建安装包。先前通过数仍仅代表对应历史代码及范围。

### 逐将规则入口

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| JIN001 | 司马炎 | [垂统、兴图既有约定](../../../rules/generals/jin001-simayan.md) |
| JIN002 | 司马师 | [泰然、夷灭；腹心死士](../../../rules/generals/jin002-simashi.md) |
| JIN003 | 司马昭 | [昭然、挟征](../../../rules/generals/jin003-simazhao.md) |
| JIN004 | 贾充 | [通法、悖弑](../../../rules/generals/jin004-jiachong.md) |
| JIN005 | 羊祜 | [柔克、顺流](../../../rules/generals/jin005-yanghu.md) |
| JIN007 | 王元姬 | [识人、恤下](../../../rules/generals/jin007-wangyuanji.md) |
| JIN008 | 夏侯徽 | [宜室、识度](../../../rules/generals/jin008-xiahouhui.md) |
| JIN009 | 司马懿 | [权变、骤霆、应期](../../../rules/generals/jin009-simayi.md) |
| JIN010 | 张春华 | [伤逝、扼绝](../../../rules/generals/jin010-zhangchunhua.md) |
| JIN011 | 张虎&乐綝 | [果毅](../../../rules/generals/jin011-zhanghu-yuechen.md) |
| JIN012 | 羊徽瑜 | [慈威、弘训](../../../rules/generals/jin012-yanghuiyu.md) |
| JIN013 | 王濬 | [乘流、克清](../../../rules/generals/jin013-wangjun.md) |
| JIN014 | 文鸯 | [膂力、夺气；文虎](../../../rules/generals/jin014-wenyang.md) |
| JIN015 | 石苞 | [前驱](../../../rules/generals/jin015-shibao.md) |
| JIN016 | 张华 | [复礼、风物](../../../rules/generals/jin016-zhanghua.md) |

### 实质发现与来源边界

- **需修正的登记**：`pkg/qiao_generals/data/standard.lua` 的 JIN003 `companions` 为空；标准表及 JSON `zhulian_ke` 均有 JIN002，当前 `init.lua` 只把该空表加载并自校验，不能检查出来源漏项。影响真实珠联璧合组合。
- **需修正的文本**：JIN007 恤下运行时写“交给其两张牌并摸两张牌”，来源是“交给其两张牌，然后摸两张牌”。不应将顺序和连接关系改写。JIN003 昭然亦有“此阶段内／省略你”的非逐字改写，应恢复来源；JIN005 顺流体力括注是旧解释，采用现有已确认配将修正规则，保持 `deputyHpAdjust = -1`。尖括号样式差异另与语义差异区分，不作为新增效果。
- **次要展示差异**：JIN002、003、008、009、010、011、014 的运行时称号均只保留来源首项，漏第二项；另有繁简字差异。标准表已保留完整来源，不应从 CSV 的其他称号补写替换。属于数据展示待修正，不与技能效果缺失混为一项故障。
- **版本差异**：泰然 JSON 写结束阶段、CSV 写回合结束时；用户于 2026-11-15 明确时机尚未定案，**暂按回合结束时**（对应规则集回合结束前），标准表及逐将约定已标明暂行性质，不能把暂行口径写成最终裁定。当前运行时 `data/standard.lua` 仍显示旧“结束阶段”，后续实装须同步修正。骤霆仍采用标准表／JSON 的亮出与角色数上限，不采用 CSV 无该上限的版本；外部资料保留原样。
- **三项已回复**：泰然后续在回合结束时暂按每次发动记录分别结算；柔克必须实际改为冰杀才有未造成伤害后的横置／重置机会；顺流受伤者通常已在扣减体力流程中重置，若造成属性伤害后仍横置，则在受伤者部分与横置角色部分各弃一张。具体依据见对应逐将页；前两项涉及的时机映射与“然后”依赖关系已写入[公共约定](../../../rules/general-principles.md#易读描述的时机与然后)，柔克与顺流的问题已闭合，泰然的具体后续时机仍待定，暂行执行方式已有明确指示。

### 已核对的实现接口与复用路径

基准为 `dependencies.lock.json` 的引擎 0.5.25、hegemony `e8d93ac`、utility `b14e45d`。以下为本次实际读取的源码与拟议接入点，不声称新技能已经验证。

- `.dev/runtime/FreeKill-release/ltk/server/room.lua`：`askToUseCard` 返回待执行数据；`askToUseRealCard` 默认已执行，`skip=true` 才只选择；`askToUseActiveSkill` 默认执行主动技的 `onUse`。悖弑、骤霆、风物等必须选定一种执行契约，不能拿返回值再重复用一次。骤霆额外开放处理区顶牌，通过 `expand_pile` 等正式参数授权，不先放手牌。
- 同文件 `askToGuanxing` 默认完成置顶／置底，返回 `top`、`bottom`；权变可复用项目 `skill_shu004_1.lua` 的观星交互，不重写牌堆排序。
- `.dev/runtime/FreeKill-release/ltk/core/events/usecard.lua`：`UseCardData:isUsingHandcard()` 读取素材来源；`changeCard()` 保留使用身份、实体材料等；`damageDealt` 为角色对象键。权变、柔克及用牌后伤害关联均据此适配，不能用已经离开手牌的实时牌区或角色 ID 键误读。
- `pkg/qiao_mode/rules/adaptation.lua`：`addEntry`、`grantIgnore`、`registerEffect`；通法复用一令牌一条件，乘流和前驱需新增雷电属性／弃装备效果处理，再通过统一 prepare／resolve 时点执行。现有 effect 表没有这两个专属效果，仅登记卡面不构成实现。
- `retinue_skill_xiyuanjun.lua` 的正式 `visibility`／`prohibit` 接线可供昭然、复礼参考；昭然公开范围须随手牌流动变化，复礼是花色禁用／禁打出，不能误改为仅锁定被展示的一张牌。
- `skill_qun012_2.lua` 及其 `qun_duanchang` 来源维护可供扼绝核对，但断肠是整张将牌失技，扼绝须选择并失去一个技能，不能直接调用整将删除。须区分将牌上的技能与非将牌技能：前者按将牌及技能保存失去状态并接入交换来源过滤，后者依实际授予来源处理、不随将牌转移。现有断肠模块提供整将失技的参考，但不表示扼绝的单技能失去与非将牌来源已接入或验证。
- `commander_retinue.lua` 已登记 JIN002 的红桃与助战条目、JIN009 的调虎离山及文鸯的限一来源；复用公共能力，新增翼从专属效果，不另造移将、选兵种、限一计数。

### 实装与核心验收方向（尚未执行）

先处理资料差异；常规伤害／摸牌／拼点技能可合批。昭然公开手牌、识人隐藏选牌与声明、骤霆处理区强制连续用牌分别先打通一个真实入口再扩展。通法、乘流、前驱先核对公共应变接线，再按专属效果接入。泰然按用户暂定的逐次结算处理，柔克与顺流依本轮已回复结论接线。

核心关注：真实支付与来源明置；阶段／回合首次事实不因晚取得技能重置；连续用牌每张执行一次；本次使用伤害关联；应变逐项与一令牌一条件；文虎区域计数及两个限一记录独立。既有司马炎、应期与公共机制覆盖可复用，不把整份规则场景当作新增测试配额。全部新效果稳定后再跑默认全量与安装包检查。

本轮静态核验：程序读取 JSON 与运行时晋区数据，确认 15 将共 29 条技能记录、28 个晋专属技能骨架中 26 个没有 `addEffect`（应期另复用魏技能）；检查本轮 17 个新增／修改 Markdown 文件的本地链接路径，未发现断链；`git diff --check` 通过。这些检查不验证未实现技能的游戏效果。

<a id="jin-standard"></a>
## 晋势力标准包最终验收（2026-11-16）

DSH分批实现，Codex审阅并完成整合修复、串行验收。范围为15将29条天生技能记录及腹心死士、文虎；应期复用魏技能，既有司马炎保留。规则审阅提交 `b28ad21`；本轮实现与验证记录一并提交。泰然后续时机尚未定案，当前暂按回合结束时逐次结算。

```text
python scripts/test.py --timeout 240
Ran 831 tests in 158.697 seconds, 831 successes, 0 failures
exit 0
python scripts/check_lua.py
366 Lua files OK, exit 0
python scripts/build_release.py
Built .dev/dist/qiao.zip
```

八套新增晋专项共65项纳入默认套件，公共转换额外加入暗卧龙回归。默认全量输出 `.dev/logs/jin_full_final.log`；保留原生 Distance malfunction 警告，无critical Lua错误或失败断言。安装包包含五个新增正式模式规则、共享辅助及技能接线，无测试、脚本或本体开发补丁。文档本地链接和差异格式检查通过。

真实客户端点击、多人联网／重连及干净本体安装人工验收未执行；自动化通过不扩展为这些结论。以下保留各专项证据及整合期间发现的问题。

<a id="jin001_simayan"></a>
### jin001_simayan.lua

由 DSH 直接通过同一 runtime 的 `FreeKill.exe --testfile` 执行专项（当时用户正在运行游戏，未重复同步运行环境）；原记录为：

```text
Ran 17 tests ... 17 successes, 0 failures
```

原文省略了运行时间。默认全量 507/507（该批次）；安装包已构建。最近完整验证记录见[开发状态](../../status.md)。

<a id="jin-basic"></a>
### jin_basic.lua

JIN011 果毅、JIN012 慈威/弘训、JIN014 膂力/夺气的定向套件。19/19 通过；膂力在 `fk.Damage`（造成伤害后）读取、两项合法选项的可执行性已修正。该结果不变。

<a id="jin-resources"></a>
### jin_resources.lua

JIN002 泰然/夷灭、JIN007 恤下、JIN008 宜室/识度及腹心死士的定向套件。最新实际执行：15/15（3.686 秒）。恤下真实“0 明置→发动后明置→交给两张→摸两张”现通过。泰然后续仍按暂定 `fk.TurnEnd` 逐条结算，不是最终裁定。

恤下暗将回归故障（仅此一处记录）：触发为真实暗将来源、0 明置时发动恤下；证据为快速 cost 引擎在追加暗将确认请求后未收到回复、后续交给/摸牌断言失败；根因在测试后端的快速 cost 流程，不在恤下效果；由 Codex 修正测试后端补齐暗将确认回复，原技能/效果断言未删；测试入口为 [jin_resources.lua](../../../../tests/jin_resources.lua) 的 `testXuxiaRealDarkSourceIsRegisteredAndTriggers`。

<a id="jin-deck"></a>
### jin_deck.lua

JIN009 权变/骤霆的定向套件。最新实际执行：3/3（0.787 秒）；处理区唯一牌修正已通过，不再以历史 2/2 代表当前状态。

<a id="jin-adaptation"></a>
### jin_adaptation.lua

JIN004 通法、JIN013 乘流、JIN015 前驱的定向套件，5/5 通过；同批公共应变 25/25、`ignore_times` 14/14。该结果属于应变公共机制与本批定向，不挪作其他技能的新增覆盖。

<a id="jin-chain"></a>
### jin_chain.lua

JIN005 柔克/顺流、JIN013 克清、JIN014 文虎及真实冰属性重置的定向套件。2026-11-16 实际执行：

```text
python scripts/test.py --file tests/jin_chain.lua --timeout 180
Ran 6 tests in 1.448 seconds, 6 successes, 0 failures
```

覆盖柔克改冰杀与失技后本次后续、顺流受伤者与横置者弃牌、克清失技持续/来源不再存活、文虎整区一次弃置与决斗目标上限、冰杀伤害重置横置受伤者。冰属性在正式 `pkg/qiao_cards/init.lua` 按锁定参考 `variation_cards/init.lua` 注册（引擎默认 `can_chain = true`），用例用真实冰杀伤害观察重置。克清真实 `killPlayer` 因夹具先触发游戏结束，死亡用例改用真实 `dead` 状态后继续真实用牌；`fk.Death` 清理链路仍待独立夹具或人工复核，客户端/联网重连未验。

<a id="jin-information"></a>
### jin_information.lua

JIN003 昭然、JIN007 识人的定向套件。DSH 首次定向 2/2（0.511 秒）通过；可见性兼容修复后由 Codex 复核 2/2（0.513 秒）通过。

<a id="jin-reactive"></a>
### jin_reactive.lua

JIN003 挟征、JIN004 悖弑的定向套件。最新实际执行：6/6（1.465 秒）通过。挟征已改为 `C.explicit({ other_roles = true })`、移除默认攻击距离并固定实际目标；悖弑改为本次 `use.extra_data` token `{ actor, source, damaged }`，核对 `data.card == use.card`，只记录对原来源的伤害，并新增远距离反制、原来源/非原来源分支。

<a id="jin-sources"></a>
### jin_sources.lua

JIN010 扼绝/伤逝、JIN016 复礼/风物的定向套件。扼绝已用真实 `Exchange.exchange` 验证保留失技及外部来源不随牌移动；风物已用真实 `ClientPlayer` 与四花色验证；复礼的独立 `jin_sources_rule` 已正式 mode 接线。Issue #32 后定向 11/11（5.889 秒）。伤逝覆盖结束阶段选择、拒绝零材料、潜袭禁止手牌材料，以及以合法材料实际使用冰【杀】。

### 晋包整合中的可见性与响应夹具修正

昭然的技能及模式级 `visibility.card_visible` 原先在不适用时返回 `false`，使西园军原有公开效果被覆盖。首次默认套件虽汇总830项成功，仍在 `han_retinues.lua:128` 的回调内报告 critical 断言，测试入口按要求返回失败；不能仅凭汇总判通过。改为仅对昭然有效手牌返回 `true`，其余返回 `nil`，让其他可见性来源继续判断。修复后 `han_retinues` 2/2（0.508秒）及 `jin_information` 2/2（0.513秒）通过。

随后全量为829/830，`only_as` 的直接打出回复返回 nil。原套件使用随机真实双将；固定暗卧龙、黑色判定牌与同一回复可确定性重现：八阵先询问并消费给响应窗口的回复，最终响应为 nil。原失败没有记录初始双将，不追认此为当次唯一根因。公共套件改为固定多势力白板双将，并显式添加暗卧龙先放弃八阵再桃当闪打出的回归；来源无效化查询放在真实房间上下文内。`python scripts/test.py --file tests/only_as.lua --timeout 120` 为25/25（5.757秒）。临时固定复现入口1/1（0.313秒）后移除，不加入正式默认套件；原断言均保留。

挟征罚则用例在全量中为830/831：只给目标一张桃、发动者没有其他牌，却仅以结算后桃的归属判断罚则是否执行，遗漏了随后强制返牌的合法路径。用例改为将目标体力固定为1，发动者另持一张闪，按技能限定选择返还闪；同时断言返牌请求中已获得桃、返牌数量及最终两牌归属，正式技能未因此修改。

## 历史故障根因与旧状态

<a id="持重夹具根因"></a>
### 持重夹具根因（wei_support.lua:115）

曾报 `expected:1 actual:6`。当时 `initializeGenerals` 调用 `changeHero` 时，`__heg_general`／`__heg_deputy` 标记仍指向本局随机初始双将。引擎 `getGeneralMaxHp()` 优先读取这两个标记，测试角色的 `maxHp/hp` 取决于初始双将。若体力使旧版选牌下限大于回复中的 5 张，选牌就被取消，角色保留 6 张牌。[现行规则](../../../rules/generals/wei003-xiahoudun.md#持重)已按 #25 改为恰好交出超额张数。

诊断时保留的证据：初始双将始终被替换为 `qiao_test__wei_1/wei_2`，但 `hp/maxhp` 出现 3/4 两种；`player.phase = Player.NotActive`、`RoundCount = 1`、技能来源仅为 `qiao__skill_wei003_2`；请求消费为 `"1"→askToSkillInvoke`、`ReplyChooseCards→askToCards`、`ReplyChooseCardAndPlayers→askToYiji`，逐次 q 长度 3→2→1→0，均未错位。修复：写入测试双将标记后用 `pl:getGeneralMaxHp()` 重算 `maxHp/hp`，夹具固定为 4/4；未修改断言、未禁用测试、未固定随机种子。修复后连续 10 次运行均 3/3 通过。

<a id="设变巧变超时根因"></a>
### 设变／巧变 90s 超时根因

根因不是请求 schema 或嵌套事件，而是测试用 `lu.assertEquals(room:getCardOwner(x), p1())` 直接比较 `ServerPlayer` 对象；该比较在 LuaUnit 断言中挂起，设变与巧变出牌两个用例都卡在同一行。包装真实 `Request.getResult` 的原生日志显示相关请求（AskForSkillInvoke、AskForUseActiveSkill/AskForMoveCardInBoard）均已完成并消费回复；将断言改为比较 `.id` 后全部通过。移牌回复仍为 `{ cardId = <牌 id>, pos = cardsPosition[下标] }`。

<a id="魏包白板夹具"></a>
### 魏包白板夹具根因

`wei_active.lua` 夹具改为明确白板双将：`support.initQiaoRoom()` 后统一替换为 `qiao_test__wei_1/2`，写入 `__heg_general/__heg_deputy`、势力与 `__heg_*` 标记，并用 `getGeneralMaxHp()` 重算 `maxHp/hp`；显式设置当前角色与出牌阶段，避免随机真实双将的技能在嵌套【杀】时插入额外询问。C 此前在旧随机真实双将夹具下报告这两个嵌套【杀】用例 30–90 秒超时；改白板夹具后 6 个用例均通过。该对照只证明当前夹具消除了失败现象，未重新用随机夹具做 A/B 重跑，因此不把“随机双将触发额外技能/请求”写成已证实的唯一根因。

<a id="牛金奖励根因"></a>
### 牛金 `expected 3 actual 25` 根因

房间级 global refresh 会按每名角色回调，`can_refresh` 未限定 `player == data.killer`，8 人各触发一次 3 张（24），再加正常国战击杀奖励 1 张，合计 25。已限定 `player == killer` 且存活；测试新增 `AfterCardsMove` 只读探针按 `move.skillName == NJ` 统计恰好一次、恰好 3 张，并断言总手牌 = 正常奖励 1 + 牛金 3。

<a id="shu-standard"></a>
## 蜀势力标准包（2026-11-15）

DSH 分批实现，Codex 审阅并接手收尾修复与验收。规则资料提交为 `5628dce`；武将与回归提交为 `5e9711b`，翼从与目标策略提交为 `0d8adcd`。下面记录最终范围，早期阶段结果不代替最终验收。

| 专项 | 最终项数 | 核心证据 |
| --- | --- | --- |
| `shu_conversion.lua` | 22 | 仁德实际用杀次数、武圣、咆哮全回合历史、龙胆、集智、连环使用／重铸、八阵明暗与正式防具、火计、享乐 |
| `shu_effects.lua` | 10 | 突阵实际抵消者、藏机移动前防止、烈勇失技持续、狂骨击杀收益、看破闪及无懈抵消、淑慎与神智 |
| `shu_phases.lua` | 4 | 观星后续、正式主将空城、真实濒死涅槃、放权跳阶段及失技后额外回合 |
| `shu_savage.lua` | 4 | 祸首来源、再起全场红牌计数、巨象整次取牌、烈刃拼点 |
| `shu_tieqi.lua` | 3 | 按位置失效、暗副将与后续明置、判定花色手牌全部弃置／不能响应 |
| `shu_retinues.lua` | 7 | 周仓实牌用杀和范围方向、整组转化素材、白马使用／打出闪、西凉实际用杀与目标自弃、象兵两条主要流程 |

最终 `python scripts/test.py --timeout 180`：`Ran 713 tests in 120.582 seconds, 713 successes, 0 failures`，退出码 0；六套蜀包专项共 50 项均已纳入默认套件。`python scripts/check_lua.py` 退出码 0。共享目标机制定向历史：`card_use_targets` 34/34、`extra_targets` 37/37，由 DSH 工具原生检查确认，最终默认套件亦包含这些回归。

`python scripts/build_release.py` 构建 `.dev/dist/qiao.zip` 成功。Codex 核对本批修改／新增正式文件，包含全部技能、重铸辅助、模式接线和共享目标条件；包内仅 `init.lua`、`pkg/`、`image/`、`audio/`，不含开发补丁、脚本或测试。15 个蜀区主称号及 26 条卡面技能原文与 JSON 标准版逐项一致。

本批闭合的实质问题：仁德选择窗口的次数参数须进入执行复核；咆哮不能只累计得技后的计次杀；享乐保留使用者自行弃牌；突阵不能读取响应牌当前持有者猜抵消者；烈勇的本次杀加成失技后仍生效；祸首／巨象的免疫须检查技能归属；祸首不改变用牌者；周仓执行时必须沿用显式目标策略；象兵火伤生成的杀不豁免其杀后南蛮条款；周仓与巨象处理对应的全部实体牌。

测试诊断：全局替换请求会污染技能排序，已改按技能限定。放权用例曾深比较带环引用的玩家对象造成挂起，身份断言修正后完整路径及失技路径均通过；不将该断言问题归为游戏故障。Codex 沙箱内启动原生运行时超时后，按授权以本机权限执行；最终结果均来自同一锁定运行时和正式测试入口，没有另建环境绕行。

未完成真实客户端点击、多人联网／重连、干净本体安装人工验收。复杂插入移牌、多重抵消及多来源组合未穷举；自动化通过不扩展为这些结论。

<a id="qun-standard"></a>
## 群势力标准包（2026-11-15）

客户端按钮修复后的最新验收：除疠、乱武、狂斧、祸水、倾城、骁逆不再在客户端读取 `player.room`。`tests/qun_basic.lua` 使用真实 `ClientPlayer`、配套房间与独立牌区，走 `ReqPlayCard.setup`／`skillButtonValidity`；覆盖六技能合法场景、除疠无牌／无候选／次数耗尽、倾城性别筛选及狂斧／骁逆全体目标被禁止的禁用场景。服务端目标策略与执行前复核保留。

```text
python scripts/test.py --file tests/qun_basic.lua --timeout 90
Ran 15 tests in 3.697 seconds, 15 successes, 0 failures
python scripts/test.py --timeout 240
Ran 764 tests in 140.766 seconds, 764 successes, 0 failures
python scripts/check_lua.py
exit 0
python scripts/build_release.py
Built .dev/dist/qiao.zip
```

群技能文件已核对在包内，包内路径仅限正式发布目录。日志为本地 `.dev/logs/qun_client_fixed.log`、`.dev/logs/qun_client_full.log`；全量仍有原生 Distance malfunction 警告，未出现 critical Lua 错误或失败断言。客户端点击、联网／重连与干净本体安装未人工验收。故障预防与夹具说明补在 [lessons.md](../../lessons.md) 及 [testing.md](../../testing.md)，不重复增加原则性警告。以下保留首次集成的历史结果与有复用价值的经验。

DSH 分批实现，Codex 审阅、集中串行运行。范围为 15 将、27 条技能记录及黄巾雷使；马术共用蜀马超实现，并州狼骑／西凉精骑沿用现有实现。

已执行的定向验收（正常权限运行锁定 Windows 运行时）：

```text
python scripts/test.py --file tests/qun_standard.lua --timeout 180
Ran 47 tests in 11.927 seconds, 47 successes, 0 failures
python scripts/test.py --file tests/mode_rules.lua --timeout 120
Ran 10 tests in 1.454 seconds, 10 successes, 0 failures
python scripts/test.py --file tests/standard_generals.lua --timeout 120
Ran 12 tests in 0.366 seconds, 12 successes, 0 failures
python scripts/test.py --file tests/general_exchange.lua --timeout 180
Ran 17 tests in 2.081 seconds, 17 successes, 0 failures
```

有复用价值的故障与修复：

- 济世救活后不交换：引擎回复至 1 点体力时立即清除 `dying`，`after_use` 再据此记录会漏掉已救活者。现于 `CardUsing`、回复生效前记录本次濒死来源；救活和未救活两条真实路径均覆盖。
- 房间事实维护进入技能发动流程会扰动其他技能的触发顺序／测试回复；`global=true` 还会使监听加入所有模式。祸水状态维护改为只由汉晋模式安装的 refresh；黄巾伤害事实记录同样仅由模式安装。
- 断肠不得把普通明置中缺失的技能自动补回。仅在本角色至少一张将牌有断肠记录时，恢复仍有效的共享同名来源；永久失技记录覆盖整张将牌，主副位置变化不刷新。
- 乱击房间监听原先对每名角色重复询问，单个同意回复会掩盖后续重复。按 `target == player` 限一次，并用始终同意的请求辅助断言询问次数为 1。
- 测试探针应直接或必然执行，并限定同一事件只记录一次；`AskForChoices` 使用选项表回复。效果中用杀不占通常用杀次数，应观察真实 `CardUsing` 与实体牌移动。
- 受限执行环境出现原生进程无输出超时，正常权限下公共辅助套件 6/6 及后续定向可运行。不能把这种超时记作测试已执行失败断言或已通过。

真实客户端点击、联网／重连、干净本体安装人工验收未进行。

最终集成与发布核对：

```text
python scripts/test.py --timeout 240
Ran 761 tests in 129.619 seconds, 761 successes, 0 failures
python scripts/check_lua.py
exit 0
python scripts/build_release.py
Built .dev/dist/qiao.zip
```

受影响的汉区拼点、司马炎、吴区伤害与群包十套件共同执行 98 项全部通过（22.964 秒）；使用的是原套件断言，临时组合入口随后删除。安装包内新增／修改正式文件已核对，三个旧群马术骨架不在包内，且排除测试、脚本与开发本体适配。正式将性别登记为 17 女／73 男，离间／倾城针对真实双将的性别过滤已有回归。默认全量完整输出保存在本地 `.dev/logs/qun_full_final.log`。

自动记账即使写为 `on_trigger`，无条件加入触发池仍可能扰动承诏、兴图、不屈的选择；濒死序号、完杀清理和乱击花色清理均改为 refresh，只在本次确有济世记录时触发交换。无记录时不生成新的发动选项。


## 阵包与势包分批验证

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

最终默认验收：本轮执行 `python scripts/test.py --timeout 480`，979/979通过、0失败、退出码0（280.927秒）；输出保存于 `.dev/ascension-fix-full.log`。无critical或Lua回溯，原生Distance malfunction警告仍出现。Lua语法检查通过，`git diff --check`通过。

挑衅 AI 请求修复：`C.askToUseCard` 的 `names/card_name/name` 是策略白名单，不再作为引擎 pattern 直接删除；公共转发从卡名派生 `trueName` pattern（`qiao__slash` → `slash`）。挑衅真实走 `Room:askToUseCard` 请求，AI 不再收到 nil pattern；选择端用锁定引擎的 `extra_data.exclusive_targets` 限定姜维，服务端保留 `fixed_targets` 复核。`tests/card_use_targets.lua` 36/36（含 `card_name` 别名、固定目标拒绝和 exclusive_targets 观察）、`tests/shu012_jiangwei.lua` 6/6（含取消后实际弃牌）。全库扫描中已有显式 pattern 或由上层生成请求参数的分支保留；未发现其他无证据需改的直接调用。首次全量982项981成功，唯一失败为 `shu021_mifuren`；该套记录初始珠联标记（样本 before=0/after=1）并按 before+1 修正断言，单跑4/4。两项修复后最终全量982/982通过。

2026-11-17 四君主增量验收：君孙权 7/7、君曹操 15/15、君司马炎 6/6、君刘协 7/7、双坐骑 3/3；该批默认套件 1020/1020 通过。该批的诏书验证覆盖势力锦囊的取得和使用记录，牌面效果由[后续批次](../card-deck.md#势力锦囊)接入。最新全量与人工验收范围见[开发状态](../../status.md#当前验收基线)。

## 君主与关联机制复核

PR #47 复核使用 FreeKill 0.5.25。四位君主及关联专项 86/86 通过，包含混合同批弃牌的两种顺序、【弘法】恢复后的用牌与响应，以及【转蓬】正反向支付及伤害牌是否对刘协无效。叠加 #38 后专项 138/138 通过。全量结果与已知环境差异见[开发状态](../../status.md)。
