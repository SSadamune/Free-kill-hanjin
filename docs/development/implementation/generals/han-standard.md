# 汉势力标准包：实现与验证

本页记录汉势力标准 15 将 25 技能与 2 名汉关联翼从的实装接线、数据同步和验证结果，不替代规则裁定。规则表见[标准武将表](../../../../rules/standard-generals.md)，卡面资料来源为 [`docs/heroes.json`](../../../../docs/heroes.json)；逐将裁定以 `rules/generals/` 的已确认文件为准。

## 1. 范围与总览

| 编号 | 武将 | 技能 | 运行时 id | 实现详情 | 专项测试 |
| --- | --- | --- | --- | --- | --- |
| HAN001 | 刘协 | 天命、密诏 | `hanjin__han001` | [专项说明](han001-liuxie.md) | [han001_liuxie](../../../../tests/han001_liuxie.lua) |
| HAN002 | 刘辩 | 诗怨、毒逝 | `hanjin__han002` | [诗怨源码](../../../../pkg/hanjin_generals/skills/skill_han002_1.lua)、[毒逝源码](../../../../pkg/hanjin_generals/skills/skill_han002_2.lua) | [han_standard](../../../../tests/han_standard.lua) |
| HAN004 | 张让 | 滔乱 | `hanjin__han004` | [专项说明](han004-zhangrang.md) | [han004_zhangrang](../../../../tests/han004_zhangrang.lua) |
| HAN005 | 何进 | 谋诛、构难 | `hanjin__han005` | [专项说明](han005-hejin.md) | [han005_hejin](../../../../tests/han005_hejin.lua) |
| HAN006 | 王允 | 连计、定著 | `hanjin__han006` | [拼点组说明](han-pindian.md) | [han_standard_pindian](../../../../tests/han_standard_pindian.lua) |
| HAN007 | 王荣 | 敏思、追德 | `hanjin__han007` | [专项说明](han007-wangrong.md) | [han007_wangrong](../../../../tests/han007_wangrong.lua) |
| HAN008 | 伏皇后 | 惴恐、求援 | `hanjin__han008` | [专项说明](han008-fuhuanghou.md) | [han008_fuhuanghou](../../../../tests/han008_fuhuanghou.lua) |
| HAN009 | 伏完 | 谋溃 | `hanjin__han009` | [专项说明](han009-fuwan.md) | [han009_fuwan](../../../../tests/han009_fuwan.lua) |
| HAN010 | 董承 | 承诏 | `hanjin__han010` | [拼点组说明](han-pindian.md) | [han_standard_pindian](../../../../tests/han_standard_pindian.lua) |
| HAN011 | 唐姬 | 哀舞、诀别 | `hanjin__han011` | [专项说明](han011-tangji.md) | [han011_tangji](../../../../tests/han011_tangji.lua) |
| HAN012 | 蔡邕 | 铸典、博通 | `hanjin__han012` | [专项说明](han012-caiyong.md) | [han012_caiyong](../../../../tests/han012_caiyong.lua) |
| HAN013 | 皇甫嵩 | 奋钺 | `hanjin__han013` | [拼点组说明](han-pindian.md) | [han_standard_pindian](../../../../tests/han_standard_pindian.lua) |
| HAN016A | 刘宠 | 劲弩、威屯 | `hanjin__han016` | [专项说明](han016a-liuchong.md) | [han016_liuchong](../../../../tests/han016_liuchong.lua) |
| HAN017 | 刘繇 | 戡难、逆拒 | `hanjin__han017` | [专项说明](han017-liuyao.md) | [han017_liuyao](../../../../tests/han017_liuyao.lua) |
| HAN018 | 蹇硕 | 集兵 | `hanjin__han018` | [集兵源码](../../../../pkg/hanjin_generals/skills/skill_han018_1.lua) | [han_standard](../../../../tests/han_standard.lua) |

本页为全包入口；专项页面保留各将接口与验收依据。刘辩、蹇硕的实现与核心行为测试分别直接链接至源码和共享套件；王允、董承、皇甫嵩共用拼点组说明及测试。所有上述测试均纳入默认国战套件。

汉关联翼从 2 名：穆顺（`hanjin__retinue_mushun`）、西园军（`hanjin__retinue_xiyuanjun`），见[翼从实现说明](han-retinues.md)及[专项测试](../../../../tests/han_retinues.lua)。HAN016A 的牌面编号保留 `A`，运行时 id 仍为 `hanjin__han016`，避免资源和已接线的汉区数据改名。

