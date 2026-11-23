# 汉势力标准包：逐将检索与验证入口

本页是汉势力标准包 15 将 25 技能与 2 名汉关联翼从的逐将检索入口，武将和卡面技能链接到逐将页，运行时 ID、源码和验证依据随对应条目维护。规则表见[标准武将表](../../../rules/standard-generals.md)，卡面资料来源为 [`assets/docs/石激桑武将列表.json`](../../../../assets/docs/石激桑武将列表.json)，逐将裁定以 `docs/rules/generals/` 的已确认文件为准，不替代规则条文。当前完成度见[开发状态](../../status.md)。

## 1. 逐将表

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| HAN001 | [刘协](standard/han001.md) | [天命](standard/han001.md#han001-1)、[密诏](standard/han001.md#han001-2) |
| HAN002 | [刘辩](standard/han002.md) | [诗怨](standard/han002.md#han002-1)、[毒逝](standard/han002.md#han002-2) |
| HAN004 | [张让](standard/han004.md) | [滔乱](standard/han004.md#han004-1) |
| HAN005 | [何进](standard/han005.md) | [谋诛](standard/han005.md#han005-1)、[构难](standard/han005.md#han005-2) |
| HAN006 | [王允](standard/han006.md) | [连计](standard/han006.md#han006-1)、[定著](standard/han006.md#han006-2) |
| HAN007 | [王荣](standard/han007.md) | [敏思](standard/han007.md#han007-1)、[追德](standard/han007.md#han007-2) |
| HAN008 | [伏皇后](standard/han008.md) | [惴恐](standard/han008.md#han008-1)、[求援](standard/han008.md#han008-2) |
| HAN009 | [伏完](standard/han009.md) | [谋溃](standard/han009.md#han009-1)、[穆顺](standard/retinue-mushun.md#mushun)（关联翼从） |
| HAN010 | [董承](standard/han010.md) | [承诏](standard/han010.md#han010-1) |
| HAN011 | [唐姬](standard/han011.md) | [哀舞](standard/han011.md#han011-1)、[诀别](standard/han011.md#han011-2) |
| HAN012 | [蔡邕](standard/han012.md) | [铸典](standard/han012.md#han012-1)、[博通](standard/han012.md#han012-2) |
| HAN013 | [皇甫嵩](standard/han013.md) | [奋钺](standard/han013.md#han013-1) |
| HAN016A | [刘宠](standard/han016a.md) | [劲弩](standard/han016a.md#han016a-1)、[威屯](standard/han016a.md#han016a-2) |
| HAN017 | [刘繇](standard/han017.md) | [戡难](standard/han017.md#han017-1)、[逆拒](standard/han017.md#han017-2) |
| HAN018 | [蹇硕](standard/han018.md) | [集兵](standard/han018.md#han018-1)、[西园军](standard/retinue-xiyuanjun.md#xiyuanjun)（关联翼从） |

HAN016A 的牌面编号保留 `A`，运行时 id 仍为 `qiao_heg__han016`，避免资源和已接线的汉区数据改名。

## 2. 关联翼从

| 翼从 | 运行时 ID | 实现详情 | 验证 |
| --- | --- | --- | --- |
| 穆顺 | `qiao_heg__retinue_mushun` | [翼从专属技能](standard/retinue-mushun.md#mushun) | [han_retinues](../../../../tests/han_retinues.lua) |
| 西园军 | `qiao_heg__retinue_xiyuanjun` | [翼从专属技能](standard/retinue-xiyuanjun.md#xiyuanjun) | [han_retinues](../../../../tests/han_retinues.lua) |

## 3. 接线

- [init.lua](../../../../pkg/qiao_generals/init.lua)：注册 90 名正式武将、14 名翼从、19 条统领来源；按 [data/standard.lua](../../../../pkg/qiao_generals/data/standard.lua) 生成称号、技能名、技能原文翻译。
- `data/standard.lua`：六势力牌面数据。汉区本批的 25 条技能原文与 15 个主称号已按 `docs/rules/standard-generals.md` 汉区及 `assets/docs/石激桑武将列表.json` 同步；`M.skillCount` 保持 160，不因汉区 25 条而改动。
- [skills/](../../../../pkg/qiao_generals/skills)：汉区 25 个技能骨架均已实装（HAN001 走 `init.lua` 既有白名单，其余通过骨架的 `qiaoImplemented = true` 登记）；其他势力未实装条目仍为零 effect 展示壳。翼从穆顺、西园军同样带 `qiaoImplemented`。
- [util/](../../../../pkg/qiao_generals/util)：汉区共享的 [han_history.lua](../../../../pkg/qiao_generals/util/han_history.lua)、[minsi.lua](../../../../pkg/qiao_generals/util/minsi.lua)。
- [client.lua](../../../../pkg/qiao_mode/client.lua) 及 `pkg/qiao_mode/rules/`：汉区客户端接线与公共用牌／目标／统领规则；发布包需包含这些文件，不能只靠开发本体补丁。
- 数据同步：15 个汉区主称号按 `assets/docs/石激桑武将列表.json` 的 `titles[0]` 同步；多称号武将（董承、蔡邕）主称号只取首项，第二称号不拼进主称号。25 条技能原文已逐条比对为零差异，修正 3 条旧文本：滔乱“本回合以此法使用的牌指定过的” → “本回合以此法使用牌指定过的”；定著“副将技（阴阳鱼-1）” → “副将技（☯️-1）”；集兵“造成伤害值小于X” → “造成伤害数小于X”。
- 珠联／翼从字段核对：刘辩—唐姬、伏皇后—刘协、董承—刘协、蔡邕—董卓（未在现 90 将内，保留未解析名称）与 `zhulian`／`zhulian_ke` 一致；其他汉区武将无珠联字段。其他势力 data 未改。

## 4. 验证

按技能检索真实回归入口。整包测试、历史命令与当时的环境见[共享验证证据的汉区汇总](verification-evidence.md#han-run-summary)。当前验收及共通的人工待办见[开发状态](../../status.md#当前验收基线)。

<a id="han-standard-boundary"></a>

## 5. 未完成与边界

- 未在真实客户端逐项点击选牌名、选目标、拼点、弃牌和暗置交互；自动化验证的是真实服务端请求／回复与牌移动，不是 QML 界面操作。
- 未在干净的用户运行环境安装本 zip 后启动对局；只核对了包内容与静态接线。
- 刘协天命、密诏的规范化描述待办仍未完成，见[天命条目](standard/han001.md#han001-1)与[密诏条目](standard/han001.md#han001-2)；既有场景依据不是逐项新增测试义务。
