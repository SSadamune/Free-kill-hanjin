# 魏势力标准包：持重、突袭、放逐与行殇修正

本页记录 WEI003 持重、WEI004 突袭、WEI014 放逐的最小可运行实现与接口接线，并记录同轮 WEI014 行殇的取牌范围修正。规则依据见[标准武将表](../../../../rules/standard-generals.md)魏区、[WEI014 曹丕结算约定](../../../../rules/generals/wei014-caopi.md)、[叠置与平置](../../../../rulebook/terms/general-op-terms/stack.md)、[“X 只能当 Y 使用／打出”实现说明](../only-as.md)。本轮已定向运行 [wei_support.lua](../../../../tests/wei_support.lua) 与 [wei_damage.lua](../../../../tests/wei_damage.lua)，结果见第 3 节。

## 1. 实现与接线

| 技能 | 运行时 id | 源码 | 要点 |
| --- | --- | --- | --- |
| 持重 | `hanjin__skill_wei003_2` | [skill_wei003_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei003_2.lua) | `fk.AfterCardsMove`；非摸牌阶段得到手牌后，每回合限一次；选择张数须大于当前体力值（至少体力值+1），选中的手牌全部经 `askToYiji` 同时分配给其他角色 |
| 突袭 | `hanjin__skill_wei004_1` | [skill_wei004_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei004_1.lua) | `fk.DrawNCards`；选择至多 `data.n` 名有手牌的其他角色，少摸等量张并各获得一张手牌；可展示后接公共 only-as 的 `tuxi` 来源 |
| 放逐 | `hanjin__skill_wei014_2` | [skill_wei014_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei014_2.lua) | `fk.Damaged` 每次伤害事件一次；目标叠置并摸2，手牌/装备合计≥4时可足额弃4并平置，牌名字数之和>7则失去1点体力 |
| 行殇（修正） | `hanjin__skill_wei014_1` | [skill_wei014_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei014_1.lua) | 取牌范围由 `getCardIds()` 改为 `getCardIds("he")`；“某人的牌”只含手牌与装备，只有判定区牌的死亡角色视为没有牌并改为回复1点体力 |

三个技能骨架均显式 `hanjinImplemented = true`，通过既有加载断言接入正式内容；专项已加入 [all.lua](../../../../tests/all.lua)，当前完成度与最终全量记录统一见[开发状态](../../status.md)。魏区 `data/standard.lua` 在持重问题解决后同步牌面数据（见第 4 节），其他势力数据未改。

### 持重

- 触发以 `fk.AfterCardsMove` 检查是否有牌移入该角色手牌区；装备区不计为“得到”。
- “摸牌阶段外”依 `rulebook/terms/game-flow-terms/phase.md` 的“某角色于阶段内”默认指其自身阶段，直接检查 `player.phase == Player.Draw`；其他角色的摸牌阶段内自己得到牌仍可发动。
- 已确认解释不是“只分出超额部分”：最小张数为 `math.max(1, 体力值 + 1)`，`max_num = 手牌数`；选牌使用 `Room:askToCards`（不施加弃置禁止，选牌不是弃置），选中牌全部通过公共 `Room:askToYiji` 分配；未使用自建分配循环。
- 每回合一次以 `usedEffectTimes(..., Player.HistoryTurn)` 判定；分配目标为其他存活角色，不包含自己。

### 突袭

- 触发时机为 `fk.DrawNCards`，在摸牌数量确定前减少 `data.n`；少摸张数等于实际选择的其他角色数。
- 依次从每名目标手牌中选择一张获得，使用 `fk.ReasonPrey`；目标中途无手牌时跳过。
- 展示为可选项；确认展示后 `room:showCards` 公开获得的牌，并调用 `OnlyAs.addSource`：
  - `def = "tuxi"`（公共定义：仅开放【杀】的 `use`/`response` 用途）；
  - `cards = 本次实际获得的实体牌集合`；
  - `duration = "turn"`；
  - 不传 `skill`，因此**失去突袭不会撤销**本回合已产生的限制，回合结束由 only-as 规则统一到期。
- 直接使用/打出这些实体牌被公共 only-as 禁止；其它来源的转化权限仍按并集保留。未在技能内自行改写牌名或添加独立“只能当”技能。

### 放逐

- 目标须为其他存活角色；先执行叠置，再摸两张。国战“叠置/平置”对应引擎的 `faceup`：平置 `faceup = true`，叠置 `faceup = false`。叠置仅在 `faceup` 为真时调用原生 `player:turnOver()`；已叠置不重复翻转，但后续摸牌与弃牌分支仍分别执行。
- 摸牌后若目标手牌+装备合计不足四张，不进入弃牌分支：不平置，也不检查牌名字数、不失去体力。
- 足够四张时，由目标决定是否弃置；`min_num = max_num = 4` 保证足额，弃牌范围含手牌与装备。弃置完成后仅在仍为叠置（`faceup = false`）时调用原生 `turnOver` 平置，再按实际弃置的四张牌逐张累计中文牌名字数（`utf8.len`），大于7则失去1点体力。
- 使用原生翻面入口，保留 `BeforeTurnOver`/`TurnedOver` 事件、翻面跳回合流程与客户端 `faceup` 朝向显示；未修改引擎本体。

