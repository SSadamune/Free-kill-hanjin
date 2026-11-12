# 可复用的故障案例

本页保留触发条件、已确认根因、修复与回归入口，供定位同类问题；不是游戏规则，也不记录完整排障流水账。通用处理方法见[测试规范](testing.md)，最新验证结果见[开发状态](status.md)。

## 客户端角色没有服务端房间字段（已修复）

- 现象：刘协搭配徐晃、明置副将后进入出牌阶段，密诏按钮检查报 `player.room` 为 nil。
- 根因：可用性、交牌下限及提示会在 `ClientPlayer` 上计算，不能假定它有 `ServerPlayer.room`。
- 修复：密诏使用兼容客户端的当前房间接口读取可见状态，保留服务端执行前复核。
- 回归：`tests/han001_liuxie.lua` 中 `testMZ31RealClientPlayerWithoutRoomComputesKnownFaction`、`testMZ32ClientWithoutRoomPredictsHiddenOwnFaction`。

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
