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
