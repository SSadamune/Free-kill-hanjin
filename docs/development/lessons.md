# 可复用的故障案例

本页保留触发条件、已确认根因、修复与回归入口，供定位同类问题；不是游戏规则，也不记录完整排障流水账。通用处理方法见[测试规范](testing.md)，最新验证结果见[开发状态](status.md)。

## 客户端角色没有服务端房间字段（已修复）

- 现象：刘协搭配徐晃、明置副将后进入出牌阶段，密诏按钮检查报 `player.room` 为 nil。
- 根因：可用性、交牌下限及提示会在 `ClientPlayer` 上计算，不能假定它有 `ServerPlayer.room`。
- 修复：密诏使用兼容客户端的当前房间接口读取可见状态，保留服务端执行前复核。
- 回归：`tests/han001_liuxie.lua` 中 `testMZ31RealClientPlayerWithoutRoomComputesKnownFaction`、`testMZ32ClientWithoutRoomPredictsHiddenOwnFaction`。
- 群包再次出现同类问题：张角／华佗进入出牌阶段，`ReqPlayCard.skillButtonValidity` 调用除疠 `can_use` 时访问 `player.room`。服务端效果用例通过不能证明客户端按钮可用；应沿调用链检查 `can_use`、目标筛选及它们调用的辅助函数。
- 夹具也须使用客户端房间：仅换成 `ClientPlayer` 而让 `Fk:currentRoom()` 仍返回服务端房间，会混用两套角色和牌区。`tests/qun_basic.lua` 的 `withClientRoom` 展示成套客户端角色、独立牌区及异常后恢复上下文；测试同时断言合法场景可用、无候选和次数耗尽时禁用，避免用空列表掩盖错误。

## 卡牌脚注泄漏富文本标签

- 现象：使用助战杀时，结算区卡牌上显示 `</b></font>` 等标签并折行遮挡牌面。
- 接口核对：锁定引擎 `Client:parseMsg(msg, true)` 仍给玩家名加 `font/b` 标签；实体牌 `setCardNote` 与虚拟牌 `showVirtualCard` 都调用它。截图含张虎&乐綝，但 `&` 是否导致 Qt AutoText 解析失败尚未通过渲染验证。
- 修复：正式扩展的 `HanjinClient:parseMsg` 仅对汉晋模式的 `nocolor == true` 输出去除这些格式标签；继承两条通知路径，普通日志及其他模式保留原行为，不修改本体 QML。
- 回归：`tests/han001_liuxie.lua` 的 `testCardFootnoteStripsRichTextOnlyInHanjinMode` 使用正式双将名及真实 `##UseCardTo` 消息，捕获两条客户端通知，核对脚注、普通日志与模式隔离；客户端实际渲染待人工验收。

## 预排的闪回复被无懈询问提前消费

- 现象：纯打出闪不触发应变的测试偶发观察到一次应变；单独测试可能通过。
- 根因：随机初始双将包含暗置张让时，滔乱使持闪的目标进入万箭齐发的无懈候选。`FkTest.setNextReplies` 按请求先后消费且不校验牌名，原本供 `AskForResponseCard` 的闪回复被更早的无懈 `AskForUseCard` 消费，测试因此错误执行了一次使用闪。观察到的牌没有转化技能名，所响应牌为万箭；固定隐张让组合可复现。
- 修复：纯卡牌套件固定白板双将；该交互用例明确装入隐张让，先为无懈请求安排取消，再为万箭安排打出闪。保留真实询问，并观察无懈候选和卡牌事件。
- 回归：`tests/card_reuse.lua:testJinkPlayedAsResponseDoesNotTriggerAdaptation` 断言目标实际进入无懈候选、`CardResponding` 一次、`CardUsing` 零次、应变零次。

## 同名语义不代表事件数据拥有同一方法（已修复）

- 现象：发动国战方天画戟扩目标后，一名目标用闪抵消杀，报 `setNullified` 不存在。
- 根因：锁定引擎的 `UseCardData` 没有该方法；`CardEffectData` 等数据才提供无效化接口。装备安装成功的测试没有触达此分支。
- 修复：独立汉晋武器技能在牌效果数据上登记全部目标无效，不修改上游依赖。
- 回归：`tests/card_reuse.lua` 的 `testHalberdExpandedSlashNullifiesRemainingTargetsAfterJink`，并保留无人出闪及未发动扩目标的对照。

## 随机初始暗将状态污染已知双将夹具（已修复）

