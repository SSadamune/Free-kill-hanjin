# 配将体力：跨势力技能实现与验证

本页是“配将体力”机制的主记录页：配将体力贡献修正及其在开局、升变时的复用。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。范围边界：只实现应期的配将体力贡献修正（☯️+2）；魏司马懿的[狼顾](damage.md#wei002-1)、[鹰视](retrial.md#wei002-2)与晋司马懿的权变、骤霆不在本页。晋 JIN009 的同文应期共享本页正文，不重复记录。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| WEI002 | 司马懿 | [应期](#wei002-3) |
| JIN009 | 司马懿 | 应期（同文共享，来源记录见 [WEI002 条目](#wei002-3)） |

## 技能条目

### 魏

<a id="wei002-3"></a>
#### 应期（WEI002 司马懿；JIN009 同文共享）

- **标识与依据**：
  - 运行时 ID：魏 `hanjin__skill_wei002_3`，源码 [skill_wei002_3.lua](../../../../pkg/hanjin_generals/skills/skill_wei002_3.lua)；晋同文 `hanjin__skill_jin009_3`，源码 [skill_jin009_3.lua](../../../../pkg/hanjin_generals/skills/skill_jin009_3.lua)。晋应期在本页只记录来源，不另写正文。
  - 规则见[应期裁定](../../../../rules/generals/wei002-simayi.md)、[JIN009 同文引用](../../../../rules/generals/jin009-simayi.md)与[配将体力贡献通则](../../../../rules/general-principles.md#配将体力贡献与武将状态)。业务文件：[pair_hp.lua](../../../../pkg/hanjin_mode/rules/pair_hp.lua)、`mode.lua`、`rules/ascension.lua`、两张应期骨架。
- **实现与接口**：
  - 数值表示：引擎以**半格**保存体力贡献（1.5 体力记作 `3`，2.0 记作 `4`，2.5 记作 `5`）。国战双将体力上限为 `((主将贡献 + 主将调整) + (副将贡献 + 副将调整) + 应期半格修正) // 2`；半格合计为奇数时 `HalfMaxHpLeft` 标记为 `1`，表示 1 个“半个阴阳鱼”。应期的“☯️+2”是 **2 个半格**（1 点体力上限），不是两枚可消耗的阴阳鱼标记，因此不发放 `@!!yinyangfish` 或 `hanjin_ascension_yinyang` 等标记，只在开局把组合上限补 1 点，并沿用引擎写入的奇偶余数标记。
  - 身份判定：`pair_hp.lua` 的 `qualifies(name)` 表示“配将”是否为多势力或客将——多势力看牌面 `kingdom + subkingdom` 的已知势力数大于 1（`faction_ban.affiliations`），不看本局禁选过滤后的结果；客将看 `guest_factions.guestKingdoms(name)` 非空。应期技能归属按技能名识别（`hanjin__skill_wei002_3`、`hanjin__skill_jin009_3`），君主版／效忠版若沿用同名技能也会被识别；计算按每名角色的配将独立进行，同一配将组合由 `yinyang` 返回一次修正。
  - 开局：`mode.lua` 覆盖 `HegLogic:broadcastGeneral`，先调用上游实现（按组合写入 `maxHp`、`hp`、`HalfMaxHpLeft`），再对每名角色执行 `PairHp.apply_start`。此时主将仍为 `anjiang`，实际配将从 `__heg_general`／`__heg_deputy` 标记读取，不等待明置。`apply_start` 只在模式开局广播路径补齐体力贡献，差值不大于 0 时不再调整；两张应期骨架的 `GameStart` 效果只调用 `register_start` 登记配将，不再调用 `apply_start`，不改变体力或引起额外明置。
  - 升变：`rules/ascension.lua` 的 `pair_max_hp`、实际主副将读取与阴阳鱼奇偶判断改由 `pair_hp.lua` 提供；升变前后组合上限都按含应期的公式计算，所以“同体力主将升变”不会被误判为上限增加；升变收益仍按原公共流程（新组合上限更高时加 1 点上限并回复 1 点体力）。
  - 不重算：普通交换、移除、替换不调用 `apply_start`／`pair_max_hp`，已确定的体力上限不变；开局后属性变化不会撤回或追加应期收益。
  - 客户端与模式隔离：应期不新增客户端交互或私有字段；`maxHp`、`hp`、`HalfMaxHpLeft` 都是引擎已有公开属性／标记。只在 `hanjin_heg_mode` 的 logic 上覆盖 `broadcastGeneral`，不修改上游 `hegemony` 包或其他模式。
- **验证依据**：[wei_pair_hp.lua](../../../../tests/wei_pair_hp.lua)（已加入 [all.lua](../../../../tests/all.lua)）覆盖开局真实接线（复刻 `chooseGenerals` 的 `setPlayerGeneral`／`setDeputyGeneral`／标记／暗置顺序，调用模式真实的 `broadcastGeneral`，分别验证 WEI002、JIN009 与客将配将得到 `3+4+2 = 9` 半格 → 上限 4、余数 1，且不发放可消耗阴阳鱼标记；普通配将保持 `7 → 3`）、身份（本局魏可用时客将按原势力结算，应期仍按资料登记成立；牌面多势力对象与禁选无关）、升变（开局 4 点上限后升变到同为 1.5 体力的 JIN009 保持 4、不多加；再升变到无应期的 2.0 体力主将仍保持 4）。另有 `testPairHpYingqiContribution` 独立断言 `3+4+2=9` 半格；合计 4 项，历史 4/4，最终默认套件 608/608，见[共享验证证据](verification-evidence.md#wei_pair_hp)。
- **未完成与边界**：自动化已通过；客户端进房及联网／重连人工验证尚未完成。“普通交换后升变”的组合比较沿用既有实现（比较升变前后的组合上限公式），不改比较实际 `maxHp`；若规则要求以实际上限为基准，需另轮裁定并补测试。若将来出现独立应期君主版／效忠版但使用不同技能名，需要把技能名登记到 `pair_hp.M.YINGQI_SKILLS`。开局广播路径已有正式房间与专项自动化覆盖；不设 GameStart 重算作为回退，新增开局加载路径时应复核仍经过该模式接线。
