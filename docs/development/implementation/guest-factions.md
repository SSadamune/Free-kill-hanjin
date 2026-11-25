# 客将：实现与验证

游戏语义见[对应规则](../../rules/guest-factions.md)；当前实装与待办见[开发状态](../status.md)。本页保留接口、接线和验收依据，不替代规则裁定，历史覆盖说明不代表已完成全部人工验收。

## 扩展内实现

**已实装。** 禁选结果确定后，在房间内保存每张牌本局可用的势力及是否由客将势力转入。发将、选将界面、服务器配将验证、初始势力选择及后续取将共用这一结果；不改写全进程的武将定义。

| 内容 | 文件/接口 |
| --- | --- |
| 房主候选/上限与允许集 | `pkg/qiao_mode/rules/faction_ban.lua`：`resolveSettings`、`plan`、`registerKingdom`；候选外不可选 |
| 客将势力登记与逐房间解析 | `pkg/qiao_mode/rules/guest_factions.lua`：`registerGuest(name, kingdoms)`、`resolve(name, allowed, replacementEnabled)`、`factionsOf(room, name)`、`pairKingdoms(room, main, deputy)`、`store(room, factions)` |
| 开局将池、版本替换与状态落盘 | `pkg/qiao_mode/rules/general_pool.lua`：`resolve(room, versionPlan, options)`、`apply(room, built)` |
| 选将请求、重抽、服务端复核 | `pkg/qiao_mode/rules/selection.lua` |
| 武将弃牌堆与引擎入口拦截 | `pkg/qiao_mode/rules/general_discard.lua` |
| 重抽客户端 | `pkg/qiao_mode/qml/GuestRedrawBox.qml`、`qiao_heg_pair` 客户端选将规则 |
| 正式/测试内容 | `tests/support/guest_allegiance_content.lua`（仅测试）；正式登记见 `pkg/qiao_generals/data/standard.lua` |

### 房间状态与配将

三个模式共享 `qiao_guest_replacement` 复选框，缺省开启。开局版本计划、将池解析及后续查询共用该设置。大合集和自由模式为实际启用客将势力的候选提供重抽资格，锁定势力的重抽候选为空。济世保留救援结算，并按该开关决定是否进入客将交换。

- `qiao_general_factions_v1` 房间 tag 保存本局每张入池牌的结果：`source = "original" | "guest" | "wild"` 及过滤后的 `kingdoms`。`guest` 表示印刷主势力全被禁、由客将势力转入；`wild` 只用于仍以野心家主将入池的原版。
- 先完成[势力禁选](../../rules/faction-ban.md)和[野心家效忠](../../rules/wild-allegiance.md)的开局版本规划，再对保留名单逐张解析。任一印刷主势力未禁就用印刷势力；全部被禁才启用登记的客将势力；两者都没有未禁项则移出本局并加入 `disabled_generals`。
- `pairKingdoms` 使用房间结果而非引擎全局定义：双方各取本局可用势力求交集；野心家原版只能作主将，按其副将的本局势力确定初始势力。发将、候选校验、初始势力选择和最终落将都调用同一接口。
- 禁选前候选集 `C` 完全由房主预先选择，默认魏蜀吴群汉晋六势力；不从将池、主势力、客将势力或效忠版势力推断。客将势力与主势力、效忠版势力同受本局允许集约束，候选外不可选；仅作为客将势力出现的势力不再单独计数。

### 自愿重抽与弃牌堆

1. 发将后所有玩家直接进入主副将选择界面。启用客籍的牌显示完整的登记客籍。点击该牌下方的「重抽」按钮，立即请求替换这一张牌；其他候选和选将倒计时保持原状。
2. 服务端核对玩家、牌位和原候选，仅处理本人的有效客将。补发前检查替换后是否仍有合法主副将，并从剩余将池取牌。
3. 只有找到合法补发时才移除原候选、从本房间将池补发并记入弃牌堆；补发失败时原候选、候选顺序和将池都不变，并记录 `qiao_guest_redraw_failures_v1`。
4. 补发牌回到原牌位。新牌若仍为客将，可继续重抽；其余未点选客将保留重抽权。若补发失败，保留原牌并关闭该牌的重抽按钮。多人重抽按服务端收到请求的顺序使用剩余将池。
5. 客将重抽成功换下的牌，以及变更武将成功换下的旧武将牌，都立即加入 `qiao_general_discard_v1` 与 `disabled_generals`，并从 `general_pile` 移除。`general_discard.lua` 在汉晋房间内拦截 `getNGenerals`、`findGeneral`、`findGenerals`、`askToChooseIniticalGeneral`和 `returnToGeneralPile`，本局后续取将及回池都不会重新放入；其他模式不受影响。
6. 最终选将使用 `ChooseGeneralBox` 与 `qiao_heg_pair` 规则，服务端按 `guest` 及 `wild` 结果重新验证主副将、同名替换、初始势力和重复牌；超时、取消、越界或非法组合回退到该玩家仍合法的候选组合。初始势力在合法交集中单独询问并再次校验。

