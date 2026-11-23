# 判定与花色：跨势力技能实现与验证

本页是“判定与花色”机制的主记录页：判定牌替换（改判）、判定结果的处理与获得，以及花色视为与花色过滤。不替代规则条文，规则冲突时以 `docs/rules/` 与 `rulebook/` 为准。范围边界：以判定流程或花色视为为核心的技能；拼点过程本身归[拼点](pindian.md)，伤害结算归[伤害、体力与死亡](damage.md)。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| WEI002 | 司马懿 | [鹰视](#wei002-2) |
| WEI007 | 甄姬 | [洛神](#wei007-2) |
| WU011 | 小乔 | [红颜](#wu011-2) |
| QUN010 | 张角 | [鬼道](#qun010-2) |
| QUN012 | 蔡文姬 | [悲歌](#qun012-1) |

## 技能条目

### 魏

<a id="wei002-2"></a>
#### 鹰视（WEI002 司马懿）

- **标识与依据**：运行时 ID `qiao__skill_wei002_2`；源码 [skill_wei002_2.lua](../../../../pkg/qiao_generals/skills/skill_wei002_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI002。同将[狼顾](damage.md#wei002-1)、[应期](pair-hp.md#wei002-3)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L4824)。

> 当一名角色的判定牌生效前，你可以打出一张牌代替之。

- **实现与接口**：
  - 规则要点：一名角色的判定牌生效前，发动者可打出一张**自己的手牌或装备牌**代替之；与普通“鬼才”不同，可用牌包含装备区，不限于手牌。
  - 时机为 `fk.AskForRetrial`，条件为拥有鹰视、存在未被禁止打出的手牌／装备牌、同一判定尚未替换过（`data.__qiao_wei002_2_retrial`）。
  - 费用：`room:askToSkillInvoke` 后 `room:askToCards`，候选集为手牌＋装备区中 `player:prohibitResponse(card)` 为假的牌，装备区以 `expand_pile` 提供；禁止打出的牌不能选。
  - 真实打出：现有 `room:changeJudge{ response = true }` 只移牌、不产生 `CardRespond` 事件，因此先 `room:responseCard { from = player, card = card, skipDrop = true }` 完成真实打出，防止牌被默认弃置；打出后复核 `room:getCardArea(id) == Card.Processing`，再调用 `room:changeJudge { card = card, player = player, data = data, skillName = ..., response = true }`，`data` 标记确保同一判定只替换一次。
  - 翻译键：`qiao__skill_wei002_2`、提示 `#qiao__skill_wei002_2-invoke`、`#qiao__skill_wei002_2-ask`。
- **验证依据**：[wei_retrial.lua](../../../../tests/wei_retrial.lua) 覆盖真实 `room:judge` 流程中替换牌成为最终判定牌（`responseCard` 与 `changeJudge` 均走真实实现，用例只固定是否发动与选择哪张牌两个输入），以及被 `prohibitResponse` 禁止的牌不能作为候选、不产生改判，见[共享验证证据](verification-evidence.md#wei_retrial)。
- **未完成与边界**：输入选择仍使用测试桩（是否发动、选哪张牌）；判定、真实打出与改判流程未用桩。同一判定多次改判（多角色鹰视／鬼才）的交互未展开。

<a id="wei007-2"></a>
#### 洛神（WEI007 甄姬）

- **标识与依据**：运行时 ID `qiao__skill_wei007_2`；源码 [skill_wei007_2.lua](../../../../pkg/qiao_generals/skills/skill_wei007_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)魏区 WEI007。同将倾国见[转化与生成用牌](conversion.md#wei007-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L4936)。

> 准备阶段，你可以判定，若为黑色，你可以重复此流程。然后你获得所有黑色的判定牌。

- **实现与接口**：
  - 准备阶段判定；黑色可重复，全部判定结束后统一获得黑色判定牌。
  - 使用 `Room:judge`：其返回值不是 `JudgeData`，判定结果写回传入的 spec 表（`TriggerData:_data` 包装），因此调用后读取原表；循环结束后只收集仍在处理区／弃牌堆的黑色判定牌，一次 `obtainCard` 统一移动。
  - 记录本次流程最终生效的黑色判定牌（含改判后的判定牌），全部判定结束后统一获得，修正了上游逐次 `FinishJudge` 入手的写法，并修正对 `room:judge` 返回值的假设。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖洛神连续两次黑色后红桃终止、`AfterCardsMove` 探针确认黑色判定牌只产生一次得到移动、共两张。
- **未完成与边界**：客户端判定展示与获得提示未人工验收。

### 吴

<a id="wu011-2"></a>
#### 红颜（WU011 小乔）

- **标识与依据**：运行时 ID `qiao__skill_wu011_2`；源码 [skill_wu011_2.lua](../../../../pkg/qiao_generals/skills/skill_wu011_2.lua)。规则见[标准武将表](../../../rules/standard-generals.md)吴区 WU011。同将天香见[伤害、体力与死亡](damage.md#wu011-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L6231)。

> 锁定技，你的黑桃牌和黑桃判定牌视为红桃牌。

- **实现与接口**：手牌区、装备区及当次判定牌按有效花色处理，判定区里的牌维持原花色，见[自己的牌](../../../../rulebook/terms/description-terms/limit_card.md)。锁视入口与锁定国战包 `pkg/standard/skills/hongyan.lua` 一致，使用 `Fk:cloneCard` 保留注册包，并复制汉晋实体牌的 `extra_data`，保留应变、牌位等信息。汉晋牌面只规定花色变化。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 专项 23/23，覆盖天香／红颜组合，以及正常回复使用实体黑桃 9 雷【杀】时的红桃花色、牌包音效、实体应变信息、雷伤害及弃牌。
- **未完成与边界**：红颜失技／交换后的实际客户端刷新、少见红颜／禁弃组合未独立验收；客户端点击、联网／重连未人工验证。

### 群

<a id="qun010-2"></a>
#### 鬼道（QUN010 张角）

- **标识与依据**：运行时 ID `qiao__skill_qun010_2`；源码 [skill_qun010_2.lua](../../../../pkg/qiao_generals/skills/skill_qun010_2.lua)。规则见[张角规范](../../../rules/generals/qun010-zhangjiao.md)。同将雷击见[伤害、体力与死亡](damage.md#qun010-1)。

牌面原文见[石激桑资料](../../../../assets/docs/石激桑武将列表.json#L2727)。

> 当一张判定牌生效前，你可以打出一张黑色牌替换之。

- **实现与接口**：`fk.AskForRetrial` 时从手牌或装备区选一张黑色、未被禁止打出的牌，先走真实 `responseCard` 完成打出（跳过默认弃置），再 `changeJudge{exchange=true}` 替换判定牌并把原判定牌交给张角；`response=true` 只指定移动原因，不产生完整打出事件，不能省去 `responseCard`。
- **验证依据**：用一个可取消的 `askToCards` 请求列出黑色手牌和装备。`include_equip` 允许客户端点选装备，确认后按当前牌区和打出限制复核。[qun_retrial.lua](../../../../tests/qun_retrial.lua) 覆盖取消时原判继续、点选黑色装备后改判并获得原判定牌，以及红牌不进入请求。
- **未完成与边界**：其他改判者竞争、打出牌被中途移动、装备区最后一牌等边界未穷举；客户端改判提示未人工验收。

<a id="qun012-1"></a>
#### 悲歌（QUN012 蔡文姬）

- **标识与依据**：运行时 ID `qiao__skill_qun012_1`；源码 [skill_qun012_1.lua](../../../../pkg/qiao_generals/skills/skill_qun012_1.lua)。规则见[标准武将表](../../../rules/standard-generals.md)群区 QUN012。同将断肠见[伤害、体力与死亡](damage.md#qun012-2)。

牌面采用[项目登记](../../../../pkg/qiao_generals/data/standard.lua)的文字，与[石激桑原记录](../../../../assets/docs/石激桑武将列表.json#L2767)有差异，采用依据与边界见[项目规则](../../../rules/standard-generals.md)。

> 当一名角色受到【杀】造成的伤害后，你可以弃置一张牌，然后令其判定，若为：<br>红桃，其回复1点体力；方片，其摸两张牌；<br>梅花，来源弃置两张牌；黑桃，来源叠置。

- **实现与接口**：角色受到【杀】造成的伤害后，蔡文姬弃一张牌，令受伤角色走正式判定（鬼道可改判）；红桃其回复 1 点，方片其摸两张，梅花伤害来源弃两张，黑桃伤害来源定向叠置。叠置仅平置→叠置，已叠置不翻回；来源缺失或已死亡时该分支不执行。
- **验证依据**：已执行 [qun_judgement.lua](../../../../tests/qun_judgement.lua) 的 `testBeigeHeartRecoversDamagedPlayer`、`testBeigeSpadeStacksSourceWithoutFlippingBack`。历史批次见[验证记录](verification-evidence.md#qun-standard)。
- **未完成与边界**：方片／梅花分支、无来源伤害、来源中途死亡未逐项覆盖；客户端判定与弃牌未人工验收。
