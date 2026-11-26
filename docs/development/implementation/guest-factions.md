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
6. 最终选将使用原生 `ChooseGeneralModel` 与 `qiao_heg_pair` 规则，普通选将、升变提示及重抽按所需界面加载对应组件。服务端按本局势力结果重新验证主副将、同名替换和重复牌。超时、取消、越界或非法组合回退到该玩家仍合法的候选组合。初始势力在合法交集中单独询问并校验。

通用移除也使用这个武将弃牌堆。上游把成功移除的牌换成士兵后，会先归还旧将再触发「移除武将牌后」。汉晋在这一次归还时将旧将记入弃牌堆，后续技能在该时机内就已无法检索它。移除被阻止时，原将及将池保持原状。

### 边界

- 正式标准包有 51 张武将登记客将势力，君临天下新增 9 张。阵、势包按[图鉴牌面](../../rules/zhen-shi-generals.md#客将势力)填写 `guests`，随正式武将一起注册。孙策按牌面顺序登记群、汉。`tests/support/guest_allegiance_content.lua` 的独立测试武将不进入正式将池。
- 选将界面的客将重抽入口与本局势力提示已按请求数据实现，仍需在游戏客户端人工验收；自动化测试覆盖请求数据、客户端选将规则、服务端复核和状态落盘。
- 战报、动画和断线重连显示不在本轮自动化范围内。

### 客将插画

房间照片和弹窗里的简化照片通过公共武将牌接线更新原生遮罩中的主副将图片源。图片沿用该层的双将裁切，换将后重新读取当前可见程序 ID。具备独立皮肤的角色仍按引擎层级显示皮肤。

- `GuestRedrawBox.qml` 读取请求中的 `extraData.guestIllustrations`，候选、确认区与重抽沿用同一张卡片。只要房间开关开启，即使本次没有可重抽的客将也使用这个选将框。`extraData.guestFactions` 提供启用客籍武将的完整登记客籍，供牌面和边框渲染。`GuestFactionBorder.qml` 从上边中点逆时针按周长等分。禁用蜀、群时，刘备显示汉、魏、吴、群。常规配将的 `pairing` 和初始势力选择使用本局允许的客籍。
- 开启自由选将及客将替换规则时，请求也包含候选外可换入的客将在资料上登记的全部客籍。重抽资格继续来自原始候选。
- 自由选将按武将列表的扩展登记顺序把汉晋武将包放在顶部，与上游包以分割线隔开。列表预览与选将框共用普通及客将牌面，自由选将时使用相同的默认插画，避免本地皮肤盖住换入前预览的插画。
- 自由选将、同名替换和重抽复用原候选卡片。底图随当前武将牌模型更新。本局开启客将替换且当前武将有对应客将插画时才采用该插画，其余情况使用默认插画。`python scripts/check_free_assign_ui.py` 离屏检查蔡文姬与司马炎互换，以及关闭客将替换时蔡文姬显示默认插画。
- `QiaoRoom.qml` 使用 `GeneralCardPresentation.qml` 处理房间及详情弹窗中创建的原生武将牌、缩略牌、武将图牌面和 `PhotoBase` 头像。房间开关和公开的本局允许势力决定显示。暗将占位与缺图回退沿用原组件，主、副将分别按当前可见身份取图。
- `GuestIllustration.js` 与 `GuestCardAppearance.qml` 提供选将、对局与图鉴共用的附加图和卡面势力徽记。选将、变更与局内详情统一按房间显示顺序排列三种以上客籍，图鉴按登记顺序预览。对局头像沿用原遮罩、分栏及皮肤层。
- 对局内按房间开关和可见武将的程序 ID 查找插画，朱儁的 `guests` 留空也能在选将与局内换图。其牌面势力和配将按汉处理，图鉴开关仍按客籍登记预览。
- 【尚义】的私看和【祸水】的选将共用 utility 请求模型与对局武将牌显示，详情可查看本次提供的武将。选中状态由模型保存，候选滚出网格后仍可由下一次选择替换。候选限制和回包格式沿用 utility。
- 根 `init.lua` 通过已登记的武将一览页面入口加载 `QiaoGeneralsOverview.qml`。「客将势力」开关对原生图鉴网格和详情预览应用同一份客将登记。登记由武将数据提供，一到两种势力用原卡面样式，三种以上由 `GuestFactionBadges.qml` 错行排列。各包的显示、搜索与原详情入口可继续使用。

`tests/guest_allegiance.lua` 覆盖势力解析与配将、连续重抽、两人重抽、补发失败保留原候选、选将回复复核和客户端请求协议，也核对阵势包九将登记、禁吴和群时孙策的入池与配将、朱儁在房间开关两种状态下的选将请求。`tests/standard_generals.lua` 覆盖标准包客将登记与解析。真人联机及断线重连显示待人工验收。
