# HAN004 张让：滔乱实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

游戏语义见[专项裁定](../../../../rules/generals/han004-zhangrang.md)与[标准武将表](../../../../rules/standard-generals.md)汉区 HAN004。本页记录接口与验收依据，暂行结算不因实现转为定稿。

## 1. 实现结构

- `pkg/hanjin_generals/skills/skill_han004_1.lua`：滔乱。
- 骨架显式赋 `hanjinImplemented = true`，不改 `init.lua`、`data/`。

## 2. 发动窗口与明置

- 统一使用 ViewAs：正常出牌阶段与合法「使用」窗口共用同一入口，无实体子牌，按正常牌面条件选择目标；正常出牌不会绕过普通【杀】次数。
- `view_as` 是客户端纯函数：只读取自身可见武将/本局公开标记，不调用 `player.room`，也不做服务端查询。它在克隆牌之后把来源编号（1 主将 / 2 副将）写到 `card.hanjinTaoluanSource`。
- 响应窗口只放行 `ReqUseCard` 的「使用」窗口（含回合外使用【闪】/【无懈】）；`enabled_at_response` 在 `cardResponsing = true` 的纯打出请求下固定返回 false，不按响应牌名另做解析。
- 只有承载本技能的武将牌暗置且 `prohibitReveal` 允许时才可发动；客户端仅依据自身可见武将与本局公开标记。已明置后 `hiddenSource` 返回 nil，不再发动。
- `room:useSkill` 在 `before_use` 之前按技能名自动明置来源武将（`revealBySkillName`）。因此 `before_use` 不能要求来源仍暗置；它只消费 `hanjinTaoluanSource`，核对编号对应的武将已明置且确实承载本技能，不合法时返回技能名取消本次使用，避免伪造亮将发动。
- 候选牌名按 `hanjin_cards/data/reuse.lua` 的 `status == "reused"` 过滤，只取已实装、非衍生、非空壳的基本牌/普通锦囊，排除延时锦囊与装备。

## 3. 记录与回合末结算

- 记录与结算在首次发动时安装为房间级延迟技能，不依附张让当前技能对象；明置导致技能替换后仍能收牌。
- 以真实 `fk.TargetSpecified` 时点记录「本回合以此法使用牌指定过的其他角色」到 `-turn` 表标记，只由该牌的 `data.from` 这一个 owner 处理，不按候选玩家重复变更；不取 `CardUseFinished` 最终目标。重复指定同一角色由 `addTableMarkIfNeed` 去重。
- 每次真实宣告成功（`fk.AfterCardUseDeclared`）给发动者增加一次 `-turn` 发动计数，单次使用只计一次；不按目标数或结算次数重复计。
- `fk.TurnEnd` 使用 refresh 而非需要询问发动的 trigger：结算必须自动发生，且房间级延迟技能无需再注册触发器名。房间 tag 防止重入；按该玩家的发动计数逐个调用一次 `settle`，每次结算的候选仍取本回合累计记录的指定目标。
- `-turn` 标记由引擎 `clearHistory(Player.HistoryTurn)` 在回合末结算后清理，不手工跨回合保留。
- 每次结算：选择至多三名候选（逆时针排序），依次询问每名仍有手牌者展示并交一张手牌；按实际得到牌的有效颜色统计红/黑，红多于黑时暗置自己一张可暗置武将（两张均明置时询问）。
- 未得到的牌不额外补抽；无手牌角色跳过。

## 4. 验证

`tests/han004_zhangrang.lua`（均为真实请求/回复与真实回合）：

| 用例 | 断言 |
| --- | --- |
| 暗置发动与回合末 | 出牌阶段先取消国战争取明置询问；经真实 `PlayCard` 以滔乱使用【杀】并明置；同一完整 Turn 的 TurnEnd 选 p2，p2 交红牌后张让实际得牌并暗置主将 |
| 回合外使用【闪】 | 暗置时 `enabledAtResponse(player, true)` 为 false、false 时为 true；p2 使用【杀】时，p1 经 `ReqUseCard` 以滔乱使用【闪】；未受伤、来源明置、发动计数保留 |
| 已明置不可再发动 | 主副将均明置后仍提交滔乱使用：服务端不提供来源，使用被取消，目标未受伤、武将保持明置 |

## 5. 执行状态

- 定向命令与真实结果：
  - `python scripts/test.py --file tests/han004_zhangrang.lua --timeout 120` → `Ran 3 tests ... 3 successes, 0 failures`，退出码 0。
  - `python scripts/test.py --file tests/han005_hejin.lua --timeout 120` → `Ran 3 tests ... 3 successes, 0 failures`，退出码 0。
- 未运行默认全量 `python scripts/test.py`；本轮未提交。

## 6. 未覆盖与风险

- 暂行「每次发动分别结算」已按发动计数逐次结算、候选取本回合累计；但当前来源必须仍暗置：第一次发动后承载武将已明置，同一回合内无法再次提供该技能。是否允许已明置后继续发动，需规则最终确认；本轮未构造同回合两次发动的自动化用例。
- 明置源、限一次暗置等边界未做完整场景映射，只按本轮核心验收。
- 客户端 UI 的真实点击流程（选牌名、选目标、暗置选择）未做人工界面验证，自动化只验证服务端请求与回复。