## 2. 接线

- `pkg/hanjin_generals/init.lua`：注册 90 名正式武将、14 名翼从、19 条统领来源；按 `data/standard.lua` 生成称号、技能名、技能原文翻译。
- `pkg/hanjin_generals/data/standard.lua`：六势力牌面数据。汉区本轮的 25 条技能原文与 15 个主称号已按 `rules/standard-generals.md` 汉区及 `docs/heroes.json` 同步；`M.skillCount` 保持 160，不因汉区 25 条而改动。
- `pkg/hanjin_generals/skills/`：汉区 25 个技能骨架均已实装（HAN001 走 `init.lua` 既有白名单，其余通过骨架的 `hanjinImplemented = true` 登记）；其他势力未实装条目仍为零 effect 展示壳。翼从穆顺、西园军同样带 `hanjinImplemented`。
- `pkg/hanjin_generals/util/`：汉区共享的 `han_history.lua`、`minsi.lua`。
- `pkg/hanjin_mode/client.lua` 及 `pkg/hanjin_mode/rules/`：汉区客户端接线与公共用牌/目标/统领规则；发布包需包含这些文件，不能只靠开发本体补丁。

## 3. 数据同步与本轮修正

- 15 个汉区主称号按 `docs/heroes.json` 的 `titles[0]` 同步；多称号武将（董承、蔡邕）主称号只取首项，第二称号不拼进主称号。
- 25 条技能原文已逐条与 `docs/heroes.json` 比对为零差异；本轮修正 3 条旧文本：
  - 滔乱：“本回合以此法使用的牌指定过的” → “本回合以此法使用牌指定过的”；
  - 定著：“副将技（阴阳鱼-1）” → “副将技（☯️-1）”；
  - 集兵：“造成伤害值小于X” → “造成伤害数小于X”。
- 珠联/翼从字段核对：刘辩—唐姬、伏皇后—刘协、董承—刘协、蔡邕—董卓（未在现 90 将内，保留未解析名称）与 `zhulian`/`zhulian_ke` 一致；其他汉区武将无珠联字段。其他势力 data 未改。
- 行为修正（本轮实质问题，不增加测试量）：
  - 求援：优先目标和本次发动记录改挂 `UseCardData` 字段，避免 `extra_data` 在目标事件结束时被 AimData 旧值覆盖。
  - 谋溃：本次发动与反弃绑定改挂 `UseCardData` 字段，修复双选后抵消不触发反弃。
  - 劲弩：实际使用也带 `bypass_times`，修复本阶段已出过【杀】时目标组合校验误挡技能视为使用的【杀】。
  - 西园军：测试改为在出牌阶段内部 probe 公开/锁定/转化禁用与受伤取牌，再在 TurnEnd 后断言 `-turn` 清理；未放宽生产清理。

## 4. 验证结果

最新代码验证已包含鏖战杀／闪选择修复及滔乱每回合一次的裁定：同一角色同回合多次发动滔乱，回合末后续效果只结算一次，候选取本回合指定目标并集。历次验证记录见[开发状态](../../status.md)。

最近一次实际执行的默认全量：

```text
python scripts/test.py --timeout 120
Ran 567 tests in 83.184 seconds, 567 successes, 0 failures
```

滔乱专项 `tests/han004_zhangrang.lua` 最近一次定向验证为 4 项全部通过，包含同回合两次发动仅一次后续结算及候选合并。其余武将的测试入口见上表，均由这次默认全量覆盖；刘协详细验收依据见其专项页面，不将服务端自动化通过等同于客户端人工验收完成。

安装包：

```text
python scripts/build_release.py
Built .dev/dist/hanjin.zip (440 files)
```

已检查 zip：包含 `hanjin/pkg/hanjin_generals/skills/`、`hanjin/pkg/hanjin_generals/util/`、`hanjin/pkg/hanjin_generals/data/standard.lua`、`hanjin/pkg/hanjin_mode/client.lua` 与根 `hanjin/init.lua`；不包含 `tests/` 或 `scripts/`。

## 5. 尚未人工验证

- 未在真实客户端逐项点击选牌名、选目标、拼点、弃牌和暗置交互；自动化验证的是真实服务端请求/回复与牌移动，不是 QML 界面操作。
- 未在干净的用户运行环境安装本 zip 后启动对局；只核对了包内容与静态接线。
