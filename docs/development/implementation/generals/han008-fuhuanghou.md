# HAN008 伏皇后：惴恐、求援实现与验证

最终集成复核（2026-11-13）：本文件对应实现已纳入默认套件，DSH 工具原生检查确认 564/564 通过，发布包内容经核对。以下“未运行”“待集成”等表述如有保留，指前期阶段交回记录，不代表最终自动化状态；逐项客户端、联网／重连及干净本体安装人工验收仍未完成。统一结果见[汉势力标准包总览](han-standard.md)。

本页记录本轮限定实现与验收依据。求援的优先结算约定见
[rules/generals/han008-fuhuanghou.md](../../../../rules/generals/han008-fuhuanghou.md)；
使用事件与目标时机见[牌的使用相关事件](../../../../rulebook/events/use-card.md)，
额外目标条件见[指定额外目标](../../../../rules/extra-targets.md)。

## 1. 范围

- 惴恐：`pkg/hanjin_generals/skills/skill_han008_1.lua`
- 求援：`pkg/hanjin_generals/skills/skill_han008_2.lua`
- 定向用例：[tests/han008_fuhuanghou.lua](../../../../tests/han008_fuhuanghou.lua)

## 2. 实现要点

### 惴恐

- `EventPhaseStart` 全局监听其他角色的准备阶段；伏皇后已受伤且可与该角色
  拼点时，通过正规 `can_trigger/on_cost/on_use` 发动。`createTriggerSkill` 会
  用 `can_trigger` 覆盖基类 target 门槛，因此不需要 refresh/`room:useSkill`
  代理；正常明置来源并记录技能发动。
- 伏皇后赢：给该角色加本回合 `no_damage` 延迟标记；房间级 `DamageCaused`
  监听器按标记把该角色造成的伤害防止。监听器不依赖伏皇后之后是否仍有技能。
- 没赢（含平局）：该角色可选择视为对伏皇后使用【杀】；使用显式目标策略，
  目标为伏皇后，不叠加普通距离条件，仍复核禁止使用/禁止指定。

### 求援

- `TargetConfirming` 触发，只在伏皇后成为其他角色【杀】的目标时提供一次；
  同一名伏皇后对同一次 use 不会重复求援。
- 候选使用公共 `ExtraTargets` 显式条件 `other_roles = true`：不按普通攻击
  距离阻挡，但仍排除已禁止、已在本次目标列表中的角色。
- 通过 AimData 的目标加入接口增加目标，新增目标仍会生成
  `TargetSpecified`/`TargetConfirmed` 等正常目标事件。
- 新增目标 id 记录在本次 `UseCardData` 上；效果顺序只在
  `BeforeCardUseEffect` 调整为新增目标优先，不在目标阶段排序，不提前事件。
- 任意目标抵消后，复用方天画戟的 use 级 `nullifiedTargets` 登记，使其余目标
  无效；监听器按 use 上已建立的记录执行，不依赖伏皇后当前是否仍有求援。

## 3. 测试状态与未覆盖

**测试待基础组统一执行。** 本轮未启动 FreeKill、未运行测试，不能视为通过。
定向命令：

```text
python scripts/test.py --file tests/han008_fuhuanghou.lua --timeout 120
```

核心用例合并覆盖：惴恐赢后防止目标本回合伤害；平局按没赢允许目标视为使用
无距离【杀】；求援新增目标保留目标事件、效果顺序优先，且被【闪】抵消后
原目标不再受到此【杀】影响。

未覆盖/需基础组确认：

- 未执行真实客户端选目标、拼点及新增目标响应交互；
- 未覆盖多个伏皇后同时求援、目标中途死亡/失技、无合法新增目标等排列；
- 未验证手工强制取消或伪造目标数据；依赖公共目标/用牌复核；
- 未运行默认全量套件，未修改引擎或公共文件。
