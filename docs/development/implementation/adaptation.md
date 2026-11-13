# 应变规范：实现与验证

游戏语义见[对应规则](../../../rules/adaptation.md)；当前实装与待办见[开发状态](../status.md)。本页保留接口、接线和验收依据，不替代规则裁定，历史覆盖说明不代表已完成全部人工验收。

## 1. 源码检查和依赖结论

- 本地 FreeKill v0.5.25 的 `lua`、`ltk` 及已安装内容未发现应变条件/效果结算器；核心仅提供 `Card.extra_data` 等通用扩展接口。
- 应变篇在官方 `Qsgs-Fans/gamemode` 扩展中：`pkg/gamemodes/rule_skills/variation.lua`、`pkg/variation_cards/` 和 `pkg/gamemodes/variation.lua`。
- 已下载到 `.dev/reference/gamemode`，提交固定在 `dependencies.lock.json` 的 `references` 字段。重建可运行 `python scripts/setup_dependencies.py --references`；普通运行不依赖参考目录。
- 上游规则按单个 `{条件, 效果}` 登记，原铜雀会一次放开所有条件，不满足汉晋“一次仅忽略一项”的规则；上游接口还须按当前引擎版本核对，不能直接复制后假定兼容。
- 上游仅供核对，不安装到运行环境 `packages`，不加载其原版应变牌、武将、身份模式或全局应变技能。汉晋实现独立元数据、规则模块和事件。

## 7. 元数据与扩展 API

实现：`pkg/hanjin_mode/rules/adaptation.lua`；事件接入：`pkg/hanjin_mode/skills/adaptation.lua`。

### 卡牌或转化牌明确附带条目

```lua
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
A.setCardEntries(card, {
  { id = "skill_support", condition = "zhuzhan", effect = "execute_both" },
})
```

正式牌堆也可在独立卡牌的 `extra_data.hanjin_adaptation` 中写入同样的条目数组。未写 ID 时按 `card:序号` 自动编号；本次使用增加的条目按 `use:序号` 编号。

扩充正式牌堆时 MUST 按牌位核对应变元数据。例如，势备篇 ♠9、♠10 雷杀带有孤军，势备篇 ♠J 雷杀只有合纵，标准版一 ♣6 雷杀两者皆无。其余雷杀使用单独的牌型并沿用雷杀基础效果；新增同名牌位时须检查其实际取得的条目，避免从牌型继承孤军。

### 本次使用增添条目、给予一个忽略令牌

```lua
A.addEntry(use, { id = "skill_extra", condition = "gujun", effect = "damage" })
A.grantIgnore(use, "providing_skill", "skill_extra") -- 仅此一项
A.grantIgnore(use, "another_effect")                -- 一个令牌，未指定则选择一项
```

这些接口 MUST 在本次应变准备前调用，通常在转化牌构建或 `PreCardUse` 阶段完成。准备阶段固定条目与令牌；即使默认逐项重检条件，也不得在准备完成后偷偷增加条目或无视来源。

### 识别与后续技能监听

- `A.isAdaptationCard(card, use?)`：识别明确拥有条件和效果的牌，包括技能赋予的虚拟牌和使用级附加条目。
- `A.getResult(use)`：本次执行结果，含 `triggered`、`triggered_count`、逐项记录和效果次数。
- `A.hasEffect(use, "execute_both")`：供独立卡牌的效果实现判断是否执行两种选项。
- `A.Triggered`：每个成功条目的触发事件，数据含 `use` 和本条目的 `entry` 结果。尚未实装的刘渊、贾充等应明确区分检查“是应变牌”还是检查“本次触发应变”。
- `A.registerEffect(name, {apply = function(room, use, entry) ... end})`：注册明确的新效果。若是增减目标，须声明 `target_change = true` 并以布尔值返回是否实际改变目标。

内置效果：`draw`、`damage`、`disresponsive`、`add_target`、`remove_target`、`obtain_response_card`、`execute_both`、`ignore_times`。

其中 `execute_both` 仅提供语义标记与次数：未来【逐近弃远】等独立牌的实现 MUST 主动读取并执行两个不同选项；不得把它实现为对原效果再结算一次，也不表示本轮已创建该卡牌。

### 8.3 实现接口

