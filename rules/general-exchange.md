# 交换武将

适用于 `hanjin_heg_mode`。本文规定技能或效果要求「交换武将」时的结算方式。公共交换规则已实现为独立模块 `pkg/hanjin_mode/rules/general_exchange.lua`；专测为 `tests/general_exchange.lua`，已由集成会话纳入 `tests/all.lua`。

## 合法位置

- 交换的双方是两个不同的、已明置的武将牌位置。同一角色可以交换自己的主将与副将；两名角色之间须按当前国战关系互为同势力，主与主、副与副、主与副均可交换。只要求被选中的两张牌明置，角色的另一张牌可以是暗将。
- 普通士兵和翼从均可交换。君主武将和野心家专属武将默认不可交换，只有明确的特殊说明可以放宽此限制。限制针对所选武将牌；检查另一位置时仍按该牌自身的类别判断。
- 交换完成后两张牌仍明置，占据彼此原来的位置。双方沿用各自原有的体力上限计算结果；交换不重算主副将体力贡献，也不改变当前体力。

## 哪些状态随牌移动

| 项目 | 交换后的处理 |
| --- | --- |
| 武将技能 | 由新位置的持有者按技能原文使用。主将技、副将技按新位置判断可用性；位置条件暂不满足时，仍保存该牌的发动记录。 |
| 技能发动状态 | 保留武将牌上各技能在阶段、回合、轮次及整局的已用次数、分支记录，以及技能自行记录的已发动状态。已用限定技仍为已用，本轮发动过的轮次技直到原定重置时点才可再次发动。 |
| 武将牌上的牌 | 邓艾的「田」、周泰的「创」等随各自武将牌到新位置。保留实体牌、原有次序和可见性规则。双方都有牌堆时分别移交；同人交换主副将时只需维持正确归属。 |
| 士兵与翼从 | 士兵可参与交换，翼从随牌保留兵种、专属卡面、技能及其发动状态。普通士兵交换到新位置视为该位置获得士兵，按统领规则在全部新位置就绪后转换。 |
| 角色自身的状态 | 手牌、装备、判定区以及属于角色或未参与交换武将的记录留在原处。技能产生的角色标记需按该技能定义区分归属，不能整批随将搬移。 |

## 扩展内实现方案

公共操作位于 `pkg/hanjin_mode/rules/general_exchange.lua`。锁定版本 hegemony 的 `util.lua` 中，`H.swapDeputy` 已示范如何识别技能的 `derived_piles`、避免失去技能时清掉牌堆，以及迁移各时间范围的技能次数。它只处理两个不同角色的副将，而且允许处理暗置副将，不能直接作为本规则的入口；本模块不修改也不复用该流程。

1. 调用效果传入两个「角色、主副将位」及其明示例外。服务端在结算前复核位置、明置、势力和武将类别；条件失效则双方均不移动。明置只读公开的 `general` / `deputyGeneral`，服务端知道暗将的 `__heg_general` / `__heg_deputy` 也不能让暗置牌被选中。
2. 在改动任一方前，同时记录两张牌的身份、技能来源、各范围及分支的使用记录、技能自定义状态、每个具名牌堆的实体牌 ID。引擎的使用历史按角色与技能名保存，汉晋技能若可能有同名来源，应在发动时就记录所属武将牌；交换时单靠总次数无法还原归属。同名牌堆也须事先区分来源。
3. 在一次交换结算内更新双方公开位置及对应的国战主副将记录，按新位置同步技能和附属状态。跳过会清空附属牌或重置限定技的普通失技、获技初始化；保留其他来源赋予的同名技能。跨角色时按原牌堆分别移交实体牌，同角色时避免产生一次多余的移牌。交换不经过移除武将、生成士兵、回将池或重新明置流程。
4. 两侧状态就绪后再通知交换完成。客户端须能看到正确的主副将卡面、技能可用状态及具备查看权限的牌堆；重连以服务端结算结果为准。

### 公共 API

