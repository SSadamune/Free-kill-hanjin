# 魏势力标准包：阶段与转换组 8 技能实现与验证

本页记录 WEI006 轻辎、WEI007 倾国／洛神、WEI008 神速／设变、WEI009 巧变、WEI010 断粮、WEI011 励战的实现接线、接口依据与验证状态，不替代规则条文。规则来源为 [标准武将表](../../../../rules/standard-generals.md) 魏区与 `rulebook/` 原文；外部资料 `docs/石激桑武将列表.json` 仅作核对。正式技能独立实现，`hanjinImplemented = true`。

## 1. 范围与文件

| 编号 | 技能 | 实现文件 | 核心行为 |
| --- | --- | --- | --- |
| WEI006 | 轻辎 | `pkg/hanjin_generals/skills/skill_wei006_1.lua` | 准备阶段弃置同势力其他角色装备区一张牌，令其获得“神速”直到其回合结束 |
| WEI007 | 倾国 | `pkg/hanjin_generals/skills/skill_wei007_1.lua` | 黑色手牌当【闪】使用或打出 |
| WEI007 | 洛神 | `pkg/hanjin_generals/skills/skill_wei007_2.lua` | 准备阶段判定；黑色可重复，全部判定结束后统一获得黑色判定牌 |
| WEI008 | 神速 | `pkg/hanjin_generals/skills/skill_wei008_1.lua` | 准备阶段选任意项；逐项跳过阶段并视为使用无距离【杀】 |
| WEI008 | 设变 | `pkg/hanjin_generals/skills/skill_wei008_2.lua` | 失去体力后移动场上一张牌 |
| WEI009 | 巧变 | `pkg/hanjin_generals/skills/skill_wei009_1.lua` | 弃一张牌跳过阶段；摸牌阶段获得手牌，出牌阶段移动场上牌 |
| WEI010 | 断粮 | `pkg/hanjin_generals/skills/skill_wei010_1.lua` | 黑色非锦囊牌当【兵粮寸断】；其他角色跳摸后令一名角色摸一张牌 |
| WEI011 | 励战 | `pkg/hanjin_generals/skills/skill_wei011_2.lua` | 结束阶段令任意名已受伤角色各摸一张牌 |

共享工具：`pkg/hanjin_generals/util/wei_phases.lua`（公开势力预测、阶段跳过结果查询、两步式场上移牌）。专项测试：`tests/wei_phases.lua`（已并入 `tests/all.lua`）。

## 2. 接口核对（锁定 0.5.25 与 hegemony）

- 阶段跳过使用 `ServerPlayer:canSkip(phase)`／`ServerPlayer:skip(phase)`（0.5.25 `ltk/server/serverplayer.lua`）。`canSkip` 只检查当前回合尚未跳过的阶段，`skip` 标记当前回合的该阶段；已跳过的阶段不会再次触发 `fk.EventPhaseChanging`。
- 神速监听 `fk.EventPhaseChanging`，分别在判定/出牌/弃牌阶段开始前询问对应项，不设准备阶段一次性选择；`data.skipped == false` 才可发动，判定项还要求 `canSkip(Player.Draw)`。
- 移动场上牌先由引擎公共的 `Room:askToChooseToMoveCardInBoard` 在两阶段内筛出确有可移动关系的两名角色，再用 `Room:askToMoveCardInBoard`（0.5.25 `ltk/server/room.lua` 3374 行）在其中一人装备／判定区选牌移动；请求回复为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。
- 洛神使用 `Room:judge`：其返回值不是 JudgeData，判定结果写回传入的 spec 表（`TriggerData:_data` 包装），因此调用后读取原表；循环结束后只收集仍在处理区/弃牌堆的黑色判定牌，一次 `obtainCard` 统一移动。
- 视为使用【杀】走项目公共目标策略 `card_use_targets`：`bypassDistance` 取消距离限制，`extra_data.bypass_times = true` 不计通常出杀次数。
- 临时技能授予使用 `Room:handleAddLoseSkills(player, skill, source, ...)`，来源记为轻辎；到期用同一来源 `"-" .. skillName` 移除。授予状态使用不带 `-turn` 的独立标记，不随郭嘉回合末自动清除。
- 客户端不读取服务端私有字段：同势力候选复用 hegemony 公共的 `HegUtil.compareExpectedKingdomWith`（拥有者暗置时按本人可见的 `__heg_kingdom`／`__heg_wild` 预测明置后的势力），他人暗置时公开势力为 `unknown`，不进入候选。