- `A.ignoreTimesCandidate(room, player, card, use?)`：只读查询，供卡的 `cardskill.can_use` 和 `target_filter` 在次数已满时判断能否选择。不会锁条件或发事件。
- `A.lockIgnoreTimes(room, use)`：幂等；在 `fk.PreCardUse` 调用，记录 `use.extra_data.hanjin_adaptation_locked[entry.id]` 并按结果设置 `use.extraUse`。直接按规则 API 使用而未经过 `PreCardUse` 时，`A.prepare` 会补锁，但此时已晚于引擎记数，不能替代正式用牌路径。
- `A.conditionSatisfied(room, player, condition)`：五种条件的只读判定，供 `A.snapshot` 和选牌阶段共用；`zhuzhan` 仍需在实际结算时询问，不能提前判定。
- 卡的 `target_filter` MUST 继续执行攻击距离检查；无视次数只豁免次数，不改变距离、目标合法性或响应规则。

### 已有覆盖与剩余验收

已有回归包括：`tests/card_reuse.lua` 的逐近弃远先弃后取、水淹七军助战后先弃装备再伤害；`tests/adaptation.lua` 的增减目标取消及成功事件、单纯打出不触发应变；`tests/card_deck.lua` 的全部 16 组、35 张实体牌及具体牌位元数据。

专项回归已补齐：逐近弃远在距离 1、目标仅一张手牌或装备时通过真实助战先弃后无牌可取；实际使用孤军闪取得所响应牌的正确实体材料，纯打出不触发，并覆盖多材料、无材料及已离开处理区；富甲借刀在真实无懈与内部杀询问中均无法响应；全部 16 组、35 张实体牌的条目、提示、标记及动态牌面文本一致。

洞烛先机本身不在已确认的 16 组应变牌中，不应列为“应变执行两项”的待办。它的普通效果先观星操作牌堆顶、再摸两张，已通过真实用牌和观星请求核对牌堆／手牌顺序。`execute_both` 的专属顺序仍适用于上文的水淹七军和逐近弃远。

上述新增回归位于 `tests/card_reuse.lua` 与 `tests/card_deck.lua`。测试注入自定义应变条目时使用虚拟克隆牌及实体子牌，避免改写共享正式实体牌元数据污染后续场景。自动文本一致性不替代客户端渲染及真实联网界面的人工验收。

## 10. 现有实现的验收

`tests/mode_rules.lua` 覆盖国战公共规则与汉晋规则的实际挂接、回合开始明置主将/副将/全亮/取消、禁止明置，以及汉晋君主升变与原生转换的兼容。

`tests/adaptation_display.lua` 覆盖手牌标记与选牌提示、同名牌位隔离、多条目、虚拟牌与材料牌、标记清理和可见范围，以及五种条件的具体触发提示、失败/取消不提示、无视令牌、真实用牌入口与重复处理。

运行 `python scripts/test.py`，或单独运行 `python scripts/test.py --file tests/adaptation.lua`。

覆盖虚拟牌与使用级条目识别、五种条件、强制独立结算、默认逐项重检（条件变为不满足及变为满足）、保留统一快照策略、策略在单次使用中固定、无视令牌延后使用、重入顺序保护、一令牌一条件、两来源令牌、目标选择取消与成功事件、助战同时竞速/只弃一张/非法回复过滤/无人助战/独立助战分别付费，以及真实使用最后一张手牌的空巢检测。测试只使用独立测试内容，不创建正式武将或装备。

`tests/ignore_times.lua` 额外覆盖：正式牌包中恰好两张登记孤军→无视次数的雷杀（♠9/♠10），不表示整个牌包仅有两张可用雷杀；并覆盖雷杀身份与雷电伤害、孤军/未确定势力/有同势力存活角色、次数已满/未满、距离仍受限、选牌与选目标无副作用、PreCardUse 锁定后状态变化不改变本次结果、锁定后本次不计数、孤军失去后下一次照常计数、咆哮/连弩只绕过上限且失去状态后计数仍保留、其它条目的逐项顺序与一令牌一项。正式牌不再是测试专用内容；测试仍不创建正式武将。

尚未人工验证多人网络客户端的助战界面与取消请求展示；原生 Request 的并发与取消流程已由自动化测试调用和检查。