- `Exchange.validate(room, first, second, options)`：只校验，返回 `true` 或 `false, reason`。
- `Exchange.exchange(room, first, second, options)`：成功返回结算上下文；失败返回 `false, reason`，且双方都不移动。
- 位置参数为 `{ player = ServerPlayer, isDeputy = boolean, general = 可选预期牌名 }`。可选 `general` 用于拒绝过期的选择结果。
- 默认策略只允许当前国战关系下互为同势力的两名角色；同一角色的主副将交换自然满足。未来的特殊说明通过 `options.cross_kingdom = true` 或 `options.kingdom_allowed(from, to)` 明示放宽。君主武将、野心家专属武将默认拒绝，通过 `options.allow_lord`、`options.allow_wild` 或 `options.allowed_generals[generalName]` 明示放宽。未传例外时不会自行放宽。
- `Exchange.registerSoldierGeneral(name, "white"|"retinue")` 供统领模块登记独立翼从；普通士兵默认识别 `blank_shibing` / `blank_nvshibing`，不按 `blank_` 前缀推定所有独立翼从 ID。
- `Exchange.registerLordGeneral(name)` 允许未来使用不含 `lord` 字样的独立君主武将 ID 参与类别校验；默认会识别牌名/真名含 `lord`、显式 `general.is_lord`、上游 `HegUtil.lordGenerals` 映射及带主公技标签的武将。
- `Exchange.registerSkillMarks(skillName, marks)` 登记需要随牌移动的自定义技能标记。引擎转换技/使命技标记和 `<skill>-<suffix>` 形式的标记自动识别，不整批迁移角色标记。
- `Exchange.addCompletionListener(fn)` / `removeCompletionListener` / `clearCompletionListeners`：交换完成入口，见下节。
- 校验失败原因包括 `invalid_position`、`invalid_player`、`missing_position`、`not_revealed`、`unknown_general`、`stale_selection`、`same_position`、`different_kingdom`、`restricted_lord`、`restricted_wild`、`restricted_wild_deputy`。
- 即使显式放宽君主/野心家限制，野心家专属武将仍不得被交换到副将位（势力禁选规则要求其为唯一主将）；该情况返回 `restricted_wild_deputy`。

### 结算顺序与状态

1. **校验**：位置存在、所选牌公开明置、牌名可解析、两个位置不同、跨角色时势力关系成立（或显式放宽）、武将类别允许（或显式放宽）。任一项失败立即返回，不写任何状态。
2. **抓取快照**：两张牌的实际牌名、技能表（含相关技能）、各范围/分支使用记录、技能标记、每个具名牌堆的实体牌 ID。快照在任何写入之前完成。
3. **技能次数**：引擎按角色和技能名聚合，模块通过隐藏模式技 `#hanjin_exchange_history` 在 `fk.SkillEffect` 时把每次发动镜像到房间级账本（tag `hanjin_skill_ledger_v1`，按武将牌记录）。交换只迁移该牌账本中的份额，源角色若仍有其他来源提供同名技能则保留其余次数。账本在阶段、回合、轮次重置时与 `Room:clearHistory` 同步清空对应范围，整局次数不重置；直接写在引擎历史里、账本中没有记录的次数只在“该牌是唯一来源”时保守回退迁移。换回原处不会重置或重复扣次。
4. **公开位置**：用低层 `setPlayerGeneral` / `setDeputyGeneral` 更新两个所选位置并广播 `general` / `deputyGeneral`，同步 `__heg_general` / `__heg_deputy`。所选主将移动时更新 `__heg_wild`。不调用 `changeHero`、`revealGeneral`、`removeGeneral` 或回将池流程；不重算体力上限，不修改当前体力。
5. **技能**：按新位置的主将技/副将技限制重新计算该角色应有的实技能集合，只增删由这两张牌提供的技能。跳过 `handleAddLoseSkills` 和技能骨架的普通 `onLose`/`onAcquire`（它们可能弃置具名牌堆或重置限定技状态），改为直接 `player:addSkill` / `player:loseSkill` 并手动广播 `AddSkill` / `LoseSkill`。其他位置、装备或衍生技能提供的同名技能保留；位置条件不满足的主将技/副将技不激活，但其次数与标记仍随牌保存。
6. **牌堆**：在技能同步后，把每张牌所属的具名牌堆实体牌按原顺序移交到新持有者的同名牌堆。跨角色分别移交；同一角色的主副将交换不产生多余的移牌。牌的区域、拥有者和可见性由引擎移牌流程更新，其他武将的牌堆不受影响。
7. **技能标记**：转换技/使命技、`<skill>-<suffix>` 及显式登记的标记随牌移动；源角色仍有同名技能来源时保留副本。其他角色标记、`CompanionEffect`、`HalfMaxHpLeft`、`__heg_kingdom` 等角色级状态留在原处。
8. **完成通知**：先广播牌堆与技能状态，再发送交换日志，最后同步调用完成监听器。监听器看到的是双方都已就绪的状态；在监听器返回前不得再次移动这两个位置。

### 结算上下文

成功时 `Exchange.exchange` 返回：

```lua
{
  room = room, same_player = boolean, options = options,
  sides = {
    { player = p1, isDeputy = bool, previous = "旧牌名", general = "新牌名" },
    { player = p2, isDeputy = bool, previous = "旧牌名", general = "新牌名" },
  },
  moved = {
    { from = { player = p1, isDeputy = bool }, to = { player = p2, isDeputy = bool },
      general = "移动的牌名", soldier = bool, white_soldier = bool, retinue = bool },
    -- 反方向一条
  },
  obtained_soldiers = {
    { player = p2, isDeputy = bool, general = "blank_shibing",
      from_player = p1, from_isDeputy = bool, same_player = bool },
    -- 每个交换到新位置的白板士兵一条
  },
}
```

