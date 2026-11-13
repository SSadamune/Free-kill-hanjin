# HAN 翼从：穆顺、西园军实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

规则依据：[标准武将表](../../../../rules/standard-generals.md)翼从两行、[统领与翼从](../../../../rules/commander-retinue.md)、[移动事件](../../../../rulebook/events/move-card.md)、[弃置](../../../../rulebook/terms/card-op-terms/discard.md)、[展示](../../../../rulebook/terms/card-op-terms/showCards.md)。本页只记录接口与验收依据；翼从取得流程由统领公共规则负责。

## 1. 实现结构

- `pkg/hanjin_generals/skills/retinue_skill_mushun.lua`：穆顺。
- `pkg/hanjin_generals/skills/retinue_skill_xiyuanjun.lua`：西园军。
- 两个骨架均显式赋 `hanjinImplemented = true`；不改 `init/data/tests/all`，不新增客户端补丁。

## 2. 穆顺

- 监听真实 `fk.AfterCardsMove`：只认 `moveReason == fk.ReasonDiscard` 且目标为弃牌堆的移动；重铸、给牌等不计。
- 分别按真实移动数据判断：`move.proposer == 穆顺` 为自己弃置任意角色的牌（含自己主动弃自己的牌）；`move.from == 穆顺` 且 `proposer` 为其他角色为被其他角色弃置。不按技能名或猜测的弃牌者判断。
- 结算时重新检查候选牌仍在弃牌堆，才允许选择；用 `askToCards` 的 `expand_pile` 展示弃牌堆候选，取得后才写本回合限制标记。
- 取得成功后才建立 `-turn` 的“下一次同条件弃牌失 1 点体力”标记；该罚效果由房间级延迟监听器读取角色标记，不要求穆顺当前仍有技能。
- 罚监听只判断“是否发生了符合条件的弃置”，不要求牌仍在弃牌堆：即使该次弃置的牌已被同优先级技能取走，仍失血。取得事件本身用事件标识抑制同一事件刚建立的罚效果，避免重复扣血。
- 取得次数标记以技能名开头，随翼从武将迁移；罚标记附在角色身上、不带技能前缀，避免误迁。每回合取得一次由 `-turn` 标记限制。

## 3. 西园军

- `fk.EventPhaseStart` 以普通 `global + can_trigger + on_cost + on_use` 处理：触发条件是与西园军同势力的角色出牌阶段开始；当前阶段角色可以没有手牌。
- 被选牌角色是“一名角色”，候选为全场有手牌的合法角色，不限制与西园军同势力（可选敌方，也可选当前空手的阶段角色以外的角色）。先选角色，再用 `askToChooseCard(flag="h")` 由引擎隐藏选牌；返回值用 `Card:getIdList` 规范化为单个 id，兼容 Card/ID/数组。
- 每个西园军 owner 各自独立处理同一事件，不使用单一 `__done` 互相阻止。
- 选中牌打两个标记：
  - `hanjin_retinue_xiyuanjun_visible-turn`：`visibility.card_visible` 对全部角色公开，回合末清理。
  - `hanjin_retinue_xiyuanjun_lock-turn-inhand`：`prohibit_use`/`prohibit_response` 禁止持有者使用或打出；名字同时含 `-turn` 与 `-inhand`，牌离开手牌立即清理，回合末也清理，避免后续持有者继承错误禁用。禁止判断会展开虚拟/转化牌的实体子牌，不只看虚拟牌自身 mark。
- `fk.Damaged` 监听带标记牌的角色：有伤害来源时由来源经 `obtainCard` 获得该牌并清标记；无来源不获得。弃置、给予等其他操作不受用牌/打出限制影响。

## 4. 验证

`tests/han_retinues.lua`（夹具直接授予正式翼从技能，只验证技能本身）：

| 用例 | 断言 |
| --- | --- |
| 穆顺取得与下一次失血 | 弃置他人牌后取回一张；同回合下一次弃牌不再取得，失去 1 点体力 |
| 西园军公开/禁用/受伤取牌 | 当前阶段角色空手、所选敌方角色有手牌也可选；选中的手牌对其他角色可见、持有者不能使用，含该子牌的虚拟牌也不能使用；受伤后伤害来源获得该牌，标记清理 |

## 5. 执行状态

- **测试待基础组集成执行**：本轮未启动 FreeKill、未运行 `scripts/test.py`；行为用例无命令输出，不宣称通过。
- 静态解析：`scripts/check_lua.py` 对上述文件均为 `OK`，退出码 0。
- 定向命令：`python scripts/test.py --file tests/han_retinues.lua --timeout 120`。
- 未加入 `tests/all.lua`（本轮禁止修改）。

## 6. 未覆盖与风险

- 西园军“公开”使用现有 `VisibilitySkill` 公共接口，无客户端补丁；若客户端未按该接口刷新手牌可见性，需基础组回报最小公共接线，而不是伪造可见数据。
- 伤害来源为空的场合已跳过；多张同时带标记的异常输入只取一张，正常流程一次只建立一张。
- 翼从取得/失去技能由统领公共流程覆盖；本测试直接授予技能，不替代该流程验收。