## 3. 关键实现决定

- 洛神：记录本次流程最终生效的黑色判定牌（含改判后的判定牌），全部判定结束后统一获得，修正了上游逐次 `FinishJudge` 入手的写法，并修正对 `room:judge` 返回值的假设。
- 神速：三项分别在判定/出牌/弃牌阶段开始前询问；判定项要求摸牌阶段尚未被跳过；选项 2 的装备牌从手牌或装备区弃置；选项 3 失去体力（可触发设变）；每项独立视为使用一张【杀】。
- 设变：仅 `HpLost` 触发；`can_trigger` 先检查场上确有可移动牌。
- 巧变：摸牌阶段效果由技能拥有者选择至多两名其他角色，各随机获得其一张手牌；出牌阶段效果复用公共移牌接口。
- 断粮：`viewas` 仅接受手牌中的黑色基本牌或装备牌；非锦囊由类别位 `basic,equip` 限定。
- 倾国：`viewas` 仅手牌，花色黑色；未开放装备区，使用与打出共用入口。
- 轻辎：授予状态使用独立标记，只在目标自己的 TurnEnd 回收；授予/移除都带轻辎来源，目标原有暗将神速或后获其他来源的同名技能不会被移除；同势力候选使用公开势力预测，客户端与服务端一致。

## 4. 验证状态

本轮真实执行（2026-11-14）：

```text
python scripts/test.py --file tests/wei_phases.lua --timeout 180
Ran 14 tests in 3.281 seconds, 14 successes, 0 failures
OK
```

此前 90s 超时的根因不是请求 schema 或嵌套事件，而是测试用 `lu.assertEquals(room:getCardOwner(x), p1())` 直接比较 `ServerPlayer` 对象；该比较在 LuaUnit 断言中挂起，设变与巧变出牌两个用例都卡在同一行。包装真实 `Request.getResult` 的原生日志显示相关请求（AskForSkillInvoke、AskForUseCard/AskForUseMoveCardInBoard）均已完成并消费回复；将断言改为比较 `.id` 后全部通过。移牌回复仍为 `{ cardId = <牌 id>, pos = cardsPosition[下标] }`。

覆盖的核心行为：

- 洛神连续两次黑色后红桃终止；`AfterCardsMove` 探针确认黑色判定牌只产生一次得到移动、共两张；
- 神速分别在判定/出牌/弃牌阶段开始前发动，跳过对应阶段、支付对应消耗并视为使用【杀】；已跳过阶段不再消耗；
- 轻辎弃置目标装备后授予神速；施加者回合结束仍保留，目标回合结束回收；目标原有/另一来源的神速不被移除；
- 断粮在他人跳过摸牌阶段后令一名角色摸牌；
- 励战令已受伤角色摸牌；
- 倾国黑色手牌可转化、红色手牌与装备区牌不可用，且使用／响应均可用。

## 5. 未完成与风险

- `tests/wei_phases.lua` 已由整合方加入 `tests/all.lua`。
- 设变、巧变的请求级用例已恢复并通过：移牌回复 schema 依锁定客户端 QML 为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。设变用例双方均有可移动牌（p1 藤甲、p2 武器）。神速弃牌项失去体力会插入同一 WEI008 的设变询问，用例已给明确回复。
- 未做真实客户端点击验收（阶段触发确认、两步移牌选择、目标选择）。
- 巧变获得手牌为服务端随机隐藏选择，未增加客户端可见性测试。
