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
| 正式/测试内容 | 正式登记见 `pkg/qiao_generals/data/standard.lua` 及阵势包的 `zhen_shi*.lua`。独立测试内容见 `tests/support/guest_allegiance_content.lua` |

### 房间状态与配将

三个模式共享 `qiao_guest_replacement` 复选框，缺省开启。开局版本计划、将池解析及后续查询共用该设置。汉晋大合集和平行时空为实际启用客将势力的候选提供重抽资格，锁定势力国战的重抽候选为空。济世保留救援结算，并按该开关决定是否进入客将交换。

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
6. 最终选将使用原生 `ChooseGeneralModel` 与 `qiao_heg_pair` 规则，普通选将、升变提示及重抽按所需界面加载对应组件。服务端按本局势力结果重新验证主副将、同名替换和重复牌。超时、取消、越界或非法组合回退到该玩家仍合法的候选组合。初始势力在合法交集中单独询问并校验。

通用移除也使用这个武将弃牌堆。上游把成功移除的牌换成士兵后，会先归还旧将再触发「移除武将牌后」。汉晋在这一次归还时将旧将记入弃牌堆，后续技能在该时机内就已无法检索它。移除被阻止时，原将及将池保持原状。

### 边界

- 正式标准包有 51 张武将登记客将势力，君临天下新增 9 张。阵、势包按[图鉴牌面](../../rules/zhen-shi-generals.md#客将势力)填写 `guests`，随正式武将一起注册。孙策按牌面顺序登记群、汉。`tests/support/guest_allegiance_content.lua` 的独立测试武将不进入正式将池。
- 服务端请求提供各候选的客将重抽资格，局内武将牌在统一入口读取房间状态展示势力。自动化覆盖重抽请求、选将规则、服务端复核和状态落盘。各显示场景的验收范围见[客将显示验证](#客将插画)。

### 客将插画

图鉴、局内完整牌和主桌面头像的显示规则见[客将插画显示表](../guest-illustrations.md#显示行为)。原本完整牌和部分弹窗分别从候选数据或角色势力取徽记，头像和缩略牌又走各自的换图路径。同一武将因此可能在不同组件显示不同的牌面。房间客籍映射现也避开了 Qt 6.10 未支持的 `Object.fromEntries`。

- [`GeneralCardPresentation.appearanceFor`](../../../pkg/qiao_mode/qml/GeneralCardPresentation.qml) 按武将程序 ID 返回可用客将图、用于展示的客籍和最终牌面势力。房间从 `guestIllustrationsEnabled()` 和 `guestCardFactions()` 取公开状态，后者以 `all_kingdoms` 判定主势力是否全禁。初始化、禁选同步及重连均刷新这份状态。武将一览用独立的预览开关和登记数据提供同一接口。
- 选将、确认区、自由选将、重抽、换将、赐、知己知彼、尚义和祸水候选共用牌面。原生角色详情、缩略牌、战报、武将牌堆、技能弹窗、动画和 `general:` 武将牌面也由房间接入。完整牌经 `GuestCardAppearance.qml` 接线，客将边框与徽记布局分别使用共享组件。图片通过 `SkinBank.getGeneralExtraPic` 从 `guest/` 读取，完整牌默认图由原生 `GeneralCardModel.frontSkin` 提供。
- 主桌面原生 `Photo` 按主副将各自公开的程序 ID 持续绑定图片源，沿用原生遮罩及裁切。Qt 6.10 退出旧的客将图条件绑定时可能残留上一张正面，因此暗将占位显式加载牌背。桌面 `Photo` 隐藏额外的武将牌徽记，原生角色势力标与弹窗中的牌面徽记各按原有显示入口处理。本人的私密武将牌从右键详情查看。
- 配将、重抽资格和赐的转交分组读取服务端的本局允许势力。局内牌面使用的完整客籍只用于展示。
- `python scripts/check_free_assign_ui.py` 验证右键及长按换将、原势力仍允许时只换图、主势力全禁时同时换图和势力标识，以及关闭开关时还原。并核对主副将头像、角色详情牌、私看牌、赐、缩略牌和武将图牌面的公共接线。

`tests/guest_allegiance.lua` 覆盖势力解析与配将、连续重抽、两人重抽、补发失败保留原候选、选将回复复核和客户端请求协议，也核对阵势包九将登记、禁吴和群时孙策的入池与配将、朱儁在房间开关两种状态下的选将请求。`tests/standard_generals.lua` 覆盖标准包客将登记与解析。实机、联机与重连的当前验收范围见[开发状态](../status.md#最近验证记录)。
