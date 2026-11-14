# 伤害、体力与死亡：跨势力技能实现与验证

本页是“伤害、体力与死亡”机制的主记录页：受伤触发、造成伤害、伤害修正、伤害防止、失去体力及死亡结算（伤害防止如天香亦在本页）。不替代规则条文，规则冲突时以 `rules/` 与 `rulebook/` 为准。范围边界只收以伤害／体力／死亡为核心效果的技能；改判、用牌目标等分别见对应机制页。同一技能的主记录在本页维护完整正文；确有两侧均复杂的可另设分记录，轻量关联只以锚点交叉引用。共享命令输出与日期见[共享验证证据](verification-evidence.md)。

## 技能索引

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN002 | 刘辩 | [毒逝](#han002-2) |
| HAN005 | 何进 | [构难](#han005-2) |
| HAN006 | 王允 | [连计](#han006-1) |
| HAN007 | 王荣 | [追德](#han007-2) |
| HAN011 | 唐姬 | [哀舞](#han011-1)、[诀别](#han011-2) |
| WEI001 | 曹操 | [奸雄](#wei001-1) |
| WEI002 | 司马懿 | [狼顾](#wei002-1) |
| WEI003 | 夏侯惇 | [刚烈](#wei003-1) |
| WEI005 | 许褚 | [裸衣](#wei005-1) |
| WEI006 | 郭嘉 | [遗计](#wei006-2) |
| WEI012 | 典韦 | [强袭](#wei012-1) |
| WEI013 | 荀彧 | [节命](#wei013-2) |
| WEI014 | 曹丕 | [行殇](#wei014-1) |
| WEI016 | 乐进 | [骁果](#wei016-1) |
| WU004 | 黄盖 | [苦肉](#wu004-1)、[诈降](#wu004-2) |
| WU011 | 小乔 | [天香](#wu011-1) |
| WU013 | 周泰 | [不屈](#wu013-1) |

## 技能条目

### 汉

<a id="han002-2"></a>
#### 毒逝（HAN002 刘辩）

- **标识与依据**：运行时 ID `hanjin__skill_han002_2`；源码 [skill_han002_2.lua](../../../../pkg/hanjin_generals/skills/skill_han002_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN002；卡面原文以 `docs/石激桑武将列表.json` 为准。
- **实现与接口**：随汉区 25 技能骨架一并实装，骨架 `hanjinImplemented = true`，由 [init.lua](../../../../pkg/hanjin_generals/init.lua) 既有登记分支加载；原资料未记录该技能独立的回调执行端与请求细节，本页不补写推测。
- **验证依据**：[han_standard.lua](../../../../tests/han_standard.lua) 共享汉区套件，已纳入默认国战套件；结果见[共享验证证据](verification-evidence.md#汉区)。无独立逐将专项文件与命令输出。
- **未完成与边界**：没有逐项客户端交互与人工验收；未完成边界沿用[汉包](han-standard.md#han-standard-boundary)。

<a id="han005-2"></a>
#### 构难（HAN005 何进）

- **标识与依据**：运行时 ID `hanjin__skill_han005_2`；源码 [skill_han005_2.lua](../../../../pkg/hanjin_generals/skills/skill_han005_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN005；出牌阶段主动技谋诛见[用牌目标与距离](active.md#han005-1)。
- **实现与接口**：
  - `fk.Death` 触发，按公共死亡数据取 `data.killer`；无来源不建立印记，来源已死也照常记录、后续不再复结算。暗将死亡先经公共 `GameOverJudge` 翻正再触发。
  - 印记 `hanjin_skill_han005_2_source-noclear` 不带技能名双下划线前缀，避免 Exchange 按来源技能迁移；`-noclear` 使其不随死亡清标记消失，移将、失技、暗置后已建立印记持续。
  - 伤害监听为房间级延迟技能（`DamageInflicted` + `global`），获得构难时安装，死亡建立印记时再次确保存在；不依赖死者当前 `hasSkill`，何进死后仍生效。
  - 只认正式普通杀牌名 `hanjin__slash`，排除火／雷／冰杀，不以伤害属性代替牌名判断；印记角色作为来源（造成）或受伤者（受到）两个方向各 +1，每次伤害事件只加一次。
- **验证依据**：[han005_hejin.lua](../../../../tests/han005_hejin.lua) 覆盖构难普通杀双向（暗将何进死亡后印记生效，来源造成／受到普通杀伤害各 +1）与属性杀排除（火杀仍为 1）；历史定向结果 3/3，见[共享验证证据](verification-evidence.md#han005_hejin)。
- **未完成与边界**：来源为空或来源已死时只按公共死亡数据记录／跳过；若后续引入复活并需重新结算，应由公共流程决定。普通杀若新增别名需同步扩充而非改回按属性判断。客户端选目标／弃牌界面未人工验收。

<a id="han006-1"></a>
#### 连计（HAN006 王允）

- **标识与依据**：运行时 ID `hanjin__skill_han006_1`；源码 [skill_han006_1.lua](../../../../pkg/hanjin_generals/skills/skill_han006_1.lua)。共用“本回合得到牌”查询 [han_history.lua](../../../../pkg/hanjin_generals/util/han_history.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN006；用牌目标策略见[效果指定的用牌目标条件](../card-use-targets.md)。
- **实现与接口**：
  - 出牌阶段主动技；“每名角色限一次”的已选目标 ID 表记在**发动者**身上，采用 `hanjin__skill_han006_1-given_targets-phase` 技能前缀，随王允武将牌由 Exchange 迁移，不会让两名持有者互相阻止。目标身上只保留已建立的下一次伤害 +1 延迟效果。
  - 只允许交出自己当前手牌；服务端在 `on_use` 重新核对牌仍属于发动者手牌，不依赖客户端选择。
  - 交给后给目标本回合 `next_damage` 计数；伤害在 `DamageInflicted` 按计数增加，在实际伤害后的 `fk.Damage` 才清零，被防止的伤害不消费。多个“下一次”同时存在时同一次实际伤害一并增加。
  - 加成监听器是模块缓存的房间级单一对象，第一次发动时安装并保留；王允之后失技、暗置或交换不影响已挂在目标身上的延迟效果，也不进入 Exchange 的武将标记迁移。
  - 连计/奋钺的主动技使用次数由引擎 `skillUsedHistory` 与正式模式已有的 `#hanjin_exchange_history` 逐牌账本迁移；本组没有另建来源侧限次标记。
- **验证依据**：[han_standard_pindian.lua](../../../../tests/han_standard_pindian.lua)（历史“待基础组执行”记录已被后续默认套件覆盖，见[共享验证证据](verification-evidence.md#汉区)）覆盖交出手牌、下一次伤害 +1 且只消费一次、同一目标同阶段拒绝而另一目标仍可发动。
- **未完成与边界**：`han_history` 的 `clear` 仅作测试夹具查询下界，正式游戏不调用；未覆盖明置瞬间完整服务端复核、武将交换前后连续操作、死亡中断。客户端选牌／选目标未人工验收。

<a id="han007-2"></a>
#### 追德（HAN007 王荣）

- **标识与依据**：运行时 ID `hanjin__skill_han007_2`；源码 [skill_han007_2.lua](../../../../pkg/hanjin_generals/skills/skill_han007_2.lua)。共用工具 [minsi.lua](../../../../pkg/hanjin_generals/util/minsi.lua)。规则见[王荣规范](../../../../rules/generals/han007-wangrong.md)；同将敏思见[辅助与牌资源](support.md#han007-1)。
- **实现与接口**：
  - `fk.Death` 触发，位于 `GameOverJudge` 之后、`BuryVictim` 清理死亡角色牌之前（`ltk/server/events/death.lua`）；国战公共流程在 `GameOverJudge` 翻开暗置武将，因此暗将来源追德仍能触发，给牌不跳过公共牌移动。
  - 选牌与接收者由辅助主动技只完成选择，`on_use` 再执行展示、给牌、摸牌和额外敏思。红桃牌展示并交给、等量摸牌。
  - 红桃判定使用 `Room:filterCard(id, player)` 的有效花色，已核对 `Fk:getCardById` 过滤缓存行为；不再直接依赖实体牌原始 `suit`，点数和仍取实体牌原始点数。
- **验证依据**：[han007_wangrong.lua](../../../../tests/han007_wangrong.lua) 覆盖追德基础（红桃展示交付、等量摸牌、无 13 组合不额外发动、剩余牌随死亡清理）与追德额外敏思（暗置主将死亡后仍触发，受赠者已有普通敏思阶段记录时额外敏思仍发动且主技能次数保持 1）。历史定向记录见[共享验证证据](verification-evidence.md#han007_wangrong)。
- **未完成与边界**：手牌上限的引擎显示值不逐个扣除“不计入”的牌，实际弃牌阶段按 `MaxCardsSkill:excludeFrom` 计算；界面数字与有效上限差异属引擎显示范围，未修改公共机制。客户端死亡与给牌交互未人工验收。

<a id="han011-1"></a>
#### 哀舞（HAN011 唐姬）

- **标识与依据**：运行时 ID `hanjin__skill_han011_1`；源码 [skill_han011_1.lua](../../../../pkg/hanjin_generals/skills/skill_han011_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN011。同将诀别见[本页](#han011-2)。
- **实现与接口**：
  - `fk.Damaged` 触发；效果设 `global = true`（对其他角色的伤害事件生效），以伤害事件为单位每次只触发一次，不按 `data.damage` 点数重复；`can_trigger` 以 `usedSkillTimes(..., Player.HistoryTurn) == 0` 实现每回合限一次。
  - 自己的弃牌是发动消耗：`on_cost` 以 `askToDiscard(skip=true)` 只选牌，`on_use` 在技能明置后按固定细节支付并继续；取消选牌即不发动；可弃牌数排除被禁止弃置的牌。
  - 受伤角色随后可弃置至少一张（可选，取消不影响已支付消耗）；两处弃牌数合计 `>= 3` 时双方各回复 1 点体力。弃牌均含装备区，不额外套用“禁止弃置”以外限制。
  - 受伤角色在结算中死亡／离场则跳过其后续弃牌；回复前再次检查双方仍在场。
- **验证依据**：[han011_tangji.lua](../../../../tests/han011_tangji.lua) 覆盖合计 3（自己弃 2、伤者弃 1，双方各回复 1，同回合第二次受伤因限次不触发）与合计不足 3（自己弃 1、伤者弃 1，不回复）。公共伤害、弃牌与请求复用现有覆盖，测试通过真实 `fk.Damaged` 与真实请求回复触发。
- **未完成与边界**：多份哀舞来源的触发先后完全依赖公共触发顺序，本实现不自建排序。客户端选牌与确认未人工验收。

<a id="han011-2"></a>
#### 诀别（HAN011 唐姬）

- **标识与依据**：运行时 ID `hanjin__skill_han011_2`；源码 [skill_han011_2.lua](../../../../pkg/hanjin_generals/skills/skill_han011_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)汉区 HAN011。
- **实现与接口**：
  - `fk.Death` 触发且效果 `global = true`（其他角色死亡也能触发）：位于 `GameOverJudge` 之后、`BuryVictim` 清牌之前；暗将死亡按翻转后的实际势力判断。
  - 触发者 `player` 为唐姬；发动、选项和受益者均由死亡角色 `target` 选择：「获得其所有牌」或「摸三张牌」；受益者为另一名与唐姬势力相同的存活角色，排除死亡角色本人。唐姬自己死亡时同样处理，比较对象包含自身。
  - 「所有牌」取死者手牌区和装备区（`getCardIds("he")`），在 `on_use` 中于清牌前用 `obtainCard` 移动；未获得的判定区牌等随正常死亡流程清理。
  - 同势力判断使用 `compareKingdomWith`；其他角色 `unknown` 一律不是同势力；只有技能持有者自己暗置时才为发动作必要的自身势力预测。不硬编码“只限其他角色”，多份来源交由公共触发次序处理。
  - 死亡角色可能已 `dead`，发动／选项／选目标请求仍按其客户端身份发出，不用存活角色代替。
- **验证依据**：[han011_tangji.lua](../../../../tests/han011_tangji.lua) 覆盖诀别他人死亡（同势力死者选“获得其所有牌”，受益者获得手牌与装备，清牌前完成）与诀别自己死亡（唐姬自己死亡仍触发，同势力受益者摸三张）。
- **未完成与边界**：死亡角色没有手牌／装备时仍可选择“获得其所有牌”，实际不发生移动；规则未禁止零张选择，未另设“至少一张”。唐姬暗置且尚未完成势力判定时，势力回退使用 `__heg_kingdom` 标记；若公共明置／转野流程改变判定，应以公共接口为准。多份诀别来源依赖公共触发顺序。

### 魏

<a id="wei001-1"></a>
#### 奸雄（WEI001 曹操）

- **标识与依据**：运行时 ID `hanjin__skill_wei001_1`；源码 [skill_wei001_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei001_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI001。
- **实现与接口**：`fk.Damaged` 触发；先摸一张，再可足额弃一张牌（手牌／装备，不含判定区）取得仍在处理区的伤害牌。选牌／选目标使用 `askToDiscard`、`askToChooseCard` 等正式请求接口。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 8 项定向历史 8/8 通过，覆盖奸雄摸牌＋弃牌取得伤害牌；见[共享验证证据](verification-evidence.md#wei_damage)。
- **未完成与边界**：完整死亡、奖惩与客户端界面仍是未验证边界；QML 选牌／选目标与明暗置来源切换未人工验收。

<a id="wei002-1"></a>
#### 狼顾（WEI002 司马懿）

- **标识与依据**：运行时 ID `hanjin__skill_wei002_1`；源码 [skill_wei002_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei002_1.lua)。规则见[司马懿规范](../../../../rules/generals/wei002-simayi.md)。同将[鹰视](retrial.md#wei002-2)、[应期](pair-hp.md#wei002-3)。
- **实现与接口**：`fk.Damaged` 触发；获得来源一张手牌／装备牌；来源为自己时只取装备区，与既有反馈类公共处理一致。技能以 `player:hasSkill` 判定当前是否持有，不依赖服务端私有字段。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖狼顾取得来源牌；历史 8/8。
- **未完成与边界**：完整死亡、客户端界面与主副将来源切换未人工验收。

<a id="wei003-1"></a>
#### 刚烈（WEI003 夏侯惇）

- **标识与依据**：运行时 ID `hanjin__skill_wei003_1`；源码 [skill_wei003_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei003_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI003；同将持重见[辅助与牌资源](support.md#wei003-2)。
- **实现与接口**：`fk.Damaged` 触发；判定红色对来源造成 1 点普通伤害，黑色弃置来源一张牌；来源离场后不再执行对应分支。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖红／黑两分支；历史 8/8。
- **未完成与边界**：客户端判定与选牌交互未人工验收。

<a id="wei005-1"></a>
#### 裸衣（WEI005 许褚）

- **标识与依据**：运行时 ID `hanjin__skill_wei005_1`；源码 [skill_wei005_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei005_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI005。
- **实现与接口**：`fk.EventPhaseEnd`（摸牌阶段）弃一张牌；`fk.DamageCaused` 延时效果按回合标记给【杀】／【决斗】伤害 +1。效果独立于技能存在：延时效果通过回合标记与 `fk.DamageCaused` 结算，不检查 `hasSkill`；标记 `hanjin_wei005_luoyi-turn` 不以技能名前缀开头，避免武将交换把它当成来源技能标记迁走，回合结束由 `-turn` 清理。裸衣的回合标记只服务端判定，不使用 `@@` 展示标记。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖失去技能后本回合加伤仍生效；历史 8/8。
- **未完成与边界**：客户端提示与人工交互未验收。

<a id="wei006-2"></a>
#### 遗计（WEI006 郭嘉）

- **标识与依据**：运行时 ID `hanjin__skill_wei006_2`；源码 [skill_wei006_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei006_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI006；同将轻辎见[辅助与牌资源](support.md#wei006-1)。
- **实现与接口**：`fk.Damaged` 每次伤害事件一次；看牌堆顶两张，先选 1~2 张给一名角色，剩余再给一名角色，不做上游式任意循环分配。使用 `getNCards(2)` 读取牌堆顶两张（只读取、不移入处理区），选择对话框以 `expand_pile` 展示，再按两次分配从牌堆移动到目标手牌；未新增仅客户端可见的私有展示层。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖一次 2 点伤害只发动一次且分两次给牌；历史 8/8。
- **未完成与边界**：客户端分配界面未人工验收；未展开与死亡时失去装备等触发之间的完整时序回归。

<a id="wei012-1"></a>
#### 强袭（WEI012 典韦）

- **标识与依据**：运行时 ID `hanjin__skill_wei012_1`；源码 [skill_wei012_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei012_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI012。
- **实现与接口**：出牌阶段每目标一次（`-targets-phase` 表标记）；目标先按当前攻击范围确定，再弃武器或失去 1 点体力，然后造成 1 点伤害。`can_use` 要求体力至少 1，或拥有可弃武器牌；失去体力的消耗不得超过当前体力，不把有可弃武器的强袭一并限制为体力至少 1。
- **验证依据**：[wei_active.lua](../../../../tests/wei_active.lua) 覆盖无武器时失去体力并对攻击范围内目标造成 1 点伤害、写入每目标标记；历史 6/6。
- **未完成与边界**：客户端选目标与弃武器交互未人工验收。

<a id="wei013-2"></a>
#### 节命（WEI013 荀彧）

- **标识与依据**：运行时 ID `hanjin__skill_wei013_2`；源码 [skill_wei013_2.lua](../../../../pkg/hanjin_generals/skills/skill_wei013_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI013；同将驱虎见[拼点](pindian.md#wei013-1)。
- **实现与接口**：`fk.Damaged` + `trigger_times = data.damage`；每个伤害点分别询问目标并摸至 `min(体力上限,5)` 张手牌。保留引擎逐次调度：未拆分伤害事件，也未在 `on_use` 内循环。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖 2 点伤害逐点发动两次并按点节命；历史 8/8。
- **未完成与边界**：客户端逐点选择未人工验收。

<a id="wei014-1"></a>
#### 行殇（WEI014 曹丕）

- **标识与依据**：运行时 ID `hanjin__skill_wei014_1`；源码 [skill_wei014_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei014_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)魏区 WEI014 与[曹丕结算约定](../../../../rules/generals/wei014-caopi.md)。同将放逐见[辅助与牌资源](support.md#wei014-2)。
- **实现与接口**：`fk.Death`（弃置其牌之前）触发；获得死亡角色的手牌与装备牌（“某人的牌”不含判定区，取牌范围由 `getCardIds()` 改为 `getCardIds("he")`）；其没有牌时回复 1 点体力。只有判定区牌的死亡角色视为没有牌。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖取得死亡角色手牌与装备牌及无牌回复；判定区用例 `testXingshangTakesCardsOrRecovers` 断言只有判定区牌时改为回复、判定区牌不移动。历史 8/8。
- **未完成与边界**：用例直接触发 `fk.Death`（真实死亡事件类与真实请求／回复），未经过完整 `killPlayer` 死亡结算链；完整死亡、奖惩与客户端界面仍待验收。未新增判定区延迟锦囊交互测试。

<a id="wei016-1"></a>
#### 骁果（WEI016 乐进）

- **标识与依据**：运行时 ID `hanjin__skill_wei016_1`；源码 [skill_wei016_1.lua](../../../../pkg/hanjin_generals/skills/skill_wei016_1.lua)。规则见[乐进规范](../../../../rules/generals/wei016-yuejin.md)。
- **实现与接口**：`fk.EventPhaseStart`（其他角色准备阶段）触发；弃置至少一张基本牌为消耗，目标弃置等量装备（不足全弃），实际基本数 > 装备数则造成 1 点伤害，否则摸一张。消耗规范：须至少一张，`skip = true` 后在 `on_use` 统一移动；无装备不弃；伤害比较用实际弃置张数。
- **验证依据**：[wei_damage.lua](../../../../tests/wei_damage.lua) 覆盖基本数多于装备数造成伤害、相等时摸牌；历史 8/8。
- **未完成与边界**：客户端消耗与目标装备弃置交互未人工验收。

### 吴

<a id="wu004-1"></a>
#### 苦肉（WU004 黄盖）

- **标识与依据**：运行时 ID `hanjin__skill_wu004_1`；源码 [skill_wu004_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu004_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU004；同将诈降见[本页](#wu004-2)。
- **实现与接口**：出牌阶段主动技，实际失去体力（不是受到伤害），供诈降的 `HpLost` 监听使用。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 22 项定向历史 22/22 通过，包含真实伤害／失去体力；见[共享验证证据](verification-evidence.md#wu_damage)。
- **未完成与边界**：客户端确认与联网／重连未人工验收。

<a id="wu004-2"></a>
#### 诈降（WU004 黄盖）

- **标识与依据**：运行时 ID `hanjin__skill_wu004_2`；源码 [skill_wu004_2.lua](../../../../pkg/hanjin_generals/skills/skill_wu004_2.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU004。
- **实现与接口**：监听 `HpLost` 摸牌并累计本回合出杀次数；次数修正使用锁定杀接口查询的 `HistoryPhase`；红杀距离与累计次数在失去技能后继续生效（中性回合标记＋模式级距离技能）。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖两次诈降累计及真实用杀次数、失技后持续；历史 22/22。
- **未完成与边界**：客户端红杀距离提示未人工验收。

<a id="wu011-1"></a>
#### 天香（WU011 小乔）

- **标识与依据**：运行时 ID `hanjin__skill_wu011_1`；源码 [skill_wu011_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu011_1.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)吴区 WU011；同将红颜见[判定与花色](retrial.md#wu011-2)。
- **实现与接口**：只展示可弃置红桃候选，含红颜视为红桃的牌，并在支付前复核；先防止原伤害，再执行新伤害／失去体力两分支，不写成旧版转移伤害。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖天香／红颜组合；历史 22/22。
- **未完成与边界**：天香无来源、多次濒死完整求桃链等复杂边界未独立验收；客户端点击、联网／重连未人工验证。

<a id="wu013-1"></a>
#### 不屈（WU013 周泰）

- **标识与依据**：运行时 ID `hanjin__skill_wu013_1`；源码 [skill_wu013_1.lua](../../../../pkg/hanjin_generals/skills/skill_wu013_1.lua)。规则见[周泰规范](../../../../rules/generals/wu013-zhoutai.md)。同将奋激见[辅助与牌资源](support.md#wu013-2)。
- **实现与接口**：真实进入濒死时摸 X 张，从手牌／装备置一张“创”；同花色重复由玩家选择保留牌并移去其余，无须移去才回复至一。
- **验证依据**：[wu_damage.lua](../../../../tests/wu_damage.lua) 覆盖真实濒死不屈、装备置创、选择保留；历史 22/22。
- **未完成与边界**：多次濒死完整求桃链未穷举；客户端“创”显示与人工交互未验收。
