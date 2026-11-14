# 转化与生成用牌：跨势力技能实现与验证

本页是“转化与生成用牌”机制的主记录页：视为牌／view-as 转换、以转化结果使用或打出、以及由技能生成并真实使用一张牌的技能。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。范围边界：技能须以“把某些牌当作另一张牌使用／打出”或“生成一张虚拟牌并真实使用”为核心；仅是阶段时机触发的技能归[阶段与回合流程](phases.md)，仅影响目标与距离的归[用牌目标与距离](active.md)。共享命令输出见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN004 | 张让 | [滔乱](#han004-1) |
| HAN006 | 王允 | [定著](#han006-2) |
| HAN012 | 蔡邕 | [博通](#han012-2) |
| HAN016A | 刘宠 | [劲弩](#han016a-1) |
| WEI007 | 甄姬 | [倾国](#wei007-1) |
| WEI010 | 徐晃 | [断粮](#wei010-1) |
| WU002 | 甘宁 | [奇袭](#wu002-1) |
| WU006 | 大乔 | [国色](#wu006-1) |
| WU007 | 陆逊 | [度势](#wu007-2) |
| JIN001 | 司马炎 | [兴图](#jin001-2) |

## 技能条目

### 汉

<a id="han004-1"></a>
#### 滔乱（HAN004 张让）

- **标识与依据**：运行时 ID `hanjin__skill_han004_1`；源码 [skill_han004_1.lua](../../../../pkg/hanjin_generals/skills/skill_han004_1.lua)。规则见[滔乱专项裁定](../../../../rules/generals/han004-zhangrang.md)与[标准武将表](../../../../rules/standard-generals.md)汉区 HAN004。同一回合多次发动只结算一次的语义按用户 2026-11-13 确认的裁定，本页只记录实现与验证。
- **实现与接口**：
  - 统一使用 ViewAs：正常出牌阶段与合法「使用」窗口共用同一入口，无实体子牌，按正常牌面条件选择目标；正常出牌不绕过普通【杀】次数。
  - `view_as` 是客户端纯函数：只读取自身可见武将／本局公开标记，不调用 `player.room`，也不做服务端查询；克隆牌后把来源编号（1 主将／2 副将）写到 `card.hanjinTaoluanSource`。
  - 响应窗口只放行 `ReqUseCard` 的「使用」窗口（含回合外使用【闪】／【无懈】）；`enabled_at_response` 在 `cardResponsing = true` 的纯打出请求下固定返回 false。
  - 只有承载本技能的武将牌暗置且 `prohibitReveal` 允许时才可发动；已明置后 `hiddenSource` 返回 nil，不再发动。
  - `room:useSkill` 在 `before_use` 之前按技能名自动明置来源武将（`revealBySkillName`），因此 `before_use` 不能要求来源仍暗置；它只消费 `hanjinTaoluanSource`，核对编号对应武将已明置且确实承载本技能，不合法时返回技能名取消本次使用，避免伪造亮将发动。
  - 候选牌名按 `hanjin_cards/data/reuse.lua` 的 `status == "reused"` 过滤，只取已实装、非衍生、非空壳的基本牌／普通锦囊，排除延时锦囊与装备。
  - 记录与结算在首次发动时安装为房间级延迟技能，不依附张让当前技能对象；明置导致技能替换后仍能收牌。以真实 `fk.TargetSpecified` 记录“本回合以此法使用牌指定过的其他角色”到 `-turn` 表标记，只由该牌的 `data.from` 一个 owner 处理，重复指定同一角色由 `addTableMarkIfNeed` 去重；每次真实宣告成功（`fk.AfterCardUseDeclared`）给发动者增加一次 `-turn` 发动计数，单次使用只计一次。
  - `fk.TurnEnd` 使用 refresh 而非询问发动的 trigger：结算必须自动发生，且房间级延迟技能无需再注册触发器名；房间 tag 防止重入，同一角色同一回合无论发动几次都只调用一次 `settle`，清空待结算计数后按玩家逐个处理。候选取本回合累计记录的指定目标并集；每名角色至多结算一次。`-turn` 标记由引擎 `clearHistory(Player.HistoryTurn)` 在回合末结算后清理。
  - 每次结算：选择至多三名候选（逆时针排序），依次询问每名仍有手牌者展示并交一张手牌；按实际得到牌的有效颜色统计红／黑，红多于黑时暗置自己一张可暗置武将（两张均明置时询问）；未得到的牌不额外补抽，无手牌角色跳过。
- **验证依据**：[han004_zhangrang.lua](../../../../tests/han004_zhangrang.lua) 覆盖暗置发动与回合末、回合外使用【闪】、已明置不可再发动、同回合两次发动只结算一次；历史定向 4/4，且默认全量 567/567 含该回归。命令与日期见[共享验证证据](verification-evidence.md#han004_zhangrang)。
- **未完成与边界**：发动资格不变——承载武将仍须暗置才能发动，首次发动后即明置；同回合两次发动只由测试专用效果制造暗置来覆盖结算语义，不代表正式对局中的额外发动途径。明置源、限一次暗置等边界未做完整场景映射；客户端选牌名、选目标、暗置选择未人工界面验证。

<a id="han006-2"></a>
#### 定著（HAN006 王允）

- **标识与依据**：运行时 ID `hanjin__skill_han006_2`；源码 [skill_han006_2.lua](../../../../pkg/hanjin_generals/skills/skill_han006_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN006；用牌目标策略见[效果指定的用牌目标条件](../card-use-targets.md)。同将连计见[伤害、体力与死亡](damage.md#han006-1)。
- **实现与接口**：
  - `Skill.DeputyPlace` 副将技；主将位不会获得该技能，界面与触发均不提供。
  - 记录的是本回合“得到过牌”的角色，不是当前手牌非空；得到后立即用掉／弃掉仍满足条件。共用[han_history.lua](../../../../pkg/hanjin_generals/util/han_history.lua) 查询本回合实际发生的 `GameEvent.MoveCards`，按进入手牌区的牌张累计，装备区与当前手牌数不参与；不安装记录器，因此暗置、晚获得技能或技能失效不会漏掉此前得牌。
  - 出牌阶段结束时先询问发动；发动询问、得到过牌角色与另一名目标角色都在 `on_cost` 中选定并保存，随后才进入 SkillEffect 的明置／技能效果结算，避免先明置再选目标。
  - 由得到过牌的角色视为对指定角色使用【决斗】。目标条件使用汉晋公共显式目标策略，先校验再执行一次真实用牌，不重复结算。
- **验证依据**：[han_standard_pindian.lua](../../../../tests/han_standard_pindian.lua) 覆盖得到过牌后随即失去仍可作候选、仅有手牌但本回合未得牌不作候选、主将位不可用而副将位可用、真实【决斗】使用。历史记录见[共享验证证据](verification-evidence.md#汉区)。
- **未完成与边界**：`han_history` 的 `clear` 仅作测试夹具查询下界，正式游戏不调用；未覆盖明置瞬间完整服务端复核与武将交换前后连续操作。客户端选牌／选目标未人工验收。

<a id="han012-2"></a>
#### 博通（HAN012 蔡邕）

- **标识与依据**：运行时 ID `hanjin__skill_han012_2`；源码 [skill_han012_2.lua](../../../../pkg/hanjin_generals/skills/skill_han012_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN012。同将铸典见[辅助与牌资源](support.md#han012-1)。
- **实现与接口**：
  - `viewas` 转化任意基本牌；`fk.CardUseFinished` 时把仍在处理区的子牌分配给其他角色。
  - 选牌范围为手牌区或装备区（`include_equip = true`）；合法组合仅两种：4 张且四种花色各一张，或 3 张且基本牌／锦囊牌／装备牌各一张。
  - `card_filter` 以“补选后仍可能形成上述任一组合”防止选牌死路；`feasible` 做最终校验。多子牌颜色／点数由引擎 `Card:addSubcards` 按普通多子牌规则确定，不手算。
  - 牌名交互用 `UI.CardNameBox`，候选由公开的 `Player:getViewAsCardNames` 过滤；转化结果只允许「使用」，`enabled_at_response = false`。
  - 使用结算结束时 `fk.CardUseFinished` 先于处理区子牌置入弃牌堆触发；该效果标记 `is_delay_effect = true`，属于本次转化使用的后续效果，不作为新技能发动，也不因中途失去博通而消失。此时取仍留在 `Card.Processing` 的子牌；接受给牌后必须把当前可给子牌全部分配完，不能只给一部分后取消（可在最初拒绝整项给牌）。分配逐名选择，最后统一调用一次 `Room:doYiji`，即一次正常给牌移动，不限定接收人数，不保留标记。
  - 未分配的牌只可能来自非法／空回复等异常路径，正常流程全部给完；异常余牌留在处理区，由使用流程置入弃牌堆。
- **验证依据**：[han012_caiyong.lua](../../../../tests/han012_caiyong.lua) 覆盖博通四花色（4 张四花色当【杀】使用，结算后 4 张子牌全部交给 p2，p1 不残留）与博通三类别（基本／锦囊／装备各一张成功使用，拒绝分配时三张正常进弃牌堆）。历史记录见[共享验证证据](verification-evidence.md#han012_caiyong)。
- **未完成与边界**：分配采用逐名选择、最后统一移动；若后续要求单次界面完成多目标分配，可改用分配专用请求，当前语义与一次给牌移动一致。基本牌名表目前列汉晋已登记的基本牌（含属性【杀】），卡表新增基本牌时应同步扩充。

<a id="han016a-1"></a>
#### 劲弩（HAN016A 刘宠）

- **标识与依据**：运行时 ID `hanjin__skill_han016_1`；源码 [skill_han016_1.lua](../../../../pkg/hanjin_generals/skills/skill_han016_1.lua)。规则见[刘宠规范](../../../../rules/generals/han016a-liuchong.md)与[标准武将表](../../../../rules/standard-generals.md)。牌面编号保留 `A`，运行时仍为 `hanjin__han016`；同将威屯见[阶段与回合流程](phases.md#han016a-2)。
- **实现与接口**：
  - 出牌阶段结束时触发执行一次；零用牌不满足任何分支。
  - 直接查询本阶段真实发生的 `GameEvent.UseCard` 事件，按事件 id 排序，因此技能在非空闲时点使用的牌也进入完整牌序；不依赖引擎聚合用牌次数。纯“打出”的 `GameEvent.RespondCard` 不是“使用”，不进入本条件。
  - 两个分支：至少使用过一张牌且全部为【杀】；或至少使用过两张牌且最后两张均不为【杀】。
  - 满足时在 `on_cost` 选定目标，再使用显式目标策略的 `bypass_distance` 虚拟【杀】：保留通常目标规则但不计算距离，真实使用一次，避免重复结算；实际使用也带 `bypass_times`，修复本阶段已出过【杀】时目标组合校验误挡技能视为使用的【杀】。
- **验证依据**：[han016_liuchong.lua](../../../../tests/han016_liuchong.lua) 覆盖劲弩零用牌不触发、全部为【杀】触发一次无距离【杀】、最后两张均非【杀】触发、不逐项拆分排列。历史记录见[共享验证证据](verification-evidence.md#han016_liuchong)。
- **未完成与边界**：未执行真实客户端出牌与目标选择交互；未覆盖阶段内响应／非空闲窗口的复杂牌序边界、技能造成目标死亡后的目标复核、禁止使用／禁止指定的具体来源；未验证武将交换与跨回合清理。资源编号迁移不在本轮范围。

### 魏

<a id="wei007-1"></a>
#### 倾国（WEI007 甄姬）

- **标识与依据**：运行时 ID `hanjin__skill_wei007_1`；源码 [skill_wei007_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei007_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI007。同将洛神见[判定与花色](retrial.md#wei007-2)。
- **实现与接口**：黑色手牌当【闪】使用或打出；`viewas` 仅手牌、花色黑色，未开放装备区；使用与打出共用入口。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖黑色手牌可转化、红色手牌与装备区牌不可用、使用／响应均可用；历史 14/14。
- **未完成与边界**：客户端转化提示未人工验收。

<a id="wei010-1"></a>
#### 断粮（WEI010 徐晃）

- **标识与依据**：运行时 ID `hanjin__skill_wei010_1`；源码 [skill_wei010_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei010_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI010。同将长驱见[用牌目标与距离](active.md#wei010-2)。
- **实现与接口**：黑色非锦囊牌当【兵粮寸断】；转换模板按黑色及类别位 `basic,equip` 排除锦囊，底牌区域按引擎视为技选牌权限处理。其他角色跳摸牌阶段后令一名角色摸一张牌；本轮专项主要触达跳过摸牌阶段后的摸牌分支。
- **验证依据**：[wei_phases.lua](../../../../tests/wei_phases.lua) 覆盖断粮在他人跳过摸牌阶段后令一名角色摸牌；历史 14/14。
- **未完成与边界**：装备区素材的真实客户端选取尚未人工验收，不将“仅手牌”增写为规则限制。

### 吴

<a id="wu002-1"></a>
#### 奇袭（WU002 甘宁）

- **标识与依据**：运行时 ID `hanjin__skill_wu002_1`；源码 [skill_wu002_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu002_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU002。
- **实现与接口**：独立转换为汉晋【过河拆桥】，沿用公共用牌流程；不使用上游同名旧实现。
- **验证依据**：[wu_support.lua](../../../../tests/wu_support.lua) 覆盖奇袭转换；历史 15/15。
- **未完成与边界**：客户端转化与目标选择未人工验收。

<a id="wu006-1"></a>
#### 国色（WU006 大乔）

- **标识与依据**：运行时 ID `hanjin__skill_wu006_1`；源码 [skill_wu006_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu006_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU006。同将流离见[用牌目标与距离](active.md#wu006-2)；弃置分支的费用与限次见[辅助与牌资源 WU006](support.md#wu006-1)。
- **实现与接口**：使用分支按【乐不思蜀】原目标条件，不能被弃牌限制误挡；两分支的限次复核、弃置费用与批量移动见[辅助与牌资源 WU006](support.md#wu006-1)。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖国色两分支及不可重用；历史 12/12。
- **未完成与边界**：客户端两分支选择未人工验收。

<a id="wu007-2"></a>
#### 度势（WU007 陆逊）

- **标识与依据**：运行时 ID `hanjin__skill_wu007_2`；源码 [skill_wu007_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu007_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU007。同将谦逊见[用牌目标与距离](active.md#wu007-1)。
- **实现与接口**：按本回合未进弃牌堆花色筛转化牌，完成【以逸待劳】后检查四花色，按实际队列目标数选择红牌真实使用【火烧连营】。
- **验证依据**：[wu_phases.lua](../../../../tests/wu_phases.lua) 覆盖度势 ClientPlayer 与真实后续用牌；历史 12/12。
- **未完成与边界**：客户端筛选与后续用牌交互未人工验收。

### 晋

<a id="jin001-2"></a>
#### 兴图（JIN001 司马炎）

- **标识与依据**：运行时 ID `hanjin__skill_jin001_2`；源码 [skill_jin001_2.lua](../../../../pkg/hanjin_generals/skills/skill_jin001_2.lua)。规则见[司马炎规范](../../../../rules/generals/jin001-simayan.md)。辅助主动技 `#hanjin__skill_jin001_2_active`；同将垂统见[辅助与牌资源](support.md#jin001-1)。
- **实现与接口**：
  - 本回合应变牌使用事实：不要求当前拥有兴图的全局 `fk.PreTurnStart` 效果在每个回合开始时把房间标记 `hanjin_jin001_2_adaptation_used` 置为 false，下一回合不继承上一回合事实；全局 `fk.AfterCardUseDeclared` 以 `A.isAdaptationCard(data.card, data)` 判断使用级应变牌，只检查本次实际使用的牌／使用数据，不把实体材料牌的应变条目或 `Adaptation.Triggered` 成功事件当作使用事实。任意角色使用均记录，条件是否满足、是否成功触发不影响事实。记录效果在技能尚未获得、暗置或后来获得时仍存在。纯“打出”走 `RespondCard`，不计入。
  - `fk.TurnEnd` 对每名角色（包括自己）的回合结束检查房间标记；技能有效且本回合序号匹配时只发起一次 `askToChoice`，直接给出“将一张装备牌当【桃】对一名角色使用”“摸一张牌”和取消。分支选择在 `on_cost` 完成并写入 `event:setCostData(self, { choice = ... })` 传给 `on_use`；取消返回 false，不进入 SkillEffect，因此不摸牌、不用牌、不消耗，也不明置来源或计为发动。第一项不合法时只提供摸牌与取消。
  - 第一项：辅助主动技只允许选择自己手牌区或装备区中的装备牌（`card_num = 1`、`include_equip = true`、`card_filter` 检查归属与 `Card.TypeEquip`），目标按“一名角色”提供（含自己与其他角色）。服务端再次复核材料归属／类型、目标存活及 `player:isProhibited`，然后调用公共 `C.useVirtualCard`，以 `C.explicit({})` 替换普通【桃】的牌面目标条件，并把 `skillName` 记为兴图；实际进入一次完整用牌流程，由【桃】自身效果回复体力，不直接 `recover`。
  - 第二项：直接 `drawCards(1, skill.name)`，不要求拥有装备牌。任一项都可取消；选择第一项后在选牌／选目标处取消，不摸牌、不使用、不移动。
- **验证依据**：[jin001_simayan.lua](../../../../tests/jin001_simayan.lua) 覆盖无应变用牌／普通牌／纯打出不触发；其他角色在本回合使用应变牌、条件未成功触发也计数；用牌发生在获得技能之前仍计入；下一回合清空；任意角色回合结束可发动；摸牌项与拒绝；第一项用手牌或装备区装备作材料、对受伤或其他满体力角色完整使用一次【桃】、材料离区且 `skillName` 为兴图；无合法装备时只提供摸牌项；主将、副将、暗置来源；真实 `ClientPlayer` 装备牌／非装备牌与目标可选性。历史 17/17，见[共享验证证据](verification-evidence.md#jin001_simayan)。
- **未完成与边界**：用户曾报告“应变牌后的下一回合，敌方普通杀→八卦阵视为闪，兴图误触发”，自动化未复现；真实连续回合回归及虚拟闪无应变条目检查通过，2026-11-13 用户复测确认无异常、反馈关闭，不据此追认具体根因，也未保留无复现依据的回合序号补丁。全局记录以使用牌事件为准，未覆盖“无任何目标但被使用”的边缘牌型。规范化描述待办见[司马炎入口](jin001-simayan.md#jin001-todo)。
