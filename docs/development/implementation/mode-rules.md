# 汉晋模式公共接线

三个模式从[模式入口](../../../pkg/qiao_mode/init.lua)进入[公共构造器](../../../pkg/qiao_mode/mode.lua)。当前验证基线见[开发状态](../status.md#当前验收基线)。

## 房间与开局

- 大合集和自由模式由同一模式构造器分流。大合集读取模式设置的候选数和选将时长，时长缺省为 90 秒。被覆盖的通用游戏设置在[客户端设置入口](skill-ui.md)置灰，自由模式保留可编辑的上游设置。服务端以 [selection.lua](../../../pkg/qiao_mode/rules/selection.lua) 过滤禁将、候选和非法配将。关联查找见[势力禁选](faction-ban.md)与[客将](guest-factions.md)。
- [faq_core_rules.lua](../../../pkg/qiao_mode/rules/faq_core_rules.lua) 在 `GameEvent.DrawInitial` 处理后置位手气卡。大合集按 0 次通用手气卡计算，7 人及以上从 7 号位各发一次。自由模式在房间通用次数之外按「后置位补偿」设置发放。每次换手牌后更新发牌结束事件里的实际初始手牌，供应变等后续入口读取。
- [房间规则回归](../../../tests/qiao_rules.lua#L191)验证两模式设置、联动选项存在或缺失、选将请求执行和时长。[FAQ 专项](../../../tests/faq_core_rules.lua#L160)验证座位、自由模式开关、重抽牌和事件。设置页离屏覆盖与人工边界见[开发状态](../status.md#最近验证记录)。

### 锁定势力

「游戏规则」在「模式设置」首项，默认斗地主。正式扩展的 [LockedGameRuleRow.qml](../../../pkg/qiao_mode/qml/LockedGameRuleRow.qml) 将选择映射为建房容量 3 或 4，并锁定通用设置中的人数控件。创房可行性检查和服务端开局都校验规则与人数一致。建房页读取当前禁将方案，检查房主配置的候选势力中是否至少存在一组可发足最低配额的两方。服务端再按实际跨局禁选结果和将池确认。缺少规则键的旧设置仍可按 3 或 4 人开局。锁定势力的客户端与服务端均固定关闭自由选将。3／4 人局只使用可入池的效忠版，隐藏无效的原版野心家数量设置。

[模式规则](../../rules/faction-ban.md#锁定势力)由 [locked_factions.lua](../../../pkg/qiao_mode/rules/locked_factions.lua) 在大合集的禁选步骤结束后分配。按实际可用的牌为每席匹配候选。每人的基础候选数统一为 2 至 5 张，地主加两张。优先满足房主设置，候选不足时统一下调基础张数。最低配额也无法满足时，提示原因并取消开局。三人局为地主再补两张同势力候选，选将提示包含本人身份、座次和获配势力。服务端按候选与分配势力复核选将及同名替换。启用客将替换时，请求照常发送客籍与插画数据，重抽资格列表为空，服务端拒绝重抽。

开局双将体力计算后增加斗地主 1 号位的体力与上限，按上游欢乐斗地主的默认接线授予引擎的 `m_feiyang` 和 `m_bahu`。其实现分别位于 FreeKill v0.5.25 的 `standard/pkg/skills/feiyang.lua` 与 `standard/pkg/skills/bahu.lua`。二对二通过 `getAdjustedProperty` 在 `DrawInitialCards` 前调整发牌数。[Gitee 斗地主模式](https://gitee.com/qsgs-fans/gamemode/blob/fd19e8863c9507f710e937db9fabccbdffed840d/pkg/gamemodes/1v2.lua)

[鏖战入口](../../../pkg/qiao_mode/rules/battle_royal.lua)根据锁定势力的房间开关决定是否进入。开关缺省关闭，开启后使用国战回合开始条件，三人全暗开局时首回合即进入鏖战。该开关作用于汉晋和上游的进入入口。

选将提示复用引擎的座次翻译。三人局显示身份、座次和获配势力，四人局显示座次和获配势力。[开局专项用例](../../../tests/locked_factions.lua)覆盖两种提示、候选数量、鏖战开关、跨局禁选、客将与同名替换、三人场明置与模式技能，以及四人场队列／围攻及发牌。

有 PySide6 和锁定版开发运行时的核心检出时，可运行 `python scripts/check_locked_factions_ui.py`。该离屏回归使用原生建房与模式设置页，验证规则切换、人数请求和禁将方案更新。

## 势力与身份

[faq_core_rules.lua](../../../pkg/qiao_mode/rules/faq_core_rules.lua) 为明置、升变和效忠提供统一上限及预演。10 人局同一势力最多 4 名，第 5 名转野。已死亡同势力角色参与该项计数。4 人及以下局禁止普通升变、死亡继位及首次明置获得先驱。人数进入阈值和事件窗见[人数与标记规则](../../rules/player-count-and-marks.md)。[FAQ 专项](../../../tests/faq_core_rules.lua#L84)覆盖超员、升变与效忠的上限，以及[四人局限制](../../../tests/faq_core_rules.lua#L308)。

## 明暗置

房间加载[国战明置处理](../../../pkg/qiao_mode/mode.lua)与[预亮入口](../../../pkg/qiao_mode/rules/skill_prelight.lua)。预亮只在正式请求中按引擎支持的技能类型开放，并在提交时复核限制。将牌明暗置、移动或失技之后由[牌上技能监听](../../../pkg/qiao_mode/skills/general_card_skills_rule.lua)同步后天附将技能与阵法入口。作用域与迁移见[武将来源职责](general-exchange.md#公共武将来源职责)。[模式回归](../../../tests/mode_rules.lua#L220)通过真实回合开始询问验证主、副、双亮、取消与禁止明置。[技能来源回归](../../../tests/general_card_skills.lua)覆盖暗置、再亮和失去来源。

## 轮次、回合、阶段与死亡

正常轮次、回合及阶段以锁定上游国战流程为底。汉晋在 [mode.lua](../../../pkg/qiao_mode/mode.lua) 的房间启动阶段装入需要跨技能复用的历史记录与结算监听。轮次、回合、阶段的技能次数及换将历史按[交换历史监听](../../../pkg/qiao_mode/skills/exchange_history.lua)清理。普通升变接 `TurnStart`，死亡继位接 `BeforeGameOverJudge`，胜负由[第二君主规则接线](second-lord.md#扩展内实现)接管。技能或标记自己的回合结束和死亡收尾在对应主记录中维护。时机裁定总表见[轮次、回合、死亡和明置规则](../../rules/turn-death-and-reveal-timing.md)，表中的专属规则应跳到具体接线和用例确认覆盖。

## 移出游戏

[removed_targets.lua](../../../pkg/qiao_mode/rules/removed_targets.lua) 为双方提供 `getPresentPlayers()`。汉晋服务端过滤普通选人候选，并在接收主动技和普通用牌回包时拒绝已移出的发动者或目标。角色移回后再次进入普通候选。胜负等明确计入移出者的算法按各自规则运行。正常目标筛选和有既定目标的效果都需要在相应结算点检查在场状态。[移出专项](../../../tests/qiao_removed_cards.lua#L120)覆盖真实【调虎离山】、移回早于破军归还、人数和手牌上限以及过期回包。

## 阵法召唤

[array_summon.lua](../../../pkg/qiao_mode/rules/array_summon.lua) 根据实际明置武将与阵法来源同步公开入口。队列按相邻方向邀请，围攻按两侧路径分别判断候选。同一次召唤遇到同一名暗将只问一次，即使已拒绝或超时。开始以及每次响应后按人数复核能否继续招募。同势力人数包括已死亡和暂时移出的角色，十人局到第四名时停止。共有入口按当前出牌阶段计次。公开座次命中的暗将都会收到私有询问，避免通过提示与否暴露势力。询问展示发起人和阵法种类，有资格时才列出可明置的位置。技能说明见[阵包与势包规则](../../rules/zhen-shi-generals.md)及[阵法召唤术语](../../../rulebook/terms/description-terms/arraycall.md)。

[阵法专项](../../../tests/array_summon.lua)经过客户端选择和服务端回包，分别覆盖队列、围攻、重合候选和十人局达到第四名同势力后停止。取消、超时、标题及联机复测见[开发状态](../status.md#最近验证记录)。

## 标记上限

[FAQ 安装入口](../../../pkg/qiao_mode/rules/faq_core_rules.lua) 包装汉晋房间的 `H.addHegMark`，由各合法来源获得阴阳鱼时都在 5 枚上限处截断。开局双亮、升变后重判和已领取状态各自走[第二君主](second-lord.md)或上游的对应时机。[FAQ 专项](../../../tests/faq_core_rules.lua#L361)验证多来源获标记和模式隔离。君主旗、诏书和“赐”见各自所属武将。

标记的消耗条件、当前上游入口及待适配项见[国战标记与大旗说明](skill-ui.md#国战标记与大旗说明)。

## 自由用牌

[free_use.lua](../../../pkg/qiao_mode/rules/free_use.lua) 的 `askToUseCard` 设置 `not_passive`，使客户端自由用牌请求排除没有本次响应时机的被动牌。服务端根据出牌者、牌型、禁止和[公共目标条件](card-use-targets.md)复核回包，沿用[只能当](only-as.md)的来源校验。返回值是待执行数据，调用方执行一次。正式调用包括[牛金](generals/standard/retinue-niujin.md#niujin)、[风物](generals/standard/jin016.md#jin016-2)和[四海归平](../../../pkg/qiao_cards/skills/sihai_guiping.lua)。用例入口见各技能的主记录及[技能界面](skill-ui.md)。

## 配将体力

[配将体力规则](../../rules/general-principles.md#配将体力贡献与武将状态)的开局与升变接线共用 [pair_hp.lua](../../../pkg/qiao_mode/rules/pair_hp.lua)。魏、晋司马懿的修正见[应期](generals/standard/wei002.md#wei002-3)。

`pair_hp.lua` 在上游开局广播后将双 2.5 组合的体力上限和体力修正为 4，在已有的 `HalfMaxHpLeft` 记录两枚待领阴阳鱼。双亮时，汉晋规则在上游单枚奖励前发放两枚并清空待领记录。升变使用同一数量查询。原生用例用正式皇甫嵩与关羽，经开局广播及两次明置验证首亮不发、双亮发两枚。

## 拼点入口

拼点入口沿用锁定引擎的 `发起者:canPindian(对手)`。该查询同时检查双方手牌和发起方向的禁止状态。[烈刃](generals/standard/shu015.md#shu015-2)在发出询问前和实际拼点前均按同一方向检查资格。[密诏](generals/standard/han001.md#han001-2)先交牌，因此在交牌后再确定合法拼点对象。其余拼点主动技或首动作拼点的触发技在提供发动或目标时检查资格。
