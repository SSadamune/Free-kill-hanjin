# 可复用的故障案例

本页保留触发条件、已确认根因、修复与回归入口，供定位同类问题；不是游戏规则，也不记录完整排障流水账。通用处理方法见[测试规范](testing.md)，最新验证结果见[开发状态](status.md)。

## 新核心布局下的超时与翼从回归

- 控制台适配原先只处理运行时根目录。安装 `packages/freekill-core` 后，原生程序加载该目录下的未适配 `Request`，无限时间和超时免踢测试因此失败。开发同步现按已安装的核心布局应用适配。回归见 `tests/python/test_prepare_runtime.py` 和 `tests/console_timeout.lua`。
- 通用选将接口在新核心用 `canUseGeneral` 过滤回包，会因翼从的 `hidden` 标记拒绝本来合法的选择。翼从转换复用相同的卡面请求，由本次可得兵种列表校验回复。`tests/commander_retinue.lua` 检查真实候选，并选择与默认回复不同的兵种。
- 虎卫军的上游主动技可能用 `nil` 表示不可选。回归通过真实客户端请求处理器的 `targetValidity` 判断界面可选状态，同时核对合法来源及第二步目标。见 `tests/wei_retinues.lua`。

## 实战缺陷复盘（Issue #20、#21）

- **已有用例走到了结算，漏过了入口。** 倾国的旧用例直接调用 `viewAs`，跳过响应表达式匹配；仁德预填选中【杀】的回复，跳过客户端牌名框；突袭只查询服务端能否转换，未检查玩家可点击的技能。穆顺的预填回复同样绕过了玩家实际看到的候选。相应回归改用请求载荷、候选或确认回包，覆盖失败处，并保留原结算断言。相关套件为 `wei_phases`、`shu_conversion`、`wei_support`、`han_retinues`。
- **测试引擎可以验证大部分接口，但有明确边界。** 西园军未命中时的 `false` 会隐藏普通手牌，原用例只查被标记的一张，补查持有者的未标记手牌即可复现。麒麟弓的 AI 请求能在自动化中跑真实载荷。另一方面，同进程客户端可能读到服务端牌面数据，也不会完整重放座次和房间设置；神授思召须用只有公开标记的牌、仁德须按真实环形座次同步夹具。Lua 请求处理器和 QML 静态检查均无法证明实际弹窗已渲染、可点击，虎卫军和州郡领兵印仍须点验。
- **部分缺陷来自实现时对接口或结算的假设。** 牛金把主动用牌当作响应窗口调用，挥鞭把后段回复对象提前设成发动门槛，应期为无读者的开局记录注册了一个可预亮触发。审阅时先确认请求种类、来源、候选与时机，再复用对应的公共入口；规则已要求武将技能先于装备技能时保留原顺序。
- **固政的测试超时出在断言。** 测试比较了包含房间引用的角色对象，改用角色 ID 后保留了原请求和回包验证。客户端覆盖和夹具写法见[测试规范](testing.md)。故障来源见 [Issue #20](https://github.com/SSadamune/Free-kill-hanjin/issues/20) 和 [Issue #21](https://github.com/SSadamune/Free-kill-hanjin/issues/21)。

## 客户端房间查询（已修路径与防复发）

- 现象：刘协搭配徐晃、明置副将后进入出牌阶段，密诏按钮检查报 `player.room` 为 nil。
- 根因：可用性、交牌下限及提示会在 `ClientPlayer` 上计算，不能假定它有 `ServerPlayer.room`。
- 修复：密诏使用兼容客户端的当前房间接口读取可见状态，保留服务端执行前复核。
- 回归：`tests/han001_liuxie.lua` 中 `testMZ31RealClientPlayerWithoutRoomComputesKnownFaction`、`testMZ32ClientWithoutRoomPredictsHiddenOwnFaction`。
- 群包再次出现同类问题：张角／华佗进入出牌阶段，`ReqPlayCard.skillButtonValidity` 调用除疠 `can_use` 时访问 `player.room`。服务端效果用例通过不能证明客户端按钮可用；应沿调用链检查 `can_use`、目标筛选及它们调用的辅助函数。
- 夹具也须使用客户端房间：仅换成 `ClientPlayer` 而让 `Fk:currentRoom()` 仍返回服务端房间，会混用两套角色和牌区。`tests/qun_basic.lua` 的 `withClientRoom` 展示成套客户端角色、独立牌区及异常后恢复上下文；测试同时断言合法场景可用、无候选和次数耗尽时禁用，避免用空列表掩盖错误。
- 第三次复发：君曹操授荀彧驱虎后，`ReqPlayCard.skillButtonValidity` 由 `can_use` 调用 `eligibleTargets`，内部仍用 `player.room.alive_players`。已有规范明确要求客户端验证，但此前只修复密诏、除疠等已报技能，未对驱虎及其 helper 执行，属于审阅与验收遗漏；服务端 `on_use` 测试不能触达按钮路径。防复发：默认套件 `tests/client_active_skills.lua` 自动枚举正式武将与翼从的主动／转换技能，使用真实 `ClientPlayer` 查询按钮；驱虎、三陈、伪溃、强袭增加合法目标可用断言，驱虎另测无候选及次数耗尽。客户端夹具拒绝服务端私有字段。复杂选择入口另补代表性用例，静态审阅须跟随 `can_use`、目标／牌筛选等回调调用的 helper；服务端 `on_use`/trigger 不机械替换。按钮广覆盖不等于逐技能全部选择、转换和提示分支均已动态验收。

## 卡牌脚注泄漏富文本标签

- 现象：使用助战杀时，结算区卡牌上显示 `</b></font>` 等标签并折行遮挡牌面。
- 接口核对：锁定引擎 `Client:parseMsg(msg, true)` 仍给玩家名加 `font/b` 标签；实体牌 `setCardNote` 与虚拟牌 `showVirtualCard` 都调用它。截图含张虎&乐綝，但 `&` 是否导致 Qt AutoText 解析失败尚未通过渲染验证。
- 修复：正式扩展的 `QiaoClient:parseMsg` 仅对汉晋模式的 `nocolor == true` 输出去除这些格式标签；继承两条通知路径，普通日志及其他模式保留原行为，不修改本体 QML。
- 回归：`tests/han001_liuxie.lua` 的 `testCardFootnoteStripsRichTextOnlyInQiaoMode` 使用正式双将名及真实 `##UseCardTo` 消息，捕获两条客户端通知，核对脚注、普通日志与模式隔离；客户端实际渲染待人工验收。

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

## 隐藏武将 fake/prelight 与技能来源不同步（已修复）

- 现象：暗置普通张角升变君张角后仍显示预亮的旧雷击/鬼道，弘法不可用；截图中的绿色旧技能与真实复现一致。
- 架构：`General` 定义只是牌面技能清单；角色实际状态分散在 `player.player_skills`、`_fake_skills`、`prelighted_skills`、`derivative_skills`。`changeHero` 按当前 `player.general` 清理旧技能，暗置时该值是 `anjiang`，不会看到旧普通将 fake；这些列表必须由升变流程按 `actual_main` 显式同步。
- 另一层：`弘法`/`章武` 原带 `Skill.Lord`，`ChangeProperty` 用身份模式的 `isLord` 和 `getSkillNameList(isLord)` 过滤，国战势力角色不会获得；`Player:hasSkill` 本身不按 Lord 过滤，`Player:canAttachSkill` 才是获取限制。两者不能混说。
- 修复：公共升变在换将前清理旧主将 fake/prelight，只删 fake 且保留实际独立来源；两个国战君主技能移除身份模式 Lord 获取标签，君主资格仍按 `general_versions` 和国战牌来源。
- 回归：`tests/second_lord.lua` 真实 `qiao_heg__qun010` + 暗貂蝉、真实 `qiao_heg__shu001`、独立同名鬼道来源；33/33。君主将局部套件各 4/4。此前测试君主技能没有 `Skill.Lord`，旧技能断言只查 `hasSkill`，未检查 fake 与预亮列表；正式君主局部套件又绕开了实际升变，因此正常路径的来源与标签问题同时漏检。

### 本次漏检的复盘

需求“技能随武将牌走”已明确，问题在实现与验收：把通用 `changeHero` 当成完整国战升变接口，没有核实它在旧位置为 `anjiang` 时的来源同步；又把国战君主技直接映射为身份模式主公技标签。暗将升变是常规路径，不属于罕见边缘。

公共升变测试与正式君主技能测试分别通过，却没有验证两者接合后的真实流程。审阅接受了这些局部结果，没有检查离场旧牌的 fake/prelight 来源是否仍在，也没有验证君主技实际获得并建立旗来源。后续同类改动以一条真实武将主流程核对“旧牌来源撤回、新牌来源安装、其他来源保留”，复用已有公共回归，不以增加无关测试数量代替接口核实。

## 选择与执行接口职责混淆（已修复）

- 风险：虚拟用牌助手可能在返回前已执行；调用者再执行会重复结算，也可能使校验晚于实际效果。
- 修复：公共目标层区分只选择、返回待执行数据与选择后执行，先附加策略并复核，再由单一入口执行。接口契约见[目标实现文档](implementation/card-use-targets.md)。
- 回归：`tests/card_use_targets.lua` 的执行次数、失败无副作用及复杂目标集成验证。

## 功能交付不能依赖开发本体补丁（方案已纠正）

密诏单选切换最初被尝试做为本地客户端适配，随后撤回。最终通过扩展内的汉晋客户端注册与请求处理器发布；本地开发脚本不承担该功能。回归同时覆盖出牌与主动技能询问路径，安装包检查包含客户端和接线。此例说明应先确认成品加载路径，再实现玩家交互，不应把本地可用当作功能交付完成。

## 多个 boardgame 复用同一引擎导致重复初始化（已修复）

- 现象：加载时牌型数量从 179 增至 358，随后报 `Duplicate game_mode qiao_heg_mode detected`；遍历顺序不同会使故障时隐时现。
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
- 修复：文件末尾返回 `return { name = "qiao_套件名" }`，与测试类名 `Testqiao_套件名` 对应；新套件从项目模板开始。入口要求非空成功汇总，空模板不能当作通过。
- 复核依据：吴阶段套件补齐描述符后只运行本文件用例；历史定向结果见[共享验证证据](implementation/generals/verification-evidence.md#wu_phases)。

## 请求覆盖误拦截引擎内部选择（已修复）

- 现象：反间等测试覆盖 `askToChoice` 后，触发顺序选择得到普通分支字符串，引擎按技能名查找时得到 nil。
- 根因：覆盖未检查 `params.skill_name`，连 `skill_name = "trigger"` 的多技能选择也被接管。
- 修复：只覆盖目标技能请求，其他请求调用原方法；结束或断言异常后恢复覆盖，避免污染后续测试。
- 回归入口：`tests/wu_support.lua` 的反间、英魂与固政真实流程用例；可复用辅助的隔离与恢复另由 `tests/test_support.lua` 验证。


### 玩家对象的断言与房间协程

马隆锋械、君刘备天钺和将包登记用例曾在游戏流程跑完后卡在对象断言。遇到类似超时时，先查看 `scripts/test.py` 在超时分支补打的子进程输出，再按[夹具与失败诊断](testing.md#夹具与失败诊断)核对断言是否遍历了房间对象图。

房间内清牌、安装武将等 helper 不得再次调用 `FkTest.runInRoom`；由外层测试统一进入房间协程。嵌套恢复同一协程会产生 critical，并让后续准备步骤没有执行，不能据此推断正式技能未注册。测试准备保留至少两个势力，避免明置准备将牌时提前结束游戏。

## 新核心布局下扩展 postLoad 相对 require 失效（已修复）

- 现象：使用 `packages/freekill-core` 布局时，qiao 的 `postLoad` 报 `module 'packages.qiao...' not found`，对应文件实际存在。
- 根因：`ModManager:loadPackages` 在 `postLoad` 前把工作目录切回核心包；引擎沙箱将 `package` 置空，扩展不能调整 `package.path`。
- 修复：扩展加载时解析回调需要的模块，`postLoad` 再注册武将、模式和卡牌数据。引擎工作目录由引擎维护，避免回调中途抛错后跳过恢复。详见[扩展加载与新核心布局](implementation/extension-loading.md)。
- 回归：在新核心布局核对工作目录和汉晋模式注册，并通过真实测试房间触发模式规则。旧核心布局的默认套件单独执行。
