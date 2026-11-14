# 判定与花色：跨势力技能实现与验证

本页是“判定与花色”机制的主记录页：判定牌替换（改判）、判定结果的处理与获得，以及花色视为与花色过滤。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。范围边界：以判定流程或花色视为为核心的技能；拼点过程本身归[拼点](pindian.md)，伤害结算归[伤害、体力与死亡](damage.md)。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| WEI002 | 司马懿 | [鹰视](#wei002-2) |
| WEI007 | 甄姬 | [洛神](#wei007-2) |
| WU011 | 小乔 | [红颜](#wu011-2) |

## 技能条目

### 魏

<a id="wei002-2"></a>
#### 鹰视（WEI002 司马懿）

- **标识与依据**：运行时 ID `hanjin__skill_wei002_2`；源码 [skill_wei002_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei002_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI002。同将[狼顾](damage.md#wei002-1)、[应期](pair-hp.md#wei002-3)。
- **实现与接口**：
  - 规则要点：一名角色的判定牌生效前，发动者可打出一张**自己的手牌或装备牌**代替之；与普通“鬼才”不同，可用牌包含装备区，不限于手牌。
  - 时机为 `fk.AskForRetrial`，条件为拥有鹰视、存在未被禁止打出的手牌／装备牌、同一判定尚未替换过（`data.__hanjin_wei002_2_retrial`）。
  - 费用：`room:askToSkillInvoke` 后 `room:askToCards`，候选集为手牌＋装备区中 `player:prohibitResponse(card)` 为假的牌，装备区以 `expand_pile` 提供；禁止打出的牌不能选。
  - 真实打出：现有 `room:changeJudge{ response = true }` 只移牌、不产生 `CardRespond` 事件，因此先 `room:responseCard { from = player, card = card, skipDrop = true }` 完成真实打出，防止牌被默认弃置；打出后复核 `room:getCardArea(id) == Card.Processing`，再调用 `room:changeJudge { card = card, player = player, data = data, skillName = ..., response = true }`，`data` 标记确保同一判定只替换一次。
  - 翻译键：`hanjin__skill_wei002_2`、提示 `#hanjin__skill_wei002_2-invoke`、`#hanjin__skill_wei002_2-ask`。
- **验证依据**：[wei_retrial.lua](../../../../tests/wei_retrial.lua) 覆盖真实 `room:judge` 流程中替换牌成为最终判定牌（`responseCard` 与 `changeJudge` 均走真实实现，用例只固定是否发动与选择哪张牌两个输入），以及被 `prohibitResponse` 禁止的牌不能作为候选、不产生改判；历史 2/2，见[共享验证证据](verification-evidence.md#wei_retrial)。
- **未完成与边界**：输入选择仍使用测试桩（是否发动、选哪张牌）；判定、真实打出与改判流程未用桩。同一判定多次改判（多角色鹰视／鬼才）的交互未展开。

<a id="wei007-2"></a>
#### 洛神（WEI007 甄姬）

- **标识与依据**：运行时 ID `hanjin__skill_wei007_2`；源码 [skill_wei007_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei007_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI007。同将倾国见[转化与生成用牌](conversion.md#wei007-1)。
- **实现与接口**：
  - 准备阶段判定；黑色可重复，全部判定结束后统一获得黑色判定牌。
  - 使用 `Room:judge`：其返回值不是 `JudgeData`，判定结果写回传入的 spec 表（`TriggerData:_data` 包装），因此调用后读取原表；循环结束后只收集仍在处理区／弃牌堆的黑色判定牌，一次 `obtainCard` 统一移动。
  - 记录本次流程最终生效的黑色判定牌（含改判后的判定牌），全部判定结束后统一获得，修正了上游逐次 `FinishJudge` 入手的写法，并修正对 `room:judge` 返回值的假设。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖洛神连续两次黑色后红桃终止、`AfterCardsMove` 探针确认黑色判定牌只产生一次得到移动、共两张；历史 14/14。
- **未完成与边界**：客户端判定展示与获得提示未人工验收。

### 吴

<a id="wu011-2"></a>
#### 红颜（WU011 小乔）

- **标识与依据**：运行时 ID `hanjin__skill_wu011_2`；源码 [skill_wu011_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu011_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU011。同将天香见[伤害、体力与死亡](damage.md#wu011-1)。
- **实现与接口**：覆盖手牌、装备牌及判定牌的锁视过滤；供天香等按有效花色判定。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖天香／红颜组合；历史 22/22，见[共享验证证据](verification-evidence.md#wu_damage)。
- **未完成与边界**：红颜失技／交换后的实际客户端刷新、少见红颜／禁弃组合未独立验收；客户端点击、联网／重连未人工验证。
