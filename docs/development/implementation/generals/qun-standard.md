# 群势力标准包：逐将检索

本页是群势力标准包的逐将入口，不重复技能正文。本包正式登记 15 张武将。马术复用同一运行时 ID，关联翼从在各自统领来源的行中标出。规则依据见[标准武将表](../../../rules/standard-generals.md)及 `docs/rules/generals/qun*.md`；实现与验证分别落在下列机制页。

## 逐将检索

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| QUN001 | 华佗 | [济世](damage.md#qun001-1)、[除疠](support.md#qun001-2) |
| QUN002 | 吕布 | [无双](active.md#qun002-1)、[虓猛](active.md#qun002-2)、[并州狼骑](retinues.md#bingzhou-langqi)（关联翼从） |
| QUN003 | 貂蝉 | [离间](active.md#qun003-1)、[闭月](support.md#qun003-2) |
| QUN004 | 袁绍 | [乱击](conversion.md#qun004-1) |
| QUN005 | 颜良&文丑 | [双雄](conversion.md#qun005-1) |
| QUN007 | 贾诩 | [完杀](damage.md#qun007-1)、[乱武](active.md#qun007-2)、[帷幕](active.md#qun007-3) |
| QUN008 | 庞德 | [马术](active.md#shu006-1)、[猛撼](active.md#qun008-2) |
| QUN010 | 张角 | [雷击](damage.md#qun010-1)、[鬼道](retrial.md#qun010-2)、[黄巾雷使](retinues.md#huangjin-leishi)（关联翼从） |
| QUN012 | 蔡文姬 | [悲歌](retrial.md#qun012-1)、[断肠](damage.md#qun012-2) |
| QUN013 | 马腾 | [马术](active.md#shu006-1)、[雄异](support.md#qun013-2)、[西凉精骑](retinues.md#xiliang-jingqi)（关联翼从） |
| QUN015 | 纪灵 | [双刃](conversion.md#qun015-1) |
| QUN016 | 田丰 | [死谏](support.md#qun016-1)、[随势](damage.md#qun016-2) |
| QUN017 | 潘凤 | [狂斧](conversion.md#qun017-1) |
| QUN018 | 邹氏 | [祸水](active.md#qun018-1)、[倾城](support.md#qun018-2) |
| QUN027 | 韩遂 | [马术](active.md#shu006-1)、[骁逆](conversion.md#qun027-2)、[西凉精骑](retinues.md#xiliang-jingqi)（关联翼从） |

QUN008、QUN013、QUN027 的马术与 SHU006 马超共用 `qiao__skill_shu006_1`，不另建正文；三处逐将链接复用[同一锚点](active.md#shu006-1)。黄巾雷使的翼从专属技能见[翼从专属技能](retinues.md#huangjin-leishi)。

## 测试入口与当前状态

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的群包历史验收](verification-evidence.md#qun-standard)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

群包专项统一从 [qun_standard.lua](../../../../tests/qun_standard.lua) 进入，单技能回归见各条目的证据。

## 保留的参考差异与边界

- **版本基线**：QUN016 死谏、随势按[来源基线](../../../rules/generals/qun016-tianfeng.md)采用标准表／JSON 版本，不采用 `assets/docs/药枫桑大合集337.csv` 中同编号的“变为 0／区域内牌／额外回复”以及“随势无弃手牌”异版。QUN015 双刃没赢后的转换限制按[逐将裁定](../../../rules/generals/qun015-jiling.md)持续至本回合结束，不采用 CSV 的“本回合不能使用【杀】”。
- **客将交换**：开启「客将替换规则」时，QUN001 济世结算方括号段。允许跨势力交换，首次成功即止。见[华佗规范](../../../rules/generals/qun001-huatuo.md)。
- **济世描述**：`Fk:getDescription` 的现有扩展入口按公开的房间设置展开或移除原文中的方括号段。图鉴无房间设置时展示默认开启的版本。`tests/qun_dying.lua` 6/6 通过，含有无角色参数的描述入口和原有结算。
- **目标与限制**：QUN007 乱武按最近距离先算全体其他角色，再检查合法用【杀】且至少包含一名最近角色，允许附带较远合法目标；不能改选较远但能杀的角色。完杀不保留贾诩本人豁免；帷幕只在成为黑色锦囊目标时取消该目标，不改成禁止选取或拦截延时锦囊移入判定区。
- **判定差异**：QUN010 鬼道“替换”包含获得原判定牌，区别于鹰视“代替”；先真实打出再 `changeJudge{exchange=true}`。QUN012 悲歌的判定与分支效果见[判定与花色](retrial.md#qun012-1)。
- **共享马术**：QUN008／QUN013／QUN027 直接引用 `qiao__skill_shu006_1`，不再实现三份；双将同时提供同一技能时按公共技能来源去重，不重复减距离。
- **来源与持续效果**：双刃已建立的转换权限由独立状态骨架承载至回合结束；断肠记录整张将牌技能的失去，明置及交换通过来源过滤维持结果。两者的真实主流程已通过定向验证。
- **黄巾雷使**：`qiao__qun_damage_history` 记录本回合第一个“不因使用手牌而造成伤害”的 `fk.DamageCaused` 时机；不是“每名角色首次”或“本回合首次发动”，晚取得翼从不重开已消耗的机会。

## 模式级接线

以下技能已由 `pkg/qiao_mode/mode.lua` 在 `logic:start` 注册房间规则；文档只记必要接线，不转为正式规则：

- [qun_dying_rule](../../../../pkg/qiao_mode/skills/qun_dying_rule.lua)：完杀用桃禁止与济世濒死序号／客将交换收尾，共享状态见 [util/qun_dying](../../../../pkg/qiao_generals/util/qun_dying.lua)。
- [qun_cards_rule](../../../../pkg/qiao_mode/skills/qun_cards_rule.lua)：乱击响应摸牌、狂斧与骁逆的用牌后结算、乱击花色清理。
- [qun_damage_history](../../../../pkg/qiao_mode/skills/qun_damage_history.lua)：黄巾雷使的首个非手牌伤害机会事实。
- [qun_control_rule](../../../../pkg/qiao_mode/skills/qun_control_rule.lua)：祸水回合内禁明置的按来源维护，工具见 [util/qun_control](../../../../pkg/qiao_generals/util/qun_control.lua)。
- [qun_duanchang_rule](../../../../pkg/qiao_mode/skills/qun_duanchang_rule.lua)：断肠已失技在后续明置时的幂等兜底，失技模块见 [qun_duanchang](../../../../pkg/qiao_mode/rules/qun_duanchang.lua)。

## 实际参考

本地引擎 `fk_ver` 0.5.25；hegemony HEAD `e8d93acd34a357f96b0105aef7d661708c211626`、utility HEAD `b14e45d9adf67b06bf150f71022e8f1dc0e26116`，与 `dependencies.lock.json` 一致。以下路径相对于 `.dev/runtime/FreeKill-release/`，只读未改上游：

- `packages/standard/pkg/skills/{jijiu,lijian,wushuang}.lua`：转桃、离间用牌及响应数入口；急救限制回合外，不符合济世。
- `packages/hegemony/pkg/standard/skills/{chuli,luanji,wushuang,shuangxiong,xiongyi,shuangren,sijian,suishi,kuangfu,huoshui,qingcheng,duanchang,weimu}.lua`，另读 `pkg/mobile_heg/skills/kuangfu.lua`：同名差异明显，尤其无双写死 2、双雄时机和牌区不同、双刃两分支不同、随势缺少弃手牌、狂斧效果不同，均不可直接复制。
- `ltk/core/events/usecard.lua`：`AimData` 响应次数、`UseCardData:isUsingHandcard`、`damageDealt` 及响应关联字段；`ltk/core/events/hp.lua`：体力变化数据；`ltk/server/events/judge.lua`：`changeJudge{exchange=true}` 获得旧判定牌。
- 项目内复用：`skill_shu006_1.lua`（共享马术）、`skill_wei002_2.lua`（真实打出改判）、`general_exchange.lua`、`only_as.lua`、`card_use_targets.lua` 及 [黄巾雷使](retinues.md#huangjin-leishi)、[并州狼骑](retinues.md#bingzhou-langqi)、[西凉精骑](retinues.md#xiliang-jingqi) 的既有实现。

## 待验证与待办

- 定向与默认全量已通过，具体命令与覆盖以[开发状态](../../status.md)和[验证记录](verification-evidence.md#qun-standard)为准。
- 修复除疠及乱武、狂斧、祸水、倾城、骁逆的客户端房间读取；客户端按钮回归已纳入默认套件，验证记录见下述链接。默认全量 764/764 及安装包核对已完成；客户端点击、联网／重连、干净本体安装仍未人工验收。
