# WEI002／JIN009 司马懿·应期：配将体力贡献实现与验证

本页记录[应期裁定](../../../../rules/generals/wei002-simayi.md)、[JIN009 的同文引用](../../../../rules/generals/jin009-simayi.md)与[配将体力贡献通则](../../../../rules/general-principles.md#配将体力贡献与武将状态)的程序接线。它不是正式规则条文；规则冲突时以 `rules/` 与 `rulebook/` 为准。

## 范围

- 只实现应期的配将体力贡献修正：☯️+2。
- 本页只记录配将体力接线。魏司马懿的狼顾、鹰视分别见[伤害组](wei-damage.md)与[改判组](wei-retrial.md)；JIN009 的权变、骤霆仍不在本批实装范围。
- 不修改 `General` 属性，不向其他游戏模式或上游包写入规则。
- 业务文件：`pkg/hanjin_mode/rules/pair_hp.lua`（新增）、`mode.lua`、`rules/ascension.lua`、`skill_wei002_3.lua`、`skill_jin009_3.lua`。

## 数值表示

引擎以**半格**保存体力贡献：1.5 体力记作 `3`，2.0 体力记作 `4`，2.5 体力记作 `5`。国战双将的体力上限为

```text
(主将贡献 + 主将调整) + (副将贡献 + 副将调整)  // 2
```

半格合计为奇数时，`HalfMaxHpLeft` 标记为 `1`，表示 1 个“半个阴阳鱼”。应期的“☯️+2”是 **2 个半格**，即 1 点体力上限，不是两枚可消耗的阴阳鱼标记：

```text
带应期：(主将贡献 + 副将贡献 + 2) // 2 = 原上限 + 1
余数：(合计 + 2) % 2 == 合计 % 2    -- 2 为偶数，奇偶余数不变
```

因此实现不发放 `@!!yinyangfish` 或 `hanjin_ascension_yinyang` 等标记，只在开局把组合上限补 1 点，并沿用引擎写入的奇偶余数标记。

## 身份判定

`pair_hp.lua` 的 `qualifies(name)` 表示“配将”是否为多势力或客将：

- **多势力**：牌面 `kingdom + subkingdom` 的已知势力数大于 1（`faction_ban.affiliations`），不看本局禁选过滤后的结果。
- **客将**：`guest_factions.guestKingdoms(name)` 非空，即资料登记中主势力之外另列了副势力。本局是否启用客将势力（主势力是否被禁）是另一个问题，不参与判定。

应期技能归属按武将技能名识别（`hanjin__skill_wei002_3`、`hanjin__skill_jin009_3`），因此君主版／效忠版若沿用同名技能也会生效；两个司马懿同场时只修正一次，不叠加。

## 接线

1. **开局**：`mode.lua` 覆盖 `HegLogic:broadcastGeneral`。先调用上游实现（按组合写入 `maxHp`、`hp`、`HalfMaxHpLeft`），再对每名角色执行 `PairHp.apply_start`。此时主将仍为 `anjiang`，实际配将从 `__heg_general`／`__heg_deputy` 标记读取，所以不等待明置。
2. **幂等**：`apply_start` 只做“把上限补到含应期的值”，差值不大于 0 时不再调整。模式流程与技能 `GameStart` 效果在同一时点先后触发也不会叠加。`skill_*_3.lua` 的 `GameStart` 效果复用同一 `apply_start`，并设置 `hanjinImplemented = true`；它不改变普通交换、移除、替换的结果。
3. **升变**：`rules/ascension.lua` 的 `pair_max_hp`、实际主副将读取与阴阳鱼奇偶判断改由 `pair_hp.lua` 提供。升变前后的组合上限都按含应期的公式计算，所以“同体力主将升变”不会被误判为上限增加；升变收益仍按原公共流程（新组合上限更高时加 1 点上限并回复 1 点体力）。
4. **不重算**：普通交换、移除、替换不调用 `apply_start`／`pair_max_hp`，因此已确定的体力上限不变。开局后属性变化不会撤回或追加应期收益。

## 客户端与模式隔离

- 应期不新增客户端交互或私有字段；`maxHp`、`hp`、`HalfMaxHpLeft` 都是引擎已有的公开属性／标记。
- 只在 `hanjin_heg_mode` 的 logic 上覆盖 `broadcastGeneral`；不修改上游 `hegemony` 包或其他模式。

## 测试

`tests/wei_pair_hp.lua` 已加入 `tests/all.lua`，4 项定向及最终默认套件均通过：

1. 开局真实接线：复刻 `chooseGenerals` 的 `setPlayerGeneral`／`setDeputyGeneral`／标记／暗置顺序，调用模式真实的 `broadcastGeneral`，分别验证 WEI002、JIN009 与客将配将得到 `3+4+2 = 9` 半格 → 上限 4、余数 1，且不发放可消耗阴阳鱼标记；普通配将保持 `7 → 3`。
2. 身份：本局魏可用时客将按原势力结算（`guest_factions` 解析为 `original`），应期仍按资料登记成立；牌面多势力对象（`kingdom + subkingdom`）与禁选无关。
3. 升变：开局 4 点上限后，升变到同为 1.5 体力的 JIN009（新组合仍含应期）保持 4、不多加；再升变到无应期的 2.0 体力主将（新组合 8 半格 → 4）仍保持 4。

2026-11-14 DSH 工具原生检查确认：`python scripts/test.py --file tests/wei_pair_hp.lua --timeout 120` 4/4 通过；最终 `python scripts/test.py --timeout 180` 608/608 通过。真实开局 `broadcastGeneral` 路径及升变复用已由专项触达；首次并行实现阶段未运行测试的限制现已解除。

## 未完成／风险

- 自动化已通过；客户端进房及联网／重连人工验证尚未完成。
- 既有用例 `tests/standard_generals.lua`（`testFormalRoomStartsWithBanSelectionAndHalfHp`，约 312–315 行）按“无修正”公式断言正式房间每名玩家的 `maxHp == sum // 2`。该公式在应期生效的配将上不再成立；需要把期望值改为 `pair_hp.half_hp(main, deputy) // 2`、余数改为同一合计 `% 2`。本轮未获授权修改该文件，未扩大范围。
- “普通交换后升变”的组合比较沿用既有实现（比较升变前后的组合上限公式），不改为比较实际 `maxHp`；若规则要求以实际上限为基准，需另轮裁定并补测试。
- 若将来出现独立的应期君主版／效忠版但使用不同技能名，需要把技能名登记到 `pair_hp.M.YINGQI_SKILLS`。
- 引擎在开局调用 `logic:broadcastGeneral` 的时机由现有起始上限测试间接印证；若实际调用点不同，`broadcastGeneral` 接线会失效而只剩技能 `GameStart` 效果，需要运行后确认。
