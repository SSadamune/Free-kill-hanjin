# WEI002 司马懿·鹰视：改判实现与验证

本页记录[标准武将表](../../../../rules/standard-generals.md) WEI002 鹰视的程序接线，不是正式规则条文。

## 规则要点

当一名角色的判定牌生效前，发动者可以打出一张**自己的手牌或装备牌**代替之。与普通“鬼才”不同，可用牌包含装备区的牌，不限于手牌。

## 接线

1. **时机**：`fk.AskForRetrial`，条件为拥有鹰视、存在未被禁止打出的手牌/装备牌、同一判定尚未替换过（`data.__hanjin_wei002_2_retrial`）。
2. **费用**：`room:askToSkillInvoke` 后 `room:askToCards`，候选集为手牌+装备区中 `player:prohibitResponse(card)` 为假的牌，装备区以 `expand_pile` 提供；禁止打出的牌不能选。
3. **真实打出**：现有 `room:changeJudge{response=true}` 只移牌、不产生 `CardRespond` 事件。因此先 `room:responseCard { from = player, card = card, skipDrop = true }` 完成真实打出，防止牌被默认弃置。
4. **复核与替换**：打出后复核 `room:getCardArea(id) == Card.Processing`，再调用 `room:changeJudge { card = card, player = player, data = data, skillName = ..., response = true }`；`data` 标记确保同一判定只替换一次。
5. 翻译：`hanjin__skill_wei002_2`、提示 `#hanjin__skill_wei002_2-invoke`、`#hanjin__skill_wei002_2-ask`。

## 测试（[wei_retrial.lua](../../../../tests/wei_retrial.lua)，已由整合方加入 all.lua）

1. 真实 `room:judge` 流程中替换牌成为最终判定牌；`responseCard` 与 `changeJudge` 均走真实实现，用例只固定是否发动与选择哪张牌两个输入。
2. 被 `prohibitResponse` 禁止的牌不能作为候选，不产生改判。

两个用例已由 C 会话以真实 `room:judge` 运行通过（2/2）；本轮再次真实执行：

```text
python scripts/test.py --file tests/wei_retrial.lua --timeout 180
Ran 2 tests in 0.202 seconds, 2 successes, 0 failures
```

本轮未扩大鹰视范围，未新增用例；连续 2 次运行均为 2/2（0.202–0.208 秒）。

## 未完成／风险

- 输入选择仍使用测试桩（是否发动、选哪张牌）；判定、真实打出与改判流程未用桩。
- 同一判定多次改判（多角色鹰视/鬼才）的交互未展开。