### 与上游交换流程的关系

- `HegUtil.swapDeputy` 保持原样，仍可被上游内容调用；本模块不覆盖、不修改它。专测中单独验证上游副将交换在汉晋房间仍可工作，且不会触发本模块的完成监听器。
- 两者的差异：上游只交换两名角色的副将、允许暗置副将、通过 `changeHero` 走普通失技/获技并重算国战标记；本模块按本文要求只接受公开明置牌、支持任意两个位置、跳过会破坏附属牌或限定技状态的普通初始化，并保留体力上限与当前体力。

### 当前边界

- 界面不提供独立的“选两个位置”交互，由调用技能负责选位并传入显式例外。
- 同一角色两个位置提供同名技能时，引擎无法区分这次发动来自哪一张牌；账本按“明置位置优先、主将优先”的确定规则归属。自定义技能若需要更精确的归属，应在设计时避免两个位置提供同名技能，或通过技能标记登记保留状态。
- 同一角色两个位置使用同一具名牌堆名时，引擎只有一个同名牌堆，交换时只能整体移交；这是引擎侧限制。
- 跨势力例外只负责位置和技能/牌堆迁移，是否连带改变角色势力、`role`、`__heg_kingdom` 等由未来明确该例外规则的效果自行决定；本模块默认不改变这些角色级状态。
- 重连使用服务端结算后的玩家属性、技能和牌堆序列化结果，不保存客户端固有动画状态。

## 与统领/翼从的接入约定

交换模块在双方新位置、技能和牌堆全部就绪后，通过 `Exchange.addCompletionListener(fn)` 同步调用监听器。`fn(room, context)` 中的 `context.sides` 给出每个位置的 `previous`/`general`，`context.obtained_soldiers` 列出交换到新位置的白板士兵。统领模块据此：

1. 将已明置统领的来源改记到新持有者和新势力；跨势力时移除旧势力登记并加入新势力登记。
2. 复核被换走的统领已不在持有者任一位置时，停止其统领能力，但保留原势力登记和全部兵种。
3. 在所有来源更新后，把 `obtained_soldiers` 中的白板士兵按新势力逐位转换；全部新位置就绪前不处理。
4. 不重复改写交换模块已经迁移的武将、技能、牌堆或体力上限。

实现位于 `pkg/hanjin_mode/rules/commander_retinue.lua` 的 `onExchangeCompleted`；交换模块不得在监听器返回前再次移动位置。该监听器已在统领模块加载时通过 `Exchange.addCompletionListener` 注册，交换模块不直接依赖统领模块。

## 自动化验收

`tests/general_exchange.lua` 使用独立的 `tests/support/general_exchange_content.lua` 测试内容（隐藏的测试武将、限定/轮次/分支/转换/主将技/副将技/具名牌堆/翼从技），覆盖：

- 同人主副互换、跨角色同位与跨位互换；失败时双方位置、技能与牌堆均不移动。
- 敌方、被选牌暗置、同一位置重复选择、过期牌名、非法角色和非法位置参数被拒绝；未选位置暗置不阻塞。
- 君主、野心家专属、跨势力默认拒绝，显式 `allow_lord` / `allow_wild` / `allowed_generals` / `cross_kingdom` 放宽。
- 体力贡献不同的牌交换后 `maxHp`、`hp` 原样保留。
- 限定技整局次数、轮次技与分支技的轮次次数、转换技标记随牌移动；换回、再换、按原重置点重置时不重置或重复扣次。
- 主将技/副将技到错误位置不激活，但其次数保留，换回后继续生效。
- 同名技能由其他位置提供时不被清除。
- 具名牌堆按实体牌 ID、归属、顺序移交；另一名角色的同名牌堆及其他牌堆不受影响；同人交换不产生多余移牌。
- 普通士兵、已登记翼从的卡面、技能与“获得白板士兵”上下文；完成监听器在双方状态就绪后收到 `sides` 与 `obtained_soldiers`。
- 上游 `HegUtil.swapDeputy` 在汉晋房间仍可独立工作，且不触发本模块的完成入口。

## 验收要点

- 同人主副互换、队友同位及跨位互换都成功；敌方、任一所选牌暗置、默认受限武将均不能交换。未选位置暗置不妨碍合法交换。
- 让体力贡献不同的主副将跨位交换，核对双方体力上限及当前体力。普通士兵和带技能的翼从分别参与交换，检查位置、卡面及士兵身份。
- 在发动限定技与轮次技后交换，再换回原处，确认不会重置或重复扣次；进入下一轮，仅按原技能规则重置。另覆盖主副将技暂时失效、与其他来源同名的情况。
- 双方分别携带具名牌堆时交换，按实体牌 ID 核对归属、数量、顺序和可见性，同时检查其他武将的牌堆不受影响。
