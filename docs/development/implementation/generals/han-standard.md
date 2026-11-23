# 汉势力标准包：逐将检索与验证入口

本页是汉势力标准包 15 将 25 技能与 2 名汉关联翼从的逐将检索入口，统一列出编号、运行时 ID、源码、逐技能实现详情与验证依据；技能正文只在机制页维护一份，本页不重复。规则表见[标准武将表](../../../rules/standard-generals.md)，卡面资料来源为 [`assets/docs/石激桑武将列表.json`](../../../../assets/docs/石激桑武将列表.json)，逐将裁定以 `docs/rules/generals/` 的已确认文件为准，不替代规则条文。当前完成度见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN001 | 刘协 | [天命](support.md#han001-1)、[密诏](pindian.md#han001-2) |
| HAN002 | 刘辩 | [诗怨](support.md#han002-1)、[毒逝](damage.md#han002-2) |
| HAN004 | 张让 | [滔乱](conversion.md#han004-1) |
| HAN005 | 何进 | [谋诛](active.md#han005-1)、[构难](damage.md#han005-2) |
| HAN006 | 王允 | [连计](damage.md#han006-1)、[定著](conversion.md#han006-2) |
| HAN007 | 王荣 | [敏思](support.md#han007-1)、[追德](damage.md#han007-2) |
| HAN008 | 伏皇后 | [惴恐](pindian.md#han008-1)、[求援](active.md#han008-2) |
| HAN009 | 伏完 | [谋溃](active.md#han009-1)、[穆顺](retinues.md#mushun)（关联翼从） |
| HAN010 | 董承 | [承诏](pindian.md#han010-1) |
| HAN011 | 唐姬 | [哀舞](damage.md#han011-1)、[诀别](damage.md#han011-2) |
| HAN012 | 蔡邕 | [铸典](support.md#han012-1)、[博通](conversion.md#han012-2) |
| HAN013 | 皇甫嵩 | [奋钺](pindian.md#han013-1) |
| HAN016A | 刘宠 | [劲弩](conversion.md#han016a-1)、[威屯](phases.md#han016a-2) |
| HAN017 | 刘繇 | [戡难](pindian.md#han017-1)、[逆拒](pindian.md#han017-2) |
| HAN018 | 蹇硕 | [集兵](support.md#han018-1)、[西园军](retinues.md#xiyuanjun)（关联翼从） |

HAN016A 的牌面编号保留 `A`，运行时 id 仍为 `qiao_heg__han016`，避免资源和已接线的汉区数据改名。

## 2. 关联翼从

| 翼从 | 运行时 ID | 实现详情 | 验证 |
| --- | --- | --- | --- |
| 穆顺 | `qiao_heg__retinue_mushun` | [翼从专属技能](retinues.md#mushun) | [han_retinues](../../../../tests/han_retinues.lua) |
| 西园军 | `qiao_heg__retinue_xiyuanjun` | [翼从专属技能](retinues.md#xiyuanjun) | [han_retinues](../../../../tests/han_retinues.lua) |

## 3. 接线

- [init.lua](../../../../pkg/qiao_generals/init.lua)：注册 90 名正式武将、14 名翼从、19 条统领来源；按 [data/standard.lua](../../../../pkg/qiao_generals/data/standard.lua) 生成称号、技能名、技能原文翻译。
- `data/standard.lua`：六势力牌面数据。汉区本批的 25 条技能原文与 15 个主称号已按 `docs/rules/standard-generals.md` 汉区及 `assets/docs/石激桑武将列表.json` 同步；`M.skillCount` 保持 160，不因汉区 25 条而改动。
- [skills/](../../../../pkg/qiao_generals/skills)：汉区 25 个技能骨架均已实装（HAN001 走 `init.lua` 既有白名单，其余通过骨架的 `qiaoImplemented = true` 登记）；其他势力未实装条目仍为零 effect 展示壳。翼从穆顺、西园军同样带 `qiaoImplemented`。
- [util/](../../../../pkg/qiao_generals/util)：汉区共享的 [han_history.lua](../../../../pkg/qiao_generals/util/han_history.lua)、[minsi.lua](../../../../pkg/qiao_generals/util/minsi.lua)。
- [client.lua](../../../../pkg/qiao_mode/client.lua) 及 `pkg/qiao_mode/rules/`：汉区客户端接线与公共用牌／目标／统领规则；发布包需包含这些文件，不能只靠开发本体补丁。
- 数据同步：15 个汉区主称号按 `assets/docs/石激桑武将列表.json` 的 `titles[0]` 同步；多称号武将（董承、蔡邕）主称号只取首项，第二称号不拼进主称号。25 条技能原文已逐条比对为零差异，修正 3 条旧文本：滔乱“本回合以此法使用的牌指定过的” → “本回合以此法使用牌指定过的”；定著“副将技（阴阳鱼-1）” → “副将技（☯️-1）”；集兵“造成伤害值小于X” → “造成伤害数小于X”。
- 珠联／翼从字段核对：刘辩—唐姬、伏皇后—刘协、董承—刘协、蔡邕—董卓（未在现 90 将内，保留未解析名称）与 `zhulian`／`zhulian_ke` 一致；其他汉区武将无珠联字段。其他势力 data 未改。
- 本批行为修正（实质问题，不增加测试量）：求援的优先目标和本次发动记录改挂 `UseCardData` 字段，避免 `extra_data` 在目标事件结束时被 AimData 旧值覆盖；谋溃的本次发动与反弃绑定改挂 `UseCardData` 字段，修复双选后抵消不触发反弃；劲弩实际使用也带 `bypass_times`，修复本阶段已出过【杀】时目标组合校验误挡技能视为使用的【杀】；西园军测试改为在出牌阶段内部 probe 公开／锁定／转化禁用与受伤取牌，再在 TurnEnd 后断言 `-turn` 清理，未放宽生产清理。

## 4. 验证

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的汉区汇总](verification-evidence.md#han-run-summary)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

<a id="han-standard-boundary"></a>

## 5. 未完成与边界

- 未在真实客户端逐项点击选牌名、选目标、拼点、弃牌和暗置交互；自动化验证的是真实服务端请求／回复与牌移动，不是 QML 界面操作。
- 未在干净的用户运行环境安装本 zip 后启动对局；只核对了包内容与静态接线。
- 刘协天命、密诏的规范化描述待办仍未完成，见[天命条目](support.md#han001-1)与[密诏条目](pindian.md#han001-2)；既有场景依据不是逐项新增测试义务。