通用移除也使用这个武将弃牌堆。上游把成功移除的牌换成士兵后，会先归还旧将再触发「移除武将牌后」。汉晋在这一次归还时将旧将记入弃牌堆，后续技能在该时机内就已无法检索它。移除被阻止时，原将及将池保持原状。

### 边界

- 正式标准包已有 51 张武将登记客将势力并接入正式将池；其专属技能仍仅展示。`tests/support/guest_allegiance_content.lua` 的独立测试武将不进入正式将池。
- 选将界面的客将重抽入口与本局势力提示已按请求数据实现，仍需在游戏客户端人工验收；自动化测试覆盖请求数据、客户端选将规则、服务端复核和状态落盘。
- 战报、动画和断线重连显示不在本轮自动化范围内。

### 客将插画

- `GuestRedrawBox.qml` 读取请求中的 `extraData.guestIllustrations`，候选、确认区与重抽沿用同一张卡片。只要房间开关开启，即使本次没有可重抽的客将也使用这个选将框。`extraData.guestFactions` 提供启用客籍武将的完整登记客籍，供牌面和边框渲染。`GuestFactionBorder.qml` 从上边中点逆时针按周长等分。禁用蜀、群时，刘备显示汉、魏、吴、群。常规配将的 `pairing` 和初始势力选择使用本局允许的客籍。
- 开启自由选将及客将替换规则时，请求也包含候选外可换入的客将在资料上登记的全部客籍。重抽资格继续来自原始候选。
- `QiaoRoom.qml` 通过 `QiaoClient:guestIllustrationsEnabled` 读取客户端的房间开关，按 `Photo` 当前显示的主将和副将程序 ID 分别取图。重连时房间摘要恢复设置和武将属性，暗将沿用引擎占位。
- `GuestIllustration.js` 在选将、局内和图鉴共用 `SkinBank.getGeneralExtraPic(name, "guest/")`。缺图时选将和图鉴沿用原卡面，局内沿用引擎原头像。局内客将图放在 `PhotoBase` 的头像遮罩内，保留分栏和叠加效果。
- 房间挂接头像时读取客将插画开关，座位与牌面状态更新后重新检查挂接。主副将已选用的皮肤优先显示。祸水等使用 utility 通用武将选择请求的技能和「赐」共用 `QiaoGeneralCard.qml`，从房间已公开的武将位置取势力和皮肤。缺少场上对应位置时按该武将的资料显示势力。祸水保留上游候选限制与回包；该显示入口只从当前头像读取明置身份。
- 根 `init.lua` 通过已登记的武将一览页面入口加载 `QiaoGeneralsOverview.qml`。「客将势力」开关读取 `Guest.registeredInPackage` 返回的程序 ID 与势力表。一到两种势力沿用原卡片样式，三种以上由 `GuestFactionBadges.qml` 统一大小并在卡面左上角错行排列。三种近似三角形，四种近似平行四边形，五种按上二下三排列。点击牌面沿用原详情入口。

**已裁定。** 禁选前候选集 `C` 由房主预先选择，默认六势力；仅作为客将势力出现的势力不参与 `C` 的推断。客将、主势力和效忠版势力都只在 `C` 的允许集内可选；候选外不可选。候选数不超过房主允许上限时无额外禁选；超过上限时按[势力禁选](../../rules/faction-ban.md)的跨局必禁/必留规则随机到上限。

`tests/guest_allegiance.lua` 已覆盖势力解析与配将、连续重抽、两人重抽、补发失败保留原候选、选将回复复核和客户端请求协议；`tests/standard_generals.lua` 覆盖正式客将登记与解析。界面显示、动画及断线重连的人工验收仍待完成。
