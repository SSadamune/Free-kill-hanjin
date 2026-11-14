# 翼从专属技能：跨势力实现与验证

本页汇总汉、魏、吴三包关联翼从的专属技能实现、接口依据与真实验证状态；统领能力仍见[统领与翼从](../commander-retinue.md)。逐将检索见[汉势力标准包](han-standard.md#1-分组与逐将入口)与[魏势力标准包](wei-standard.md#1-分组与逐将入口)；整将记录按主要机制放入对应组。

## 魏势力标准包

本页记录三张魏关联翼从的技能实现、接口依据与验证状态，不替代规则条文。规则来源：[标准武将表](../../../../rules/standard-generals.md) 翼从表及[统领与翼从](../../../../rules/commander-retinue.md)。本轮已真实运行定向测试，3/3 通过。

### 1. 文件

| 翼从 | 技能文件 | 规则文本 |
| --- | --- | --- |
| 并州狼骑 | [retinue_skill_bingzhou_langqi.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_bingzhou_langqi.lua) | 出牌阶段限一次，令一名其他角色视为对你使用【决斗】，本回合你与其距离视为1 |
| 虎卫军 | [retinue_skill_huweijun.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_huweijun.lua) | 每回合结束时，若本回合共计造成和受到过的伤害数大于1，可以移动场上一张牌 |
| 牛金 | [retinue_skill_niujin.lua](../../../../pkg/hanjin_generals/skills/retinue_skill_niujin.lua) | 同势力角色回合结束时，可使用每种类别至多各一张牌；以此法杀死角色后摸三张牌 |

定向测试：[wei_retinues.lua](../../../../tests/wei_retinues.lua)（已执行，3/3）。

### 2. 实现要点

- 并州狼骑：主动技不依赖骨架次数限制，active `can_use` 用 `usedSkillTimes(..., Player.HistoryPhase)` 限制每阶段一次，`on_use` 不再次拒绝已记录的本次发动。距离关系改为双方 `@[hanjin_bingzhou_pairs]` 表标记，支持多来源/多持有者；距离状态技为随包加载的独立骨架 `retinue_skill_bingzhou_distance.lua`（服务端/客户端同一对象），回合末由房间级清理监听移除状态技并清标记。
- 虎卫军：`fk.TurnEnd` 为全局触发，不限于自己回合；用 `logic:getActualDamageEvents` 读取实际伤害（排除被防止），`data.from == player` 与 `data.to == player` 分别累加，自己对自己的伤害计两份。满足后复用阶段组 `wei_phases.moveCardInBoard`。测试在真实 `GameEvent.Turn` 内制造伤害，避免伪造回合历史。
- 牛金：`fk.TurnEnd` 全局触发，目标为同势力角色（含自己）；不设固定类别顺序，每次由玩家选择未用类别或结束，逐次调用 `room:askToUseCard`，每项可取消。效果内用牌 `bypass_times=true`、`extraUse=true`，正常禁止与目标条件照常。来源写入本次 `use.extra_data`；房间级奖励监听在 `fk.Death` 中向上追溯 `GameEvent.UseCard` 的 `extra_data`，仅在本次窗口用牌击杀时摸三张，不依赖持有者之后是否仍有技能。测试先断言技能/同势力/实际用牌，再断言击杀奖励。
- 并州狼骑 `on_use` 不再二次检查 `usedSkillTimes`（引擎在进入 on_use 前已记次，二次检查会吞掉本次发动）；次数由 active `can_use` 的发动历史限制。

### 3. 验证状态

- 本轮真实执行（2026-11-14）：

```text
python scripts/test.py --file tests/wei_retinues.lua --timeout 180
Ran 3 tests in 0.783 seconds, 3 successes, 0 failures
```

- 通过：并州狼骑（真实【决斗】使用者/目标、双向距离、每阶段一次）；虎卫军（真实回合内伤害后移动场上一张牌）；牛金（真实用【杀】击杀不同势力角色，牛金奖励恰好一次 3 张，另加标准国战击杀奖励 1 张，总手牌 4）。
- 牛金此前 `expected 3 actual 25` 的根因：房间级 global refresh 会按每名角色回调，`can_refresh` 未限定 `player == data.killer`，8 人各触发一次 3 张（24），再加正常国战击杀奖励 1 张，合计 25。已限定 `player == killer` 且存活；测试新增 AfterCardsMove 只读探针按 `move.skillName == NJ` 统计恰好一次、恰好 3 张，并断言总手牌 = 正常奖励 1 + 牛金 3。
- [wei_phases.lua](../../../../tests/wei_phases.lua) 同轮 14/14 通过（设变、巧变请求级用例含在内）。
- 默认套件与发布包：`python scripts/test.py --timeout 180` → `Ran 608 tests in 96.407 seconds, 608 successes, 0 failures`；`python scripts/build_release.py` → `.dev/dist/hanjin.zip (446 files)`。

### 4. 未完成与风险

- 并州狼骑的距离状态技双方挂载/回合末移除、以及客户端距离显示需要实际运行与客户端验证。
- 虎卫军已通过真实回合内伤害用例；真实客户端移牌面板未人工验收。

## 汉势力标准包

<a id="han-retinues"></a>

### HAN 翼从：穆顺、西园军实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

规则依据：[标准武将表](../../../../rules/standard-generals.md)翼从两行、[统领与翼从](../../../../rules/commander-retinue.md)、[移动事件](../../../../rulebook/events/move-card.md)、[弃置](../../../../rulebook/terms/card-op-terms/discard.md)、[展示](../../../../rulebook/terms/card-op-terms/showCards.md)。本页只记录接口与验收依据；翼从取得流程由统领公共规则负责。

#### 1. 实现结构

- `pkg/hanjin_generals/skills/retinue_skill_mushun.lua`：穆顺。
- `pkg/hanjin_generals/skills/retinue_skill_xiyuanjun.lua`：西园军。
- 两个骨架均显式赋 `hanjinImplemented = true`；不改 `init/data/tests/all`，不新增客户端补丁。

<a id="mushun"></a>

#### 2. 穆顺

- 监听真实 `fk.AfterCardsMove`：只认 `moveReason == fk.ReasonDiscard` 且目标为弃牌堆的移动；重铸、给牌等不计。
- 分别按真实移动数据判断：`move.proposer == 穆顺` 为自己弃置任意角色的牌（含自己主动弃自己的牌）；`move.from == 穆顺` 且 `proposer` 为其他角色为被其他角色弃置。不按技能名或猜测的弃牌者判断。
- 结算时重新检查候选牌仍在弃牌堆，才允许选择；用 `askToCards` 的 `expand_pile` 展示弃牌堆候选，取得后才写本回合限制标记。
- 取得成功后才建立 `-turn` 的“下一次同条件弃牌失 1 点体力”标记；该罚效果由房间级延迟监听器读取角色标记，不要求穆顺当前仍有技能。
- 罚监听只判断“是否发生了符合条件的弃置”，不要求牌仍在弃牌堆：即使该次弃置的牌已被同优先级技能取走，仍失血。取得事件本身用事件标识抑制同一事件刚建立的罚效果，避免重复扣血。
- 取得次数标记以技能名开头，随翼从武将迁移；罚标记附在角色身上、不带技能前缀，避免误迁。每回合取得一次由 `-turn` 标记限制。

<a id="xiyuanjun"></a>

#### 3. 西园军

- `fk.EventPhaseStart` 以普通 `global + can_trigger + on_cost + on_use` 处理：触发条件是与西园军同势力的角色出牌阶段开始；当前阶段角色可以没有手牌。
- 被选牌角色是“一名角色”，候选为全场有手牌的合法角色，不限制与西园军同势力（可选敌方，也可选当前空手的阶段角色以外的角色）。先选角色，再用 `askToChooseCard(flag="h")` 由引擎隐藏选牌；返回值用 `Card:getIdList` 规范化为单个 id，兼容 Card/ID/数组。
- 每个西园军 owner 各自独立处理同一事件，不使用单一 `__done` 互相阻止。
- 选中牌打两个标记：
  - `hanjin_retinue_xiyuanjun_visible-turn`：`visibility.card_visible` 对全部角色公开，回合末清理。
  - `hanjin_retinue_xiyuanjun_lock-turn-inhand`：`prohibit_use`/`prohibit_response` 禁止持有者使用或打出；名字同时含 `-turn` 与 `-inhand`，牌离开手牌立即清理，回合末也清理，避免后续持有者继承错误禁用。禁止判断会展开虚拟/转化牌的实体子牌，不只看虚拟牌自身 mark。
- `fk.Damaged` 监听带标记牌的角色：有伤害来源时由来源经 `obtainCard` 获得该牌并清标记；无来源不获得。弃置、给予等其他操作不受用牌/打出限制影响。

#### 4. 验证

`tests/han_retinues.lua`（夹具直接授予正式翼从技能，只验证技能本身）：

| 用例 | 断言 |
| --- | --- |
| 穆顺取得与下一次失血 | 弃置他人牌后取回一张；同回合下一次弃牌不再取得，失去 1 点体力 |
| 西园军公开/禁用/受伤取牌 | 当前阶段角色空手、所选敌方角色有手牌也可选；选中的手牌对其他角色可见、持有者不能使用，含该子牌的虚拟牌也不能使用；受伤后伤害来源获得该牌，标记清理 |

#### 5. 执行状态

- **测试待基础组集成执行**：本轮未启动 FreeKill、未运行 `scripts/test.py`；行为用例无命令输出，不宣称通过。
- 静态解析：`scripts/check_lua.py` 对上述文件均为 `OK`，退出码 0。
- 定向命令：`python scripts/test.py --file tests/han_retinues.lua --timeout 120`。
- 未加入 `tests/all.lua`（本轮禁止修改）。

#### 6. 未覆盖与风险

- 西园军“公开”使用现有 `VisibilitySkill` 公共接口，无客户端补丁；若客户端未按该接口刷新手牌可见性，需基础组回报最小公共接线，而不是伪造可见数据。
- 伤害来源为空的场合已跳过；多张同时带标记的异常输入只取一张，正常流程一次只建立一张。
- 翼从取得/失去技能由统领公共流程覆盖；本测试直接授予技能，不替代该流程验收。

## 吴势力标准包

[锦帆军](../../../../pkg/hanjin_generals/skills/retinue_skill_jinfanjun.lua)与[曲阿小将](../../../../pkg/hanjin_generals/skills/retinue_skill_quaxiaojiang.lua)均为独立正式翼从技能；统领能力与翼从效果沿用[公共规范](../../../../rules/commander-retinue.md)，不在专属技能中重写。

- 锦帆军依据真实 `ReasonDiscard` 操作者与弃牌颜色，支付同色可弃牌后摸二，每回合红黑分别限一次；技能自身支付不递归触发同次费用。
- 曲阿小将读取服务器真实 `GameEvent.UseCard` 历史，按事件顺序取得当前使用前的上一张牌，包含同回合获得技能前的使用；不以结算完成顺序误认嵌套用牌。两次目标不完全相同时，可对重合存活目标各造成一点伤害，每回合限一次。

`tests/wu_damage.lua` 的锦帆军真实弃牌、曲阿小将完整两次用牌及重合目标伤害回归随本套 22 项定向通过；已加入默认国战套件。全量、安装包及逐将入口见[吴包总表](wu-standard.md#3-真实验证与发布)。同回合红黑组合、复杂嵌套／改目标组合未逐项新增独立用例，客户端与联网／重连未人工验收。