- 现象：同一代码的天命用例有时不发动；另有明置用例意外转为野心家。
- 根因：夹具直接替换 `anjiang`，原暗将的 fake skill 和旧势力标记没有清理。随机初始双将含刘协时，残留技能导致额外发动询问，将预设空回复消费为拒绝；旧 `__heg_wild` 标记可影响明置势力。
- 修复：通过引擎明置接口清理旧技能来源，再安装已知双将并重置势力标记。没有证据前称为“时序抖动”是不正确的诊断。
- 回归：`tests/han001_liuxie.lua` 的 `testFixtureClearsHiddenSkillsBeforeInstallingKnownGenerals`，已验证修复前失败、修复后通过。

## 选择与执行接口职责混淆（已修复）

- 风险：虚拟用牌助手可能在返回前已执行；调用者再执行会重复结算，也可能使校验晚于实际效果。
- 修复：公共目标层区分只选择、返回待执行数据与选择后执行，先附加策略并复核，再由单一入口执行。接口契约见[目标实现文档](implementation/card-use-targets.md)。
- 回归：`tests/card_use_targets.lua` 的执行次数、失败无副作用及复杂目标集成验证。

## 功能交付不能依赖开发本体补丁（方案已纠正）

密诏单选切换最初被尝试做为本地客户端适配，随后撤回。最终通过扩展内的汉晋客户端注册与请求处理器发布；本地开发脚本不承担该功能。回归同时覆盖出牌与主动技能询问路径，安装包检查包含客户端和接线。此例说明应先确认成品加载路径，再实现玩家交互，不应把本地可用当作功能交付完成。

## 多个 boardgame 复用同一引擎导致重复初始化（已修复）

- 现象：加载时牌型数量从 179 增至 358，随后报 `Duplicate game_mode hanjin_heg_mode detected`；遍历顺序不同会使故障时隐时现。
- 根因：在引擎的 `postLoad` 回调中新增共享同一 Engine 的 boardgame；本体遍历 boardgame 调用各自引擎的 `postLoad`，可能再次初始化同一引擎。这不是可用重跑消除的环境问题。
- 修复：沿用原 boardgame，仅替换客户端类；自定义请求同时限定汉晋模式和密诏技能，其余委托原处理器。子类序列化也需核对父类动态转发，避免递归。
- 回归：`tests/mode_rules.lua` 检查同一 Engine 只登记一次；刘协 MZ33 同时验证汉晋单选替换和上游模式原有行为，默认全量套件验证完整加载。

## 必然效果误走默认可选询问（已修复）

- 现象：短兵对距离 1 的目标应增加一张闪的需求，真实用杀测试中却被一张闪抵消。
- 根因：第二段效果没有声明 `on_cost`，锁定引擎沿用触发技默认的 `askToSkillInvoke`；无接受回复时根本没有写入双闪要求，并非 `AimData` 到牌效果的数据传播失效。
- 修复：第二段必然效果显式使用 `Util.TrueFunc`，首段可选扩目标仍保留自己的询问。
- 回归：`tests/wu_phases.lua` 的 `testDuanbingDistanceOneTargetNeedsTwoJinks`，通过实际用杀与一张闪回复验证目标仍受伤。

## 外部套件缺少描述符，混入上游用例（已修复）

- 现象：汉包、吴包定向验证曾运行超出目标文件范围的上游内置用例，产生无关失败。
- 根因：外部套件未返回其 LuaUnit 分组描述符，运行器没有按目标套件隔离执行。
- 修复：文件末尾返回 `return { name = "hanjin_套件名" }`，与测试类名 `Testhanjin_套件名` 对应；新套件从项目模板开始。入口要求非空成功汇总，空模板不能当作通过。
- 复核依据：吴阶段套件补齐描述符后只运行本文件用例；历史定向结果见[共享验证证据](implementation/generals/verification-evidence.md#wu_phases)。

## 请求覆盖误拦截引擎内部选择（已修复）

- 现象：反间等测试覆盖 `askToChoice` 后，触发顺序选择得到普通分支字符串，引擎按技能名查找时得到 nil。
- 根因：覆盖未检查 `params.skill_name`，连 `skill_name = "trigger"` 的多技能选择也被接管。
- 修复：只覆盖目标技能请求，其他请求调用原方法；结束或断言异常后恢复覆盖，避免污染后续测试。
- 回归入口：`tests/wu_support.lua` 的反间、英魂与固政真实流程用例；可复用辅助的隔离与恢复另由 `tests/test_support.lua` 验证。
