# JIN001 司马炎：垂统、兴图实装与验证

游戏语义见[对应规则](../../../../rules/generals/jin001-simayan.md)及[装备移动通则](../../../../rules/equipment-movement.md)。本页只记录接口、接线和真实验证结果，不替代规则裁定。当前完成度与全局待办仍由[开发状态](../../status.md)维护。

## 1. 实装范围

| 技能 | 文件 | 入口 |
| --- | --- | --- |
| 垂统 | `pkg/hanjin_generals/skills/skill_jin001_1.lua` | `fk.EnterDying` |
| 兴图 | `pkg/hanjin_generals/skills/skill_jin001_2.lua` | `fk.TurnEnd`、全局 `fk.PreTurnStart` / `fk.AfterCardUseDeclared`、辅助主动技 `#hanjin__skill_jin001_2_active` |

两技能已在 `pkg/hanjin_generals/init.lua` 的正式实装例外白名单登记；`tests/standard_generals.lua` 的同一白名单和事实断言同步更新。默认国战套件由 `tests/all.lua` 接入 `tests/jin001_simayan.lua`。

## 2. 垂统

1. 在 `fk.EnterDying` 提供一次发动机会，`target` 为进入濒死的其他角色；`target == player` 直接排除，不按敌友或势力筛选。未改为监听求桃，因此同一濒死流程不会按求桃次数反复触发。
2. 候选牌只取该角色装备区中 `target:canMoveCardInBoardTo(player, id)` 为真的牌。该锁定引擎接口检查目标栏存在、未废除且为空，并排除目标为自己；已有同类装备、废除栏或无牌时 `can_trigger` 不成立。
3. 发动者从复核后的候选牌中选择一张（`Room:askToChooseCard`，候选以 `$Equip` 列表给出）。选择后再次复核来源归属、双方存活与 `canMoveCardInBoardTo`，再调用 `Room:moveCardIntoEquip(player, card, skill, false, target)`。`convert = false` 保证不替换目标已有装备；移动进入对应空栏而非手牌，并按正常移牌触发失去/得到装备结算。
4. 发动在 `askToSkillInvoke` 处可取消；取消、候选为空或复核失败时不移动。

## 3. 兴图

### 3.1 本回合应变牌使用事实

- 使用一个不要求当前拥有兴图的全局 `fk.PreTurnStart` 效果，在每个回合开始时把房间标记 `hanjin_jin001_2_adaptation_used` 置为 `false`；下一回合不会继承上一回合的事实。真实连续回合回归见 `tests/jin001_simayan.lua` 的 `testXT03bRealTurnPreTurnStartClearsFact`。用户报告的八卦阵路径未复现，未保留无证据的回合序号补丁。
- 全局 `fk.AfterCardUseDeclared` 效果以 `A.isAdaptationCard(data.card, data)` 判断使用级应变牌：只检查本次实际使用的牌/使用数据，不把实体材料牌的应变条目或 `Adaptation.Triggered` 成功事件当作使用事实。任意角色使用均记录，条件是否满足、是否成功触发不影响该事实。
- 记录效果在技能尚未获得、暗置或后来获得技能时仍然存在，因为它是与兴图同骨架的全局触发效果，不依赖 `player:hasSkill`。
- 纯“打出”走 `RespondCard`，不经过使用牌事件，因此不计入。

### 3.2 回合结束选择与两项执行

`fk.TurnEnd` 对每名角色（包括自己）的回合结束检查房间标记；技能有效且本回合序号匹配时，只发起一次 `askToChoice`，直接给出“将一张装备牌当【桃】对一名角色使用”“摸一张牌”和取消。分支选择在 `on_cost` 中完成并写入 `event:setCostData(self, { choice = ... })` 传给 `on_use`；取消返回 `false`，不进入 `SkillEffect`，因此不摸牌、不用牌、不消耗，也不明置技能来源或计为发动。第一项不合法时只提供摸牌与取消。