## 2. 规则与接口依据

- `rules/general-principles.md` 第 9 行：“某人的牌”指手牌区和装备区，不含判定区。
- `rules/generals/wei014-caopi.md`：叠置/平置为定向操作；对已叠置目标不能把叠置执行成平置，已无法执行的一步与后续摸牌等效果分别判断。
- 公共 only-as：[only_as.lua](../../../../pkg/hanjin_mode/rules/only_as.lua) 的 `define("tuxi", ...)`、`addSource(..., duration = "turn")`、`isForbidden`、`actionsForCard`。来源不绑定技能时不会因技能/武将失去而删除。
- 公共分配：`Room:askToYiji` 与 `Room:doYiji`（“将一些卡牌同时分配给一些角色”）；持重只调用前者。

## 3. 验证文件与执行

新增 [tests/wei_support.lua](../../../../tests/wei_support.lua)，包含三个代表性集成用例：

- `testChizhongDistributesMoreThanHp`：4 体力、6 手牌时用 `askToCards` 选择 5 张全部分配，保留 1 张，验证“不是只分超额”。
- `testTuxiDrawReductionAndTurnRestriction`：2 张少摸为 0，获得两名角色各一张；展示后该牌被 only-as 禁止直接使用且提供【杀】转换；失去突袭后限制仍在。
- `testFangzhuStackDrawDiscardAndHpLoss`：平置→叠置（`faceup=true→false`）并摸2；足额弃4后平置（`faceup=false→true`）且牌名字数和>7失去体力；已有叠置目标不反转且仍摸2；不足4张时不提供弃牌分支、保持叠置。
- 行殇的判定区用例已加入既有 [tests/wei_damage.lua](../../../../tests/wei_damage.lua) 的 `testXingshangTakesCardsOrRecovers`：只有判定区牌时改为回复体力，判定区牌不移动。

执行命令：

```text
python scripts/test.py --file tests/wei_support.lua --timeout 120
python scripts/test.py --file tests/wei_damage.lua --timeout 120
```

结果：

```text
python scripts/test.py --file tests/wei_support.lua --timeout 180
Ran 3 tests in 0.787 seconds, 3 successes, 0 failures

python scripts/test.py --file tests/wei_damage.lua --timeout 180
Ran 8 tests in 1.923 seconds, 8 successes, 0 failures
```

[wei_damage.lua](../../../../tests/wei_damage.lua) 的 `initializeGenerals` 也同步采用标记后重算 `maxHp/hp` 的夹具修正，避免同一随机初始双将问题影响行殇/节命等用例。

持重间歇失败（曾报 `tests/wei_support.lua:115 expected:1 actual:6`）的确定性原因：`initializeGenerals` 调用 `changeHero` 时，`__heg_general`/`__heg_deputy` 标记仍指向本局随机初始双将；引擎 `getGeneralMaxHp()` 优先读取这两个标记，于是测试角色的 `maxHp/hp` 随初始双将变为 3 或 4（并可更高），而不是测试将面的 4。若体力值使 `max(1, hp+1)` 大于回复中的 5 张，持重会正确判定选牌不足并取消发动，`p1` 保留 6 张牌，表现为“expected 1 actual 6”。诊断时保留的证据：初始双将始终被替换为 `hanjin_test__wei_1/wei_2`，但 `hp/maxhp` 出现 3/4 两种；`player.phase = Player.NotActive`、`RoundCount = 1`、技能来源仅为 `hanjin__skill_wei003_2`；请求消费为 `"1"→askToSkillInvoke`、`ReplyChooseCards→askToCards`、`ReplyChooseCardAndPlayers→askToYiji`，逐次 q 长度 3→2→1→0，均未错位。修复：写入测试双将标记后用 `pl:getGeneralMaxHp()` 重算 `maxHp/hp`，夹具固定为 4/4；未修改断言、未禁用测试、未固定随机种子。修复后连续 10 次运行均 3/3 通过。另：放逐用例曾因施放者连续承受三次1点伤害进入濒死导致一次 `faceup` 断言失败，已固定施放者体力为 10。

## 4. 魏区牌面数据同步

本轮在持重问题解决后同步 [standard.lua](../../../../pkg/hanjin_generals/data/standard.lua) 的魏区：15 个主称号改为与 `rules/standard-generals.md` 魏区一致（含第二称号，统一简体），25 条技能原文逐条对齐。仅改动 WEI001—WEI016 的 `title` 与技能 `text`：修正应期“☯️+2”、刚烈“来源”、行殇“若其没有牌，则改为”等；其他势力数据未改。核对结果：15 主称号与 25 技能原文相对规则表差异为 0。

## 5. 未完成项与风险

- 突袭对“保留其他转化权限”仅依赖 only-as 的并集语义，未新增专项组合测试；`tuxi` 来源的回合到期依赖公共 only-as 规则技能，测试未覆盖到期。
- 行殇修正只影响取牌范围；未新增死亡结算与判定区延迟锦囊的交互测试。
