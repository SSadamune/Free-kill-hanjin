# 受伤、伤害与死亡触发：跨势力机制实现与验证

本页汇总汉、魏两包中与受伤、造成伤害、伤害修正及死亡触发相关的技能实现、接口接线与真实验证状态，不替代规则条文。逐将检索见[汉势力标准包](han-standard.md#1-分组与逐将入口)与[魏势力标准包](wei-standard.md#1-分组与逐将入口)；整将记录按主要机制放入对应组，其他组只以锚点引用，不复制正文。

## 魏势力标准包

本页记录 WEI001 奸雄、WEI002 狼顾、WEI003 刚烈、WEI005 裸衣、WEI006 遗计、WEI013 节命、WEI014 行殇、WEI016 骁果的最小可运行实现、引擎接线与定向验证，不替代规则裁定。技能原文见[标准武将表](../../../../rules/standard-generals.md)魏区；已确认差异见[rules/generals/](../../../../rules/generals/)（本轮适用 [WEI016 乐进·骁果](../../../../rules/generals/wei016-yuejin.md)）。源码接口按锁定运行时 0.5.25 与 hegemony `e8d93acd34a3` 核对，`rules/`、`rulebook/`、外部资料与公共文件未改。

### 1. 本轮范围

| 技能 | 运行时 id | 源码 | 时机与要点 |
| --- | --- | --- | --- |
| 奸雄 | `hanjin__skill_wei001_1` | [skill_wei001_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei001_1.lua) | `fk.Damaged`；先摸一张，再可足额弃一张牌（手牌/装备，不含判定区）取得仍在处理区的伤害牌 |
| 狼顾 | `hanjin__skill_wei002_1` | [skill_wei002_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei002_1.lua) | `fk.Damaged`；获得来源一张手牌/装备牌；来源为自己时只取装备区，与既有反馈类公共处理一致 |
| 刚烈 | `hanjin__skill_wei003_1` | [skill_wei003_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei003_1.lua) | `fk.Damaged`；判定红色对来源造成1点普通伤害，黑色弃置来源一张牌；来源离场后不再执行对应分支 |
| 裸衣 | `hanjin__skill_wei005_1` | [skill_wei005_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei005_1.lua) | `fk.EventPhaseEnd`（摸牌阶段）弃一张牌；`fk.DamageCaused` 延时效果按回合标记给【杀】/【决斗】伤害+1 |
| 遗计 | `hanjin__skill_wei006_2` | [skill_wei006_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei006_2.lua) | `fk.Damaged` 每次伤害事件一次；看牌堆顶两张，先选1~2张给一名角色，剩余再给一名角色，不做上游式任意循环分配 |
| 节命 | `hanjin__skill_wei013_2` | [skill_wei013_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei013_2.lua) | `fk.Damaged` + `trigger_times = data.damage`；每个伤害点分别询问目标并摸至 `min(体力上限,5)` 张手牌 |
| 行殇 | `hanjin__skill_wei014_1` | [skill_wei014_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei014_1.lua) | `fk.Death`（弃置其牌之前）；获得死亡角色的手牌与装备牌（“某人的牌”不含判定区）；其没有牌时回复1点体力 |
| 骁果 | `hanjin__skill_wei016_1` | [skill_wei016_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei016_1.lua) | `fk.EventPhaseStart`（其他角色准备阶段）；弃置至少一张基本牌为消耗，目标弃置等量装备（不足全弃），实际基本数>装备数则造成1点伤害，否则摸一张 |

### 2. 接线与公共机制

- 8 个技能骨架均在源码内显式 `hanjinImplemented = true`；[init.lua](../../../../pkg/hanjin_generals/init.lua) 的既有无 effect 断言据此放行，无需改 `init.lua`、`data/standard.lua` 或公共测试文件。
- 主副将、明暗置、势力来源：技能均以 `player:hasSkill(技能名)` 判定当前是否持有；效果通过玩家自身技能、牌与事件结算，不依赖服务端私有字段。技能的来源武将、称号与描述继续由 `data/standard.lua` 统一注册。
- 客户端可见性：选牌/选目标使用 `askToDiscard`、`askToChooseCard`、`askToChoosePlayers`、`askToChooseCardsAndPlayers` 等正式请求接口；遗计以 `expand_pile` 展示牌堆顶两张。裸衣的回合标记只服务端判定，不使用 `@@` 展示标记。
- 裸衣效果独立于技能存在：延时效果通过回合标记与 `fk.DamageCaused` 结算，不检查 `hasSkill`；标记命名为 `hanjin_wei005_luoyi-turn`，不以技能名前缀开头，避免武将交换把它当成来源技能标记迁走，回合结束由 `-turn` 后缀清理。
- 节命保留引擎逐次调度：没有拆分伤害事件，也没有在 `on_use` 内循环；`trigger_times` 直接取 `data.damage`。
- 骁果遵循已确认消耗规则：弃置基本牌须至少一张，`skip = true` 后在 `on_use` 统一移动；目标装备不足时全弃、无装备不弃；伤害比较用实际弃置张数。

### 3. 定向验证

测试文件：[tests/wei_damage.lua](../../../../tests/wei_damage.lua)（本轮未改 [all.lua](../../../../tests/all.lua)，由 Codex 统一并入默认国战套件）。

```text
python scripts/test.py --file tests/wei_damage.lua --timeout 180
Ran 8 tests in 1.923 seconds, 8 successes, 0 failures
```

覆盖：奸雄摸牌+弃牌取得伤害牌；狼顾取得来源牌；刚烈红/黑两分支；裸衣失去技能后本回合加伤仍生效；遗计一次2点伤害只发动一次且分两次给牌；节命2点伤害逐点发动两次；行殇取得死亡角色手牌与装备牌及无牌回复；骁果基本数多于装备数造成伤害、相等时摸牌。

行殇用例直接触发 `fk.Death`（真实死亡事件类与真实请求/回复），未经过完整的 `killPlayer` 死亡结算链；完整死亡、奖惩与客户端界面仍是未验证边界。

### 4. 未完成项与边界

- 最终默认全量已由 DSH 工具原生检查确认 608/608 通过，包含本组 8 项；逐项客户端人工交互仍待验收。
- 本组已接入 [all.lua](../../../../tests/all.lua) 默认国战套件。
- 未做真实客户端 QML 交互（选牌、选目标、确认/取消）与明暗置、主副将来源切换的人工验收。
- 遗计使用 `getNCards(2)` 读取牌堆顶两张（该接口只读取、不移入处理区），选择对话框以 `expand_pile` 展示这两张，再按两次分配从牌堆移动到目标手牌；未新增仅客户端可见的私有展示层。
- 行殇在 `fk.Death` 取得死亡角色的手牌与装备牌；判定区牌不移动，只有判定区牌的死亡角色按“没有牌”回复体力。未展开与白银狮子等死亡时失去装备触发之间的完整时序回归。

## 汉势力标准包

汉包何进的构难（死亡后普通【杀】造成或受到伤害 +1）与伏皇后惴恐的伤害防止分别随整将记录见[主动、用牌与目标 HAN005](active.md#han005)及[拼点 HAN008](pindian.md#han008)，本组不重复。

<a id="han011"></a>

### HAN011 唐姬：哀舞、诀别实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

游戏语义见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN011；本页记录接口、接线与验收依据，不替代规则裁定。当前完成度由[开发状态](../../status.md)统一登记。

#### 1. 实现结构

- `pkg/hanjin_generals/skills/skill_han011_1.lua`：哀舞，`fk.Damaged` 触发。
- `pkg/hanjin_generals/skills/skill_han011_2.lua`：诀别，`fk.Death` 触发。
- 两个骨架均显式赋 `hanjinImplemented = true`，不改 `init.lua` 白名单或 `data/`。

#### 2. 哀舞

- 触发效果设 `global = true`（对其他角色的伤害事件生效）；以 `fk.Damaged` 的伤害事件为单位，每次伤害事件只触发一次，不按 `data.damage` 点数重复触发；`can_trigger` 以 `usedSkillTimes(..., Player.HistoryTurn) == 0` 实现每回合限一次。
- 自己的弃牌是发动消耗：`on_cost` 以 `askToDiscard(skip=true)` 只选牌，`on_use` 在技能明置后按固定细节支付并继续；取消选牌即不发动。可弃牌数排除被禁止弃置的牌。
- 受伤角色随后可以弃置至少一张（可选，取消不影响已支付的消耗）；两处弃牌数合计 `>= 3` 时，双方各回复 1 点体力。弃牌均含装备区，不额外套用“禁止弃置”以外的限制。
- 受伤角色在结算中死亡/离场则跳过其后续弃牌；回复前再次检查双方仍在场。

#### 3. 诀别

- 时机为 `fk.Death` 且效果 `global = true`（其他角色死亡也能触发）：位于 `GameOverJudge` 之后、`BuryVictim` 清牌之前。国战公共流程已在 `GameOverJudge` 翻开暗置武将，因此暗将死亡按翻转后的实际势力判断。
- 触发者（`player`）为唐姬；发动、选项和受益者均由死亡角色（`target`）选择：「获得其所有牌」或「摸三张牌」；受益者为另一名与唐姬势力相同的存活角色，排除死亡角色本人。唐姬自己死亡时同样按此定义处理，比较对象包含自身。
- 「所有牌」取死者手牌区和装备区（`getCardIds("he")`）；在 `on_use` 中于清牌前用 `obtainCard` 移动，未获得的判定区牌等随正常死亡流程清理。
- 同势力判断使用 `compareKingdomWith`。其他角色 `unknown` 一律不是同势力；只有技能持有者自己暗置时，才为发动本技能作必要的自身势力预测。不硬编码“只限其他角色”，多份来源交由公共触发次序处理。
- 死亡角色可能已 `dead`，发动/选项/选目标请求仍按其客户端身份发出，不用存活角色代替。

#### 4. 验证范围

定向套件 `tests/han011_tangji.lua`：

| 用例 | 核心断言 |
| --- | --- |
| 哀舞合计 3 | 自己弃 2、伤者弃 1，双方各回复 1；同回合第二次受伤因限次不再触发 |
| 哀舞合计不足 3 | 自己弃 1、伤者弃 1，不回复 |
| 诀别他人死亡 | 同势力死者选“获得其所有牌”，受益者获得手牌与装备，清牌前完成 |
| 诀别自己死亡 | 唐姬自己死亡仍触发，同势力受益者摸三张 |

公共伤害、弃牌、死亡清理与发动请求复用现有覆盖；测试通过真实 `fk.Damaged`/`fk.Death` 与真实请求回复触发，不只手调 `on_use`。

#### 5. 执行状态

- **测试待基础组集成执行**：本轮未启动 FreeKill、未运行 `scripts/test.py`、未部署共享 runtime；行为用例尚无命令输出，不宣称验收通过。
- 已执行静态解析（`scripts/check_lua.py`，运行时自带 Lua 5.4）：相关文件均为 `OK`。
- 定向命令（由基础组执行）：`python scripts/test.py --file tests/han011_tangji.lua --timeout 120`。
- 套件尚未加入 `tests/all.lua`（本轮禁止修改该文件）。

#### 6. 未覆盖与风险

- 诀别在死亡角色没有手牌/装备时仍可选择“获得其所有牌”，实际不发生移动；规则未禁止零张选择，未另设“至少一张”。
- 唐姬暗置且尚未完成势力判定时，势力回退使用 `__heg_kingdom` 标记；若公共明置/转野流程改变判定，应以公共接口为准。
- 多份诀别/哀舞来源的触发先后完全依赖公共触发顺序，本实现不自建排序。
