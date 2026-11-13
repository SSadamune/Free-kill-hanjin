# 魏势力翼从：并州狼骑、虎卫军、牛金实现与验证

本页记录三张魏关联翼从的技能实现、接口依据与验证状态，不替代规则条文。规则来源：[标准武将表](../../../../rules/standard-generals.md) 翼从表及[统领与翼从](../../../../rules/commander-retinue.md)。本轮已真实运行定向测试，3/3 通过。

## 1. 文件

| 翼从 | 技能文件 | 规则文本 |
| --- | --- | --- |
| 并州狼骑 | `pkg/hanjin_generals/skills/retinue_skill_bingzhou_langqi.lua` | 出牌阶段限一次，令一名其他角色视为对你使用【决斗】，本回合你与其距离视为1 |
| 虎卫军 | `pkg/hanjin_generals/skills/retinue_skill_huweijun.lua` | 每回合结束时，若本回合共计造成和受到过的伤害数大于1，可以移动场上一张牌 |
| 牛金 | `pkg/hanjin_generals/skills/retinue_skill_niujin.lua` | 同势力角色回合结束时，可使用每种类别至多各一张牌；以此法杀死角色后摸三张牌 |

定向测试：`tests/wei_retinues.lua`（已执行，3/3）。

## 2. 实现要点

- 并州狼骑：主动技不依赖骨架次数限制，`can_use`/`on_use` 用 `usedSkillTimes(..., Player.HistoryPhase)` 强制每阶段一次。距离关系改为双方 `@[hanjin_bingzhou_pairs]` 表标记，支持多来源/多持有者；距离状态技为随包加载的独立骨架 `retinue_skill_bingzhou_distance.lua`（服务端/客户端同一对象），回合末由房间级清理监听移除状态技并清标记。
- 虎卫军：`fk.TurnEnd` 为全局触发，不限于自己回合；用 `logic:getActualDamageEvents` 读取实际伤害（排除被防止），`data.from == player` 与 `data.to == player` 分别累加，自己对自己的伤害计两份。满足后复用 B 组 `wei_phases.moveCardInBoard`。测试在真实 `GameEvent.Turn` 内制造伤害，避免伪造回合历史。
- 牛金：`fk.TurnEnd` 全局触发，目标为同势力角色（含自己）；不设固定类别顺序，每次由玩家选择未用类别或结束，逐次调用 `room:askToUseCard`，每项可取消。效果内用牌 `bypass_times=true`、`extraUse=true`，正常禁止与目标条件照常。来源写入本次 `use.extra_data`；房间级奖励监听在 `fk.Death` 中向上追溯 `GameEvent.UseCard` 的 `extra_data`，仅在本次窗口用牌击杀时摸三张，不依赖持有者之后是否仍有技能。测试先断言技能/同势力/实际用牌，再断言击杀奖励。
- 并州狼骑 `on_use` 不再二次检查 `usedSkillTimes`（引擎在进入 on_use 前已记次，二次检查会吞掉本次发动）；次数由 active `can_use` 的发动历史限制。

## 3. 验证状态

- 本轮真实执行（2026-11-14）：

```text
python scripts/test.py --file tests/wei_retinues.lua --timeout 180
Ran 3 tests in 0.783 seconds, 3 successes, 0 failures
```

- 通过：并州狼骑（真实【决斗】使用者/目标、双向距离、每阶段一次）；虎卫军（真实回合内伤害后移动场上一张牌）；牛金（真实用【杀】击杀不同势力角色，牛金奖励恰好一次 3 张，另加标准国战击杀奖励 1 张，总手牌 4）。
- 牛金此前 `expected 3 actual 25` 的根因：房间级 global refresh 会按每名角色回调，`can_refresh` 未限定 `player == data.killer`，8 人各触发一次 3 张（24），再加正常国战击杀奖励 1 张，合计 25。已限定 `player == killer` 且存活；测试新增 AfterCardsMove 只读探针按 `move.skillName == NJ` 统计恰好一次、恰好 3 张，并断言总手牌 = 正常奖励 1 + 牛金 3。
- `tests/wei_phases.lua` 同轮 14/14 通过（设变、巧变请求级用例含在内）。
- 默认套件与发布包：`python scripts/test.py --timeout 180` → `Ran 608 tests in 96.407 seconds, 608 successes, 0 failures`；`python scripts/build_release.py` → `.dev/dist/hanjin.zip (446 files)`。

## 4. 未完成与风险

- 牛金奖励已修复并验证：`can_refresh` 限定 `player == killer`，奖励一次 3 张；正常国战击杀奖励未关闭，测试断言总手牌 4。
- 并州狼骑的距离状态技双方挂载/回合末移除、以及客户端距离显示需要实际运行与客户端验证。
- 虎卫军已通过真实回合内伤害用例；真实客户端移牌面板未人工验收。
