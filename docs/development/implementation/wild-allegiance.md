# 野心家效忠：实现与验证

游戏语义见[对应规则](../../../rules/wild-allegiance.md)；当前实装与待办见[开发状态](../status.md)。本页保留接口、接线和验收依据，不替代规则裁定，历史覆盖说明不代表已完成全部人工验收。

## 扩展内实现

实现位置：

| 内容 | 文件/接口 |
| --- | --- |
| 效忠版登记 | `pkg/hanjin_mode/rules/wild_allegiance.lua`：`registerAllegiance(original, version)`、`variantOf`、`originalOf`、`isAllegiance`、`kingdomsOf`；每个原版只登记一个效忠版，原版必须是 `wild`，效忠版必须使用自身常规势力 |
| 统一版本登记与选将池 | `pkg/hanjin_mode/rules/general_versions.lua`：`Versions.register` 调用 `wild_allegiance` 登记效忠版；`Versions.plan` 决定本局可发版本，`pkg/hanjin_mode/rules/general_pool.lua` 再按客将势力解析并保存到房间 |
| 准备阶段升变 | `pkg/hanjin_mode/rules/ascension.lua`：`wild_candidates`、`on_preparation`、`ascend`；由 `pkg/hanjin_mode/skills/ascension_rule.lua` 在 `fk.EventPhaseStart` 的 `Player.Start` 触发 |
| 模式接线 | `pkg/hanjin_mode/mode.lua`：选将流程使用 `Versions.plan` → `Pool.resolve`；升变规则由模式规则技能加载 |

开局纯规则位于 `general_versions.planPool`（房间入口 `Versions.plan`），候选势力与允许上限来自房主设置（`faction_ban.resolveSettings`），不从将池或版本自身势力推断。它在发将前按本局人数和 `hanjin_wild_count` 决定原版保留/替换：四人及以下全部替换，五人以上按上限随机保留原版，未保留原版由已登记的效忠版代替；效忠版按自身登记势力参与允许集筛选，未通过、候选外或被直接放入牌堆的版本会被排除并禁用。每个原版只对应一个效忠版，入池路径按版本名去重。开局直接以效忠版入池不构成升变。

准备阶段由服务端读取暗置主将，仅向本人提供自愿升变选项；提交时重新检查主将仍暗置、原版专属关系、配将合法势力、人数预演和三个时机条件。多势力效忠版按每个可搭配势力分别生成候选，只提供通过全部条件的势力。升变成功后立即明置主将、确定所选势力、替换技能并清除原版野心家专属标记，然后按所有升变共用的体力上限/回复通则结算。拒绝或超时不改变原版、暗置状态和体力；同一角色每局最多升变一次。

## 自动化验收

`tests/wild_allegiance.lua` 覆盖：

- 首回合、场上其他未确定势力角色、目标势力在场君主三个时机条件分别成立；三者均不成立时不提供选项。
- 同势力有君主仍按普通人数规则预演，超员时不能效忠。
- 多势力效忠版只有合法搭配的势力被提供。
- 拒绝后保持原版、暗置和体力；升变后主将明置、势力与技能同步、原版标记清除。
- 开局直接以效忠版入池不执行升变，不增加体力上限或回复。
- 四人局全部原版由效忠版替换；五人局按上限保留原版；被禁势力的效忠版不入池；同一效忠版去重；原版被排除后不能经同名替换重新出现。
- 统一版本登记 `Versions.is_lord / is_loyalty / lord_version / loyalty_versions` 与 `wild_allegiance` 登记一致。

`tests/guest_allegiance.lua` 另行覆盖四人/五人开局计划（纯规则）、真实房间中的客将势力解析、选将、初始势力和连续重抽；`tests/wild_allegiance.lua` 覆盖准备阶段升变。两者使用独立的测试内容，不进入正式将池。
