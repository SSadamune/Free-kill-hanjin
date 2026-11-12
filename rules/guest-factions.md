# 客将

适用于 `hanjin_heg_mode`，已实现并通过自动化测试。标准包已有 51 张武将登记客将势力，正式将池的客将解析由 `tests/standard_generals.lua` 覆盖。

## 本局主势力

对每张武将分别登记原有主势力和客将势力。原有主势力可有多项，引擎的第二势力字段不能一概解释成客将势力。客将势力限魏、蜀、吴、群、汉、晋；本局允许集同时约束主势力与客将势力。先取得房主候选与允许集，再逐张判定：

| 原有主势力 | 客将势力 | 本局结果 |
| --- | --- | --- |
| 至少一项在允许集 | 任意 | 使用在允许集的原有主势力，按普通武将入池 |
| 全部不在允许集 | 至少一项在允许集 | 使用在允许集的客将势力作为本局主势力，正常发将；获发者可保留或重抽 |
| 全部不在允许集 | 没有客将势力，或全部不在允许集 | 排除该武将 |

例如曹操原有主势力为魏，客将势力为汉、群。魏在允许集时只按魏配将；魏、汉均不在允许集且群在允许集时按群配将，并可重抽。司马懿的原有主势力为魏，魏不在允许集且晋在允许集时按晋处理。多主势力武将只要仍有一项原有主势力可用，就不会启用客将势力。候选外势力不可选，主势力、客将势力与效忠版势力一视同仁。

## 扩展内实现

**已实装。** 禁选结果确定后，在房间内保存每张牌本局可用的势力及是否由客将势力转入。发将、选将界面、服务器配将验证、初始势力选择及后续取将共用这一结果；不改写全进程的武将定义。

| 内容 | 文件/接口 |
| --- | --- |
| 房主候选/上限与允许集 | `pkg/hanjin_mode/rules/faction_ban.lua`：`resolveSettings`、`plan`、`registerKingdom`；候选外不可选 |
| 客将势力登记与逐房间解析 | `pkg/hanjin_mode/rules/guest_factions.lua`：`registerGuest(name, kingdoms)`、`resolve(name, allowed)`、`factionsOf(room, name)`、`pairKingdoms(room, main, deputy)`、`store(room, factions)` |
| 开局将池、版本替换与状态落盘 | `pkg/hanjin_mode/rules/general_pool.lua`：`resolve(room, versionPlan, options)`、`apply(room, built)` |
| 选将请求、重抽、服务端复核 | `pkg/hanjin_mode/rules/selection.lua` |
| 武将弃牌堆与引擎入口拦截 | `pkg/hanjin_mode/rules/general_discard.lua` |
| 重抽客户端 | `pkg/hanjin_mode/qml/GuestRedrawBox.qml`、`hanjin_heg_pair` 客户端选将规则 |
| 正式/测试内容 | `tests/support/guest_allegiance_content.lua`（仅测试）；正式登记见 `pkg/hanjin_generals/data/standard.lua` |

### 房间状态与配将

- `hanjin_general_factions_v1` 房间 tag 保存本局每张入池牌的结果：`source = "original" | "guest" | "wild"` 及过滤后的 `kingdoms`。`guest` 表示印刷主势力全被禁、由客将势力转入；`wild` 只用于仍以野心家主将入池的原版。
- 先完成[势力禁选](faction-ban.md)和[野心家效忠](wild-allegiance.md)的开局版本规划，再对保留名单逐张解析。任一印刷主势力未禁就用印刷势力；全部被禁才启用登记的客将势力；两者都没有未禁项则移出本局并加入 `disabled_generals`。
- `pairKingdoms` 使用房间结果而非引擎全局定义：双方各取本局可用势力求交集；野心家原版只能作主将，按其副将的本局势力确定初始势力。发将、候选校验、初始势力选择和最终落将都调用同一接口。
- 禁选前候选集 `C` 完全由房主预先选择，默认魏蜀吴群汉晋六势力；不从将池、主势力、客将势力或效忠版势力推断。客将势力与主势力、效忠版势力同受本局允许集约束，候选外不可选；仅作为客将势力出现的势力不再单独计数。

### 自愿重抽与弃牌堆

1. 发将后所有玩家直接进入主副将选择界面。客将牌按本局客将势力显示势力字和边框。点击该牌下方的「重抽」按钮，立即请求替换这一张牌；其他候选和选将倒计时保持原状。
2. 服务端核对玩家、牌位和原候选，仅处理本人的有效客将。补发前检查替换后是否仍有合法主副将，并从剩余将池取牌。
3. 只有找到合法补发时才移除原候选、从本房间将池补发并记入弃牌堆；补发失败时原候选、候选顺序和将池都不变，并记录 `hanjin_guest_redraw_failures_v1`。
4. 补发牌回到原牌位。新牌若仍为客将，可继续重抽；其余未点选客将保留重抽权。若补发失败，保留原牌并关闭该牌的重抽按钮。多人重抽按服务端收到请求的顺序使用剩余将池。
5. 成功换掉的牌立即加入 `hanjin_general_discard_v1` 与 `disabled_generals`，并从 `general_pile` 移除。`general_discard.lua` 在汉晋房间内拦截 `getNGenerals`、`findGeneral`、`findGenerals`、`askToChooseIniticalGeneral`和 `returnToGeneralPile`，本局后续取将及回池都不会重新放入；其他模式不受影响。
6. 最终选将使用 `ChooseGeneralBox` 与 `hanjin_heg_pair` 规则，服务端按 `guest` 及 `wild` 结果重新验证主副将、同名替换、初始势力和重复牌；超时、取消、越界或非法组合回退到该玩家仍合法的候选组合。初始势力在合法交集中单独询问并再次校验。

### 边界

- 正式标准包已有 51 张武将登记客将势力并接入正式将池；其专属技能仍仅展示。`tests/support/guest_allegiance_content.lua` 的独立测试武将不进入正式将池。
- 选将界面的客将重抽入口与本局势力提示已按请求数据实现，仍需在游戏客户端人工验收；自动化测试覆盖请求数据、客户端选将规则、服务端复核和状态落盘。
- 战报、动画和断线重连显示不在本轮自动化范围内。

**已裁定。** 禁选前候选集 `C` 由房主预先选择，默认六势力；仅作为客将势力出现的势力不参与 `C` 的推断。客将、主势力和效忠版势力都只在 `C` 的允许集内可选；候选外不可选。候选数不超过房主允许上限时无额外禁选；超过上限时按[势力禁选](faction-ban.md)的跨局必禁/必留规则随机到上限。

`tests/guest_allegiance.lua` 已覆盖势力解析与配将、连续重抽、两人重抽、补发失败保留原候选、选将回复复核和客户端请求协议；`tests/standard_generals.lua` 覆盖正式客将登记与解析。界面显示、动画及断线重连的人工验收仍待完成。
