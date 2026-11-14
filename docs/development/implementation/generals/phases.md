# 阶段、转换与限定技：跨势力机制实现与验证

本页汇总汉、魏两包中涉及阶段开始与结束、阶段跳过、限定技及视为牌转换（view-as）的技能实现、接口接线与真实验证状态，不替代规则条文。逐将检索见[汉势力标准包](han-standard.md#1-分组与逐将入口)与[魏势力标准包](wei-standard.md#1-分组与逐将入口)；整将记录按主要机制放入对应组，其他组只以锚点引用，不复制正文。

## 魏势力标准包

本页记录 WEI006 轻辎、WEI007 倾国／洛神、WEI008 神速／设变、WEI009 巧变、WEI010 断粮、WEI011 励战的实现接线、接口依据与验证状态，不替代规则条文。规则来源为 [标准武将表](../../../../rules/standard-generals.md) 魏区与 `rulebook/` 原文；外部资料 `docs/石激桑武将列表.json` 仅作核对。正式技能独立实现，`hanjinImplemented = true`。

### 1. 范围与文件

| 编号 | 技能 | 实现文件 | 核心行为 |
| --- | --- | --- | --- |
| WEI006 | 轻辎 | [skill_wei006_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei006_1.lua) | 准备阶段弃置同势力其他角色装备区一张牌，令其获得“神速”直到其回合结束 |
| WEI007 | 倾国 | [skill_wei007_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei007_1.lua) | 黑色手牌当【闪】使用或打出 |
| WEI007 | 洛神 | [skill_wei007_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei007_2.lua) | 准备阶段判定；黑色可重复，全部判定结束后统一获得黑色判定牌 |
| WEI008 | 神速 | [skill_wei008_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei008_1.lua) | 分别在判定／出牌／弃牌阶段开始前选择对应项，支付代价并视为使用无距离【杀】 |
| WEI008 | 设变 | [skill_wei008_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei008_2.lua) | 失去体力后移动场上一张牌 |
| WEI009 | 巧变 | [skill_wei009_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei009_1.lua) | 弃一张牌跳过阶段；摸牌阶段获得手牌，出牌阶段移动场上牌 |
| WEI010 | 断粮 | [skill_wei010_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei010_1.lua) | 黑色非锦囊牌当【兵粮寸断】；其他角色跳摸后令一名角色摸一张牌 |
| WEI011 | 励战 | [skill_wei011_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei011_2.lua) | 结束阶段令任意名已受伤角色各摸一张牌 |

共享工具：[wei_phases.lua](../../../../pkg/hanjin_generals/util/wei_phases.lua)（公开势力预测、场上牌可移动性检查、两步式场上移牌）。专项测试：[wei_phases.lua](../../../../tests/wei_phases.lua)（已并入 [all.lua](../../../../tests/all.lua)）。

### 2. 接口核对（锁定 0.5.25 与 hegemony）

- 阶段跳过使用 `ServerPlayer:canSkip(phase)`／`ServerPlayer:skip(phase)`（0.5.25 `ltk/server/serverplayer.lua`）。`canSkip` 只检查当前回合尚未跳过的阶段，`skip` 标记当前回合的该阶段；已跳过的阶段不会再次触发 `fk.EventPhaseChanging`。
- 神速监听 `fk.EventPhaseChanging`，分别在判定/出牌/弃牌阶段开始前询问对应项，不设准备阶段一次性选择；`data.skipped == false` 才可发动，判定项还要求 `canSkip(Player.Draw)`。
- 移动场上牌先由引擎公共的 `Room:askToChooseToMoveCardInBoard` 在两阶段内筛出确有可移动关系的两名角色，再用 `Room:askToMoveCardInBoard`（0.5.25 `ltk/server/room.lua` 3374 行）在其中一人装备／判定区选牌移动；请求回复为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。
- 洛神使用 `Room:judge`：其返回值不是 JudgeData，判定结果写回传入的 spec 表（`TriggerData:_data` 包装），因此调用后读取原表；循环结束后只收集仍在处理区/弃牌堆的黑色判定牌，一次 `obtainCard` 统一移动。
- 视为使用【杀】走项目公共目标策略 `card_use_targets`：`bypassDistance` 取消距离限制，`extra_data.bypass_times = true` 豁免选择时的次数检查，最终使用数据以顶层 `extraUse = true` 标记不计通常出杀次数。
- 临时技能授予使用 `Room:handleAddLoseSkills(player, skill, source, ...)`，来源记为轻辎；到期用同一来源 `"-" .. skillName` 移除。授予状态使用不带 `-turn` 的独立标记，不随郭嘉回合末自动清除。
- 客户端不读取服务端私有字段：同势力候选复用 hegemony 公共的 `HegUtil.compareExpectedKingdomWith`（拥有者暗置时按本人可见的 `__heg_kingdom`／`__heg_wild` 预测明置后的势力），他人暗置时公开势力为 `unknown`，不进入候选。

### 3. 关键实现决定

- 洛神：记录本次流程最终生效的黑色判定牌（含改判后的判定牌），全部判定结束后统一获得，修正了上游逐次 `FinishJudge` 入手的写法，并修正对 `room:judge` 返回值的假设。
- 神速：三项分别在判定/出牌/弃牌阶段开始前询问；判定项要求摸牌阶段尚未被跳过；选项 2 的装备牌从手牌或装备区弃置；选项 3 失去体力（可触发设变）；每项独立视为使用一张【杀】。
- 设变：仅 `HpLost` 触发；`can_trigger` 先检查场上确有可移动牌。
- 巧变：摸牌阶段效果由技能拥有者选择至多两名其他角色，各随机获得其一张手牌；出牌阶段效果复用公共移牌接口。
- 断粮：转换模板按黑色及类别位 `basic,equip` 排除锦囊，底牌区域按引擎视为技选牌权限处理；本轮专项主要触达跳过摸牌阶段后的摸牌分支，装备区素材的真实客户端选取尚未人工验收，不将“仅手牌”增写为规则限制。
- 倾国：`viewas` 仅手牌，花色黑色；未开放装备区，使用与打出共用入口。
- 轻辎：授予状态使用独立标记，只在目标自己的 TurnEnd 回收；授予/移除都带轻辎来源，目标原有暗将神速或后获其他来源的同名技能不会被移除；同势力候选使用公开势力预测，客户端与服务端一致。

### 4. 验证状态

本轮真实执行（2026-11-14）：

```text
python scripts/test.py --file tests/wei_phases.lua --timeout 180
Ran 14 tests in 3.281 seconds, 14 successes, 0 failures
OK
```

此前 90s 超时的根因不是请求 schema 或嵌套事件，而是测试用 `lu.assertEquals(room:getCardOwner(x), p1())` 直接比较 `ServerPlayer` 对象；该比较在 LuaUnit 断言中挂起，设变与巧变出牌两个用例都卡在同一行。包装真实 `Request.getResult` 的原生日志显示相关请求（AskForSkillInvoke、AskForUseActiveSkill/AskForMoveCardInBoard）均已完成并消费回复；将断言改为比较 `.id` 后全部通过。移牌回复仍为 `{ cardId = <牌 id>, pos = cardsPosition[下标] }`。

覆盖的核心行为：

- 洛神连续两次黑色后红桃终止；`AfterCardsMove` 探针确认黑色判定牌只产生一次得到移动、共两张；
- 神速分别在判定/出牌/弃牌阶段开始前发动，跳过对应阶段、支付对应消耗并视为使用【杀】；已跳过阶段不再消耗；
- 轻辎弃置目标装备后授予神速；施加者回合结束仍保留，目标回合结束回收；目标原有/另一来源的神速不被移除；
- 断粮在他人跳过摸牌阶段后令一名角色摸牌；
- 励战令已受伤角色摸牌；
- 倾国黑色手牌可转化、红色手牌与装备区牌不可用，且使用／响应均可用。

### 5. 未完成与风险

- [wei_phases.lua](../../../../tests/wei_phases.lua) 已由整合方加入 [all.lua](../../../../tests/all.lua)。
- 设变、巧变的请求级用例已恢复并通过：移牌回复 schema 依锁定客户端 QML 为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。设变用例双方均有可移动牌（p1 藤甲、p2 武器）。神速弃牌项的用例未放置可移动场上牌，因此不会额外询问设变；设变移动由独立真实失去体力用例覆盖。
- 未做真实客户端点击验收（阶段触发确认、两步移牌选择、目标选择）。
- 巧变获得手牌为服务端随机隐藏选择，未增加客户端可见性测试。

## 汉势力标准包

<a id="han004"></a>

### HAN004 张让：滔乱实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认最新 567/567 通过（含同回合多次发动、回合末只结算一次的回归），发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

游戏语义见[专项裁定](../../../../rules/generals/han004-zhangrang.md)与[标准武将表](../../../../rules/standard-generals.md)汉区 HAN004。本文记录接口与验收依据；同一回合多次发动只结算一次的语义按用户 2026-11-13 确认的裁定（`rules/` 规范由 Codex 同步更新），本页只记录实现与验证，不另定规则。

#### 1. 实现结构

- `pkg/hanjin_generals/skills/skill_han004_1.lua`：滔乱。
- 骨架显式赋 `hanjinImplemented = true`，不改 `init.lua`、`data/`。

#### 2. 发动窗口与明置

- 统一使用 ViewAs：正常出牌阶段与合法「使用」窗口共用同一入口，无实体子牌，按正常牌面条件选择目标；正常出牌不会绕过普通【杀】次数。
- `view_as` 是客户端纯函数：只读取自身可见武将/本局公开标记，不调用 `player.room`，也不做服务端查询。它在克隆牌之后把来源编号（1 主将 / 2 副将）写到 `card.hanjinTaoluanSource`。
- 响应窗口只放行 `ReqUseCard` 的「使用」窗口（含回合外使用【闪】/【无懈】）；`enabled_at_response` 在 `cardResponsing = true` 的纯打出请求下固定返回 false，不按响应牌名另做解析。
- 只有承载本技能的武将牌暗置且 `prohibitReveal` 允许时才可发动；客户端仅依据自身可见武将与本局公开标记。已明置后 `hiddenSource` 返回 nil，不再发动。
- `room:useSkill` 在 `before_use` 之前按技能名自动明置来源武将（`revealBySkillName`）。因此 `before_use` 不能要求来源仍暗置；它只消费 `hanjinTaoluanSource`，核对编号对应的武将已明置且确实承载本技能，不合法时返回技能名取消本次使用，避免伪造亮将发动。
- 候选牌名按 `hanjin_cards/data/reuse.lua` 的 `status == "reused"` 过滤，只取已实装、非衍生、非空壳的基本牌/普通锦囊，排除延时锦囊与装备。

#### 3. 记录与回合末结算

- 记录与结算在首次发动时安装为房间级延迟技能，不依附张让当前技能对象；明置导致技能替换后仍能收牌。
- 以真实 `fk.TargetSpecified` 时点记录「本回合以此法使用牌指定过的其他角色」到 `-turn` 表标记，只由该牌的 `data.from` 这一个 owner 处理，不按候选玩家重复变更；不取 `CardUseFinished` 最终目标。重复指定同一角色由 `addTableMarkIfNeed` 去重。
- 每次真实宣告成功（`fk.AfterCardUseDeclared`）给发动者增加一次 `-turn` 发动计数，单次使用只计一次；不按目标数或结算次数重复计。该计数只用于判断是否有待结算记录，不决定结算轮数。
- `fk.TurnEnd` 使用 refresh 而非需要询问发动的 trigger：结算必须自动发生，且房间级延迟技能无需再注册触发器名。房间 tag 防止重入；同一角色同一回合无论发动几次都只调用一次 `settle`，清空待结算计数后按玩家逐个处理，不把结算扩大成全局所有玩家一次。
- 结算候选取本回合累计记录的指定目标并集（多次发动、不同目标都保留），不缩成最后一次用牌的目标；每名角色至多结算一次，因此收牌询问、红黑比较与暗置都只有一轮。
- `-turn` 标记由引擎 `clearHistory(Player.HistoryTurn)` 在回合末结算后清理，不手工跨回合保留。
- 每次结算：选择至多三名候选（逆时针排序），依次询问每名仍有手牌者展示并交一张手牌；按实际得到牌的有效颜色统计红/黑，红多于黑时暗置自己一张可暗置武将（两张均明置时询问）。
- 未得到的牌不额外补抽；无手牌角色跳过。

#### 4. 验证

`tests/han004_zhangrang.lua`（均为真实请求/回复与真实回合）：

| 用例 | 断言 |
| --- | --- |
| 暗置发动与回合末 | 出牌阶段先取消国战争取明置询问；经真实 `PlayCard` 以滔乱使用【杀】并明置；同一完整 Turn 的 TurnEnd 选 p2，p2 交红牌后张让实际得牌并暗置主将 |
| 回合外使用【闪】 | 暗置时 `enabledAtResponse(player, true)` 为 false、false 时为 true；p2 使用【杀】时，p1 经 `ReqUseCard` 以滔乱使用【闪】；未受伤、来源明置、发动计数保留 |
| 已明置不可再发动 | 主副将均明置后仍提交滔乱使用：服务端不提供来源，使用被取消，目标未受伤、武将保持明置 |
| 同回合两次发动只结算一次 | 同一真实 Turn 内真实发动两次（首次用【杀】指定 p2，结算后由测试专用触发效果暗置张让，再以【决斗】指定 p3）：发动计数计到 2、两名目标各受伤；回合末 `askToChoosePlayers` 只询问一次且候选含两人，两张红牌各交一次，红多于黑只暗置一张（重复结算时该询问会变成两次，由计数断言判别） |

#### 5. 执行状态

- 定向命令与真实结果（2026-11-13）：
  - `python scripts/test.py --file tests/han004_zhangrang.lua --timeout 120` → `Ran 4 tests in 0.981 seconds, 4 successes, 0 failures`，退出码 0。
  - 同一命令在临时还原旧「按发动次数循环 settle」实现时失败于 `expected: 1, actual: 2`（收牌询问两次），确认新用例能区分新旧行为；随后恢复修复实现并复跑通过。
  - `python scripts/test.py --timeout 300`（默认全量）→ `Ran 567 tests in 87.485 seconds, 567 successes, 0 failures`，退出码 0。默认 60s 超时在本机不足以跑完全量，故显式放宽；耗时与通过数与本次改动无关。
  - `python scripts/build_release.py` → 生成 440 个文件的发布包；核对包内含更新后的每回合单次结算实现，未含 `tests/`、`.dev/`。
- 实现未修改 `.dev/` 上游，技能及接线随扩展发布。

#### 6. 未覆盖与风险

- 本轮不改变发动资格：承载武将仍须暗置才能发动，首次发动后即明置；同回合两次发动只由测试专用效果制造暗置来覆盖结算语义，不代表正式对局中的额外发动途径。
- 明置源、限一次暗置等边界未做完整场景映射，只按本轮核心验收。
- 客户端 UI 的真实点击流程（选牌名、选目标、暗置选择）未做人工界面验证，自动化只验证服务端请求与回复。

<a id="han012"></a>

### HAN012 蔡邕：铸典、博通实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

游戏语义见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN012；本页记录接口、接线与验收依据，不替代规则裁定。当前完成度由[开发状态](../../status.md)统一登记。本轮只交付 HAN012，未处理汉区其他武将。

#### 1. 实现结构

- `pkg/hanjin_generals/skills/skill_han012_1.lua`：铸典，`fk.TargetConfirmed` 触发；重铸用 `Room:recastCard`，黑色分支展示后补摸。
- `pkg/hanjin_generals/skills/skill_han012_2.lua`：博通，`viewas` 转化任意基本牌；`fk.CardUseFinished` 时把仍在处理区的子牌分配给其他角色。
- 两个骨架均显式赋 `hanjinImplemented = true`，不改 `init.lua` 白名单或 `data/`。

#### 2. 铸典

- 时机为「成为目标后」，使用 `fk.TargetConfirmed`；条件排除自己使用，并要求使用牌为黑色。
- 重铸是 `置入弃牌堆，然后摸一张牌`，不是弃置。选牌直接放在 `on_cost`：取消选牌即不发动，避免先明置再询问可取消消耗；实现不调用 `prohibitDiscard` 过滤，也不把重铸写成弃牌消耗。`Room:recastCard` 返回实际摸到的牌。
- 黑色分支对 `Room:filterCard(id, player)` 的有效颜色判断；展示前复核该牌仍由自己持有，避免展示已转手/隐藏的牌。展示通过 `Room:showCards`，再摸一张。
- 重铸前再次核对牌仍属于自己；重铸后死亡则不继续展示/补摸。

#### 3. 博通

- `viewas` 选牌：自己的手牌区或装备区（`include_equip = true`）；合法组合仅两种：
  - 4 张且四种花色各一张；
  - 3 张且基本牌/锦囊牌/装备牌各一张。
- `card_filter` 以「补选后仍可能形成上述任一组合」防止选牌死路；`feasible` 做最终校验。多子牌的颜色/点数由引擎 `Card:addSubcards` 按普通多子牌规则确定，不手算。
- 牌名交互用 `UI.CardNameBox`，候选由公开的 `Player:getViewAsCardNames` 过滤；转化结果只允许「使用」，`enabled_at_response = false`。
- 使用结算结束时，`fk.CardUseFinished` 先于处理区子牌置入弃牌堆触发；该效果标记 `is_delay_effect = true`，属于本次转化使用的后续效果，不作为新技能发动，也不因中途失去博通而消失。此时取仍留在 `Card.Processing` 的子牌；接受给牌后必须把当前可给子牌全部分配完，不能只给一部分后取消（可在最初拒绝整项给牌）。分配逐名选择，最后统一调用一次 `Room:doYiji`，即一次正常给牌移动，不限定接收人数，不保留标记。
- 未分配的牌只可能来自非法/空回复等异常路径，正常流程全部给完；异常余牌留在处理区，由使用流程置入弃牌堆。

#### 4. 验证范围

定向套件 `tests/han012_caiyong.lua`：

| 用例 | 核心断言 |
| --- | --- |
| 铸典黑色分支 | 装备牌在禁止弃置下仍可重铸；摸到黑色后展示并补摸；红牌不入展示 |
| 铸典非黑分支 | 摸到红牌不展示、不补摸，重铸牌进弃牌堆 |
| 博通四花色 | 4 张四花色当【杀】使用；结算后 4 张子牌全部交给 p2，p1 不残留 |
| 博通三类别 | 基本/锦囊/装备各一张成功使用；拒绝分配时三张正常进弃牌堆 |

公共牌移动、使用流程、响应与处理区清理复用现有覆盖。

#### 5. 执行状态

- **测试待基础组集成执行**：本轮未启动 FreeKill、未运行 `scripts/test.py`、未部署共享 runtime；上述行为用例尚无命令输出，不宣称验收通过。
- 已执行静态解析（项目 `scripts/check_lua.py`，使用运行时自带 Lua 5.4 解析全部扩展文件）：`skill_han012_1.lua`、`skill_han012_2.lua`、`tests/han012_caiyong.lua` 及修改后的王荣文件均为 `OK`，退出码 0。
- 定向命令（由基础组执行）：`python scripts/test.py --file tests/han012_caiyong.lua --timeout 120`。
- 套件尚未加入 `tests/all.lua`（本轮禁止修改该文件）。

#### 6. 未覆盖与风险

- 博通分配采用逐名选择、最后统一移动；若后续要求单次界面完成多目标分配，可改用分配专用请求，但当前语义与一次给牌移动一致。
- 基本牌名表目前列汉晋已登记的基本牌（含属性【杀】）；若卡表新增基本牌，应同步扩充。
- 铸典的重铸牌若因其他效果多摸，只按第一张判断黑色分支；标准重铸规则为摸一张，此边界未另作扩展。
- 王荣的红桃判定已改用 `Room:filterCard` 的有效花色；其实现文档中的旧风险条目应由规则维护者同步更新（本轮文件范围不含该文档）。

<a id="han016a"></a>

### HAN016A 刘宠：劲弩、威屯实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

本页记录本轮限定实现与验收依据。规则约定见
[rules/generals/han016a-liuchong.md](../../../../rules/generals/han016a-liuchong.md)；
卡面见[标准武将表](../../../../rules/standard-generals.md)。运行时仍使用
`hanjin__han016` 与 `skill_han016_1/2.lua`，本轮不做资源编号迁移。

#### 1. 范围

- 劲弩：`pkg/hanjin_generals/skills/skill_han016_1.lua`
- 威屯：`pkg/hanjin_generals/skills/skill_han016_2.lua`
- 定向用例：[tests/han016_liuchong.lua](../../../../tests/han016_liuchong.lua)

#### 2. 实现要点

##### 劲弩

- 出牌阶段结束时触发执行一次；零用牌不满足任何分支。
- 直接查询本阶段真实发生的 `GameEvent.UseCard` 事件，按事件 id 排序，因此
  技能在非空闲时点使用的牌也进入完整牌序；不依赖引擎的聚合用牌次数。
  纯“打出”的 `GameEvent.RespondCard` 不是“使用”，不进入本条件。
- 两个分支分别为：
  - 至少使用过一张牌且全部为【杀】；
  - 至少使用过两张牌且最后两张均不为【杀】。
- 满足时在 `on_cost` 选定目标，再使用显式目标策略的 `bypass_distance` 虚拟
  【杀】：保留通常目标规则，但不计算距离；真实使用一次，避免重复结算。

##### 威屯

- 限定技。`EventPhaseChanging` 的弃牌阶段开始前检查手牌数是否全场最多，
  并列最多也满足。
- `on_cost` 先筛选候选并让发动者选定一组共同目标；`on_use` 设置
  `data.skipped = true` 跳过弃牌阶段，然后依次对同一组目标使用
  【桃园结义】和【五谷丰登】。
- 两张牌使用汉晋显式目标策略：允许自己、允许满血等通常牌面会排除的目标；
  独立的禁止使用/禁止指定仍由公共目标策略和真实用牌入口复核。目标组不因
  第一张牌结算后重新选择。

#### 3. 测试状态与未覆盖

**测试待基础组统一执行。** 本轮未启动 FreeKill、未运行测试，不能视为通过。
静态解析已通过。定向命令：

```text
python scripts/test.py --file tests/han016_liuchong.lua --timeout 120
```

核心用例合并覆盖：

- 劲弩零用牌不触发；全部为【杀】触发一次无距离【杀】；最后两张均非【杀】
  触发；不逐项拆分排列。
- 威屯并列手牌最多、跳过弃牌阶段、同一组目标依次使用【桃园结义】和
  【五谷丰登】，并检查目标包含自己。

未覆盖/需基础组确认：

- 未执行真实客户端出牌、阶段跳过及两张群体牌的目标选择交互；
- 未覆盖阶段内响应/非空闲窗口的复杂牌序边界、技能造成目标死亡后第二张牌
  的目标复核、禁止使用/禁止指定具体来源；
- 未验证武将交换、跨回合清理和默认全量套件。
- 运行时编号仍为 `hanjin__han016`；资源编号迁移不在本轮范围。

<a id="han018"></a>

### HAN018 蹇硕：集兵

- 实现文件：[skill_han018_1.lua](../../../../pkg/hanjin_generals/skills/skill_han018_1.lua)（集兵）。
- 专项测试：[han_standard.lua](../../../../tests/han_standard.lua)（共享汉区套件），无独立逐将专项文件。
- 当前记录：集兵随汉区 25 技能一并实装并纳入默认国战套件；本组暂无更细的接口接线、定向用例输出或人工验收记录，未完成边界沿用[汉势力标准包](han-standard.md#5-尚未人工验证)。