1. **当【桃】使用装备牌**：辅助主动技 `#hanjin__skill_jin001_2_active` 只允许选择自己手牌区或装备区中的装备牌（`card_num = 1`、`include_equip = true`、`card_filter` 检查归属与 `Card.TypeEquip`），目标按“一名角色”提供，包括自己和其他角色。选择结果回到服务端后再次复核材料归属/类型、目标存活及 `player:isProhibited`，然后调用公共 `C.useVirtualCard`，以 `C.explicit({})` 替换普通【桃】的牌面目标条件，并把 `skillName` 记为兴图。实际进入一次完整用牌流程，由【桃】自身效果回复体力，不直接 `recover`。
2. **摸一张牌**：直接 `drawCards(1, skill.name)`，不要求拥有装备牌。
3. 第一项没有合法装备/目标时，只提供第二项；任一项都可取消。选择第一项后在选牌/选目标处取消，不摸牌、不使用、不移动。

### 3.3 客户端

第一项的选牌与目标使用真实 `AskForUseActiveSkill` 请求，客户端为真实 `ClientPlayer`（`handler.player`），由辅助技的 `card_filter` / `target_filter` 提供候选与禁用状态。测试通过请求断点验证装备牌可选、非装备牌不可选、目标可选。该测试夹具只向这个真实客户端自己的手牌表补入本次请求涉及的装备牌，因为测试用假后端不会把后续房间的移牌通知重放进长期存活的客户端实例；不使用 ServerPlayer 复制体替代请求处理器或目标查询。

## 4. 真实验证

常规专项验收入口：

```text
python scripts/test.py --file tests/jin001_simayan.lua --timeout 120
```

最近一次由 DSH 直接通过同一 runtime 的 `FreeKill.exe --testfile` 执行专项（当时用户正在运行游戏，未重复同步运行环境），结果为 `Ran 17 tests ... 17 successes, 0 failures`。覆盖：

- 垂统：其他角色进入濒死时移入空置对应栏且非手牌；同类栏已占用、废除栏、无牌、取消、自己濒死均不移动；`hp = 0` 的完整濒死流程只提供一次发动；主将、副将、暗置预亮来源均验证。
- 兴图：无应变用牌/普通牌/纯打出不触发；其他角色在本回合使用应变牌、条件未成功触发也计数；用牌发生在获得技能之前仍计入；下一回合清空；任意角色回合结束可发动；摸牌项与拒绝；第一项用手牌或装备区装备作材料、对受伤或其他满体力角色完整使用一次【桃】，材料离区且 `skillName` 为兴图；无合法装备时只提供摸牌项；主将、副将、暗置来源。
- 客户端：真实 `ClientPlayer` 请求处理器中装备牌/非装备牌与目标的可选性。

默认全量套件通过 507/507；安装包已构建。最近完整验证记录见[开发状态](../../status.md)。未应用开发适配的本体人工交互验收尚未执行。全局记录以使用牌事件为准，未覆盖“无任何目标但被使用”的边缘牌型，后续如出现具体用例再补。

用户曾报告“应变牌后的下一回合，敌方普通杀→八卦阵视为闪，兴图误触发”，自动化未能复现；真实连续回合回归及虚拟闪无应变条目检查通过。2026-11-13 用户复测确认已无异常，该反馈关闭；不据此追认具体根因，也未保留无复现依据的回合序号补丁。用户同时确认本轮界面调整无异常；该复测不代表完整联网、重连或未应用开发适配的独立本体验收。

## 5. 待办：规范化描述

- [ ] 编写垂统、兴图各自的规范化描述，使用规则集定义的术语与结构，精确表达时机、条件、消耗和效果，并核对项目已确认裁定与实际代码。
- [ ] 将审定后的规范化描述纳入《汉晋规则集》对应武将资料；保留面向玩家的卡面描述。本页的实现说明及 `rules/generals/jin001-simayan.md` 的结算约定均不替代规范化描述，未决裁定须明确标注。
