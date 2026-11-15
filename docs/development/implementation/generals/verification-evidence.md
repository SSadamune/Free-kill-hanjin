# 共享验证证据

本附录按原测试文件集中保存一次历史命令输出与真实结果，供各机制页条目引用；条目只写覆盖点，不重复粘贴命令。**本附录不重跑测试、不新增覆盖、不把旧定向结果冒充本轮运行**。不同日期的全量数字来自不同批次，按当时记录保留，不代表同一轮复跑；最新完成度仍以[开发状态](../../status.md)为准。

## 汉区

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

原记录为“测试待基础组集成执行”，未产生独立命令输出；后续 2026-11-13 的汉区最终集成复核确认其已纳入默认套件（564/564 通过）。该旧“未运行”状态已被最终通过取代，但不得把它当作本轮新运行。

<a id="han008_fuhuanghou"></a>
### han008_fuhuanghou.lua

原记录为“测试待基础组统一执行”，未产生独立命令输出；后续汉区最终集成复核确认已纳入默认套件（564/564 通过）。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han008_fuhuanghou.lua --timeout 120`，当时未执行，后由默认套件覆盖。

<a id="han009_fuwan"></a>
### han009_fuwan.lua

原记录为“测试待基础组统一执行”，未产生独立命令输出；后续汉区最终集成复核确认已纳入默认套件（564/564 通过）。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han009_fuwan.lua --timeout 120`，当时未执行，后由默认套件覆盖。

<a id="han012_caiyong"></a>
### han012_caiyong.lua

原记录为“测试待基础组集成执行”，仅静态解析通过；后续汉区最终集成复核确认已纳入默认套件（564/564 通过）。

<a id="han016_liuchong"></a>
### han016_liuchong.lua

原记录为“测试待基础组统一执行”，未产生独立命令输出；后续汉区最终集成复核确认已纳入默认套件（564/564 通过）。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han016_liuchong.lua --timeout 120`，当时未执行，后由默认套件覆盖。

<a id="han017_liuyao"></a>
### han017_liuyao.lua

原记录为“测试待基础组统一执行”，未产生独立命令输出；后续汉区最终集成复核确认已纳入默认套件（564/564 通过）。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han017_liuyao.lua --timeout 120`，当时未执行，后由默认套件覆盖。

<a id="han_retinues"></a>
### han_retinues.lua

原记录为“测试待基础组集成执行”，仅静态解析通过；后续汉区最终集成复核确认已纳入默认套件（564/564 通过）。

