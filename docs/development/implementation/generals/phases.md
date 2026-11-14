# 阶段与回合流程：跨势力技能实现与验证

本页是“阶段与回合流程”机制的主记录页：阶段替换、阶段跳过与重排，以及以阶段流程本身为核心的技能。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。范围边界：只收“阶段替换、跳过／重排”为核心效果的技能，**不收一切阶段时机触发**——在准备／结束等时机触发的普通技能按其主要效果归入伤害、辅助、拼点等机制页。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN016A | 刘宠 | [威屯](#han016a-2) |
| WEI008 | 夏侯渊 | [神速](#wei008-1) |
| WEI009 | 张郃 | [巧变](#wei009-1) |

## 技能条目

### 汉

<a id="han016a-2"></a>
#### 威屯（HAN016A 刘宠）

- **标识与依据**：运行时 ID `hanjin__skill_han016_2`；源码 [skill_han016_2.lua](../../../../pkg/hanjin_generals/skills/skill_han016_2.lua)。规则见[刘宠规范](../../../../rules/generals/han016a-liuchong.md)与[标准武将表](../../../../rules/standard-generals.md)。牌面编号保留 `A`，运行时仍为 `hanjin__han016`；同将劲弩见[转化与生成用牌](conversion.md#han016a-1)。
- **实现与接口**：
  - 限定技。`EventPhaseChanging` 的弃牌阶段开始前检查手牌数是否全场最多，并列最多也满足。
  - `on_cost` 先筛选候选并让发动者选定一组共同目标；`on_use` 设置 `data.skipped = true` 跳过弃牌阶段，然后依次对同一组目标使用【桃园结义】和【五谷丰登】。
  - 两张牌使用汉晋显式目标策略：允许自己、允许满血等通常牌面会排除的目标；独立的禁止使用／禁止指定仍由公共目标策略和真实用牌入口复核。目标组不因第一张牌结算后重新选择。
- **验证依据**：[han016_liuchong.lua](../../../../tests/han016_liuchong.lua) 覆盖并列手牌最多、跳过弃牌阶段、同一组目标依次使用【桃园结义】和【五谷丰登】并检查目标包含自己。历史记录见[共享验证证据](verification-evidence.md#han016_liuchong)。
- **未完成与边界**：未执行真实客户端出牌、阶段跳过及两张群体牌的目标选择交互；未覆盖技能造成目标死亡后第二张牌的目标复核、禁止使用／禁止指定具体来源；未验证武将交换、跨回合清理。资源编号迁移不在本轮范围。旧记录保留的计划定向入口为 `python scripts/test.py --file tests/han016_liuchong.lua --timeout 120`（当时标为待基础组执行，未产生该文件单独输出，后由默认套件覆盖）。

### 魏

<a id="wei008-1"></a>
#### 神速（WEI008 夏侯渊）

- **标识与依据**：运行时 ID `hanjin__skill_wei008_1`；源码 [skill_wei008_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei008_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI008。同将设变见[辅助与牌资源](support.md#wei008-2)；锁定引擎 0.5.25 与 hegemony `e8d93acd34a3`。
- **实现与接口**：
  - 分别在判定／出牌／弃牌阶段开始前选择对应项，支付代价并视为使用无距离【杀】。监听 `fk.EventPhaseChanging`，不设准备阶段一次性选择；`data.skipped == false` 才可发动，判定项还要求 `canSkip(Player.Draw)`。
  - 阶段跳过使用 `ServerPlayer:canSkip(phase)`／`ServerPlayer:skip(phase)`（0.5.25 `ltk/server/serverplayer.lua`）。`canSkip` 只检查当前回合尚未跳过的阶段，`skip` 标记当前回合的该阶段；已跳过的阶段不会再次触发 `fk.EventPhaseChanging`。
  - 选项 2 的装备牌从手牌或装备区弃置；选项 3 失去体力（可触发设变）；每项独立视为使用一张【杀】。
  - 视为使用【杀】走项目公共目标策略 `card_use_targets`：`bypassDistance` 取消距离限制，`extra_data.bypass_times = true` 豁免选择时的次数检查，最终使用数据以顶层 `extraUse = true` 标记不计通常出杀次数。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖神速分别在判定／出牌／弃牌阶段开始前发动、跳过对应阶段、支付对应消耗并视为使用【杀】、已跳过阶段不再消耗；历史 14/14。
- **未完成与边界**：客户端阶段触发确认、两步移牌选择及目标选择未人工验收。

<a id="wei009-1"></a>
#### 巧变（WEI009 张郃）

- **标识与依据**：运行时 ID `hanjin__skill_wei009_1`；源码 [skill_wei009_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei009_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI009；共享工具 [wei_phases.lua](../../../../pkg/hanjin_generals/util/wei_phases.lua)（公开势力预测、场上牌可移动性检查、两步式场上移牌）。
- **实现与接口**：
  - 弃一张牌跳过阶段；摸牌阶段效果由技能拥有者选择至多两名其他角色，各随机获得其一张手牌；出牌阶段效果复用公共移牌接口。
  - 移动场上牌先由引擎公共的 `Room:askToChooseToMoveCardInBoard` 在两阶段内筛出确有可移动关系的两名角色，再用 `Room:askToMoveCardInBoard`（0.5.25 `ltk/server/room.lua` 3374 行）在其中一人装备／判定区选牌移动；请求回复为 `{ cardId = <cards 中的牌 id>, pos = cardsPosition[牌下标] }`。
  - 不读取服务端私有字段：同势力候选复用 hegemony 公共的 `HegUtil.compareExpectedKingdomWith`，他人暗置时公开势力为 `unknown`，不进入候选。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖巧变真实移牌与请求级用例；历史 14/14。此前 90 秒超时的根因是测试直接比较 `ServerPlayer` 对象导致 LuaUnit 挂起，非请求 schema 或嵌套事件，见[共享验证证据](verification-evidence.md#设变巧变超时根因)。
- **未完成与边界**：客户端阶段跳过确认与两步移牌选择未人工验收；摸牌阶段获得手牌为服务端随机隐藏选择，未增加客户端可见性测试。