## 魏区

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
Built .dev/dist/hanjin.zip (446 files)，退出码 0
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
Built .dev/dist/hanjin.zip (452 files)
退出码 0
```

## 晋区

<a id="jin001_simayan"></a>
### jin001_simayan.lua

由 DSH 直接通过同一 runtime 的 `FreeKill.exe --testfile` 执行专项（当时用户正在运行游戏，未重复同步运行环境）；原记录为：

```text
Ran 17 tests ... 17 successes, 0 failures
```

原文省略了运行时间。默认全量 507/507（该批次）；安装包已构建。最近完整验证记录见[开发状态](../../status.md)。

## 历史故障根因与旧状态

<a id="持重夹具根因"></a>
### 持重夹具根因（wei_support.lua:115）

曾报 `expected:1 actual:6`。确定性原因：`initializeGenerals` 调用 `changeHero` 时，`__heg_general`／`__heg_deputy` 标记仍指向本局随机初始双将；引擎 `getGeneralMaxHp()` 优先读取这两个标记，测试角色 `maxHp/hp` 随初始双将变为 3 或 4（并可更高），而不是测试将面的 4。若体力值使 `max(1, hp+1)` 大于回复中的 5 张，持重会正确判定选牌不足并取消发动，`p1` 保留 6 张牌，表现为“expected 1 actual 6”。

诊断时保留的证据：初始双将始终被替换为 `hanjin_test__wei_1/wei_2`，但 `hp/maxhp` 出现 3/4 两种；`player.phase = Player.NotActive`、`RoundCount = 1`、技能来源仅为 `hanjin__skill_wei003_2`；请求消费为 `"1"→askToSkillInvoke`、`ReplyChooseCards→askToCards`、`ReplyChooseCardAndPlayers→askToYiji`，逐次 q 长度 3→2→1→0，均未错位。修复：写入测试双将标记后用 `pl:getGeneralMaxHp()` 重算 `maxHp/hp`，夹具固定为 4/4；未修改断言、未禁用测试、未固定随机种子。修复后连续 10 次运行均 3/3 通过。

<a id="设变巧变超时根因"></a>
### 设变／巧变 90s 超时根因

根因不是请求 schema 或嵌套事件，而是测试用 `lu.assertEquals(room:getCardOwner(x), p1())` 直接比较 `ServerPlayer` 对象；该比较在 LuaUnit 断言中挂起，设变与巧变出牌两个用例都卡在同一行。包装真实 `Request.getResult` 的原生日志显示相关请求（AskForSkillInvoke、AskForUseActiveSkill/AskForMoveCardInBoard）均已完成并消费回复；将断言改为比较 `.id` 后全部通过。移牌回复仍为 `{ cardId = <牌 id>, pos = cardsPosition[下标] }`。

<a id="魏包白板夹具"></a>
### 魏包白板夹具根因

`wei_active.lua` 夹具改为明确白板双将：`support.initHanjinRoom()` 后统一替换为 `hanjin_test__wei_1/2`，写入 `__heg_general/__heg_deputy`、势力与 `__heg_*` 标记，并用 `getGeneralMaxHp()` 重算 `maxHp/hp`；显式设置当前角色与出牌阶段，避免随机真实双将的技能在嵌套【杀】时插入额外询问。C 此前在旧随机真实双将夹具下报告这两个嵌套【杀】用例 30–90 秒超时；改白板夹具后 6 个用例均通过。该对照只证明当前夹具消除了失败现象，未重新用随机夹具做 A/B 重跑，因此不把“随机双将触发额外技能/请求”写成已证实的唯一根因。

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

`python scripts/build_release.py` 构建 `.dev/dist/hanjin.zip` 成功，共 459 文件。Codex 对 41 个本批修改／新增正式文件逐字节核对，包含全部技能、重铸辅助、模式接线和共享目标条件；包内仅 `init.lua`、`pkg/`、`image/`、`audio/`，不含开发补丁、脚本或测试。15 个蜀区主称号及 26 条卡面技能原文与 JSON 标准版逐项一致。

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
Built .dev/dist/hanjin.zip (466 files)
```

24 个群技能文件与包内逐字节一致，包内路径仅限正式发布目录。日志为本地 `.dev/logs/qun_client_fixed.log`、`.dev/logs/qun_client_full.log`；全量仍有原生 Distance malfunction 警告，未出现 critical Lua 错误或失败断言。客户端点击、联网／重连与干净本体安装未人工验收。故障预防与夹具说明补在 [lessons.md](../../lessons.md) 及 [testing.md](../../testing.md)，不重复增加原则性警告。以下保留首次集成的历史结果与有复用价值的经验。

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
Built .dev/dist/hanjin.zip (466 files)
```

受影响的汉区拼点、司马炎、吴区伤害与群包十套件共同执行 98 项全部通过（22.964 秒）；使用的是原套件断言，临时组合入口随后删除。安装包内 40 个新增／修改正式文件与工作区逐字节一致，三个旧群马术骨架不在包内，且排除测试、脚本与开发本体适配。正式将性别登记为 17 女／73 男，离间／倾城针对真实双将的性别过滤已有回归。默认全量完整输出保存在本地 `.dev/logs/qun_full_final.log`。

自动记账即使写为 `on_trigger`，无条件加入触发池仍可能扰动承诏、兴图、不屈的选择；濒死序号、完杀清理和乱击花色清理均改为 refresh，只在本次确有济世记录时触发交换。无记录时不生成新的发动选项。
