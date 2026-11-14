# 吴势力标准包：实现与验证

本页为吴包 15 将、27 个天生技能、后天技能涉猎及锦帆军／曲阿小将两翼从的逐将索引。规则依据见[标准表](../../../../rules/standard-generals.md)与逐将规范；机制说明合并于跨势力专项，不复制另一套吴包正文。规则确认、实现与人工验收分别记录，当前完成度见[开发状态](../../status.md)。

## 1. 分组与逐将入口

| 编号 | 武将 | 技能 | 运行时 ID／源码 | 机制专项 | 专项测试 |
| --- | --- | --- | --- | --- | --- |
| WU001 | 孙权 | 制衡 | `hanjin__wu001`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu001_1.lua) | [support](support.md#吴势力标准包) | [wu_support](../../../../tests/wu_support.lua) |
| WU002 | 甘宁 | 奇袭 | `hanjin__wu002`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu002_1.lua) | [support](support.md#吴势力标准包) | [wu_support](../../../../tests/wu_support.lua) |
| WU003 | 吕蒙 | 克己、谋断；后天涉猎 | `hanjin__wu003`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu003_1.lua) | [phases](phases.md#吴势力标准包) | [wu_phases](../../../../tests/wu_phases.lua) |
| WU004 | 黄盖 | 苦肉、诈降 | `hanjin__wu004`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu004_1.lua) | [damage](damage.md#吴势力标准包) | [wu_damage](../../../../tests/wu_damage.lua) |
| WU005 | 周瑜 | 英姿、反间 | `hanjin__wu005`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu005_1.lua) | [support](support.md#吴势力标准包) | [wu_support](../../../../tests/wu_support.lua) |
| WU006 | 大乔 | 国色、流离 | `hanjin__wu006`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu006_1.lua) | [phases](phases.md#吴势力标准包) | [wu_phases](../../../../tests/wu_phases.lua) |
| WU007 | 陆逊 | 谦逊、度势 | `hanjin__wu007`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu007_1.lua) | [phases](phases.md#吴势力标准包) | [wu_phases](../../../../tests/wu_phases.lua) |
| WU008 | 孙尚香 | 结姻、枭姬 | `hanjin__wu008`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu008_1.lua) | [support](support.md#吴势力标准包) | [wu_support](../../../../tests/wu_support.lua) |
| WU009 | 孙坚 | 英魂 | `hanjin__wu009`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu009_1.lua) | [support](support.md#吴势力标准包) | [wu_support](../../../../tests/wu_support.lua) |
| WU011 | 小乔 | 天香、红颜 | `hanjin__wu011`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu011_1.lua) | [damage](damage.md#吴势力标准包) | [wu_damage](../../../../tests/wu_damage.lua) |
| WU012 | 太史慈 | 天义、酣战 | `hanjin__wu012`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu012_1.lua) | [pindian](pindian.md#吴势力标准包) | [wu_damage](../../../../tests/wu_damage.lua) |
| WU013 | 周泰 | 不屈、奋激 | `hanjin__wu013`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu013_1.lua) | [damage](damage.md#吴势力标准包) | [wu_damage](../../../../tests/wu_damage.lua) |
| WU014 | 鲁肃 | 好施、缔盟 | `hanjin__wu014`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu014_1.lua) | [damage](damage.md#吴势力标准包) | [wu_damage](../../../../tests/wu_damage.lua) |
| WU015A | 张昭 | 直谏、固政 | `hanjin__wu015a`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu015a_1.lua) | [support](support.md#吴势力标准包) | [wu_support](../../../../tests/wu_support.lua) |
| WU016 | 丁奉 | 短兵、奋迅 | `hanjin__wu016`；[技能源码](../../../../pkg/hanjin_generals/skills/skill_wu016_1.lua) | [phases](phases.md#吴势力标准包) | [wu_phases](../../../../tests/wu_phases.lua) |

涉猎以 `related = true` 登记，仅通过谋断获得，不计入天生技能数。两个翼从的源码为[锦帆军](../../../../pkg/hanjin_generals/skills/retinue_skill_jinfanjun.lua)、[曲阿小将](../../../../pkg/hanjin_generals/skills/retinue_skill_quaxiaojiang.lua)，实现与验收见[翼从组](retinues.md#吴势力标准包)及 `wu_damage.lua`；统领能力和翼从效果由公共机制提供。

## 2. 规则依据与发布接线

- [吕蒙](../../../../rules/generals/wu003-lvmeng.md)：谋断只获得涉猎，不额外发动；涉猎定义沿用用户指定文本。
- [周瑜](../../../../rules/generals/wu005-zhouyu.md)：反间响应有选择权，只展示手牌，弃置同花色手牌及装备牌；主将体力贡献 -1，按半格公共表示处理。
- [周泰](../../../../rules/generals/wu013-zhoutai.md)：不屈删去病句，摸 X 张、置一张“创”。
- [张昭](../../../../rules/generals/wu015a-zhangzhao.md)：直谏“手牌区→你摸牌、装备区→其摸牌”顺序对应；装备置入要求空置对应栏。
- [standard.lua](../../../../pkg/hanjin_generals/data/standard.lua)：吴区 15 个主称号、27 条天生技能原文与标准表核对一致；多称号只取首项。涉猎仍为后天相关技能，`M.skillCount = 160` 原口径不变；其他 75 张武将数据块未改。
- 技能骨架均显式 `hanjinImplemented = true`；[init.lua](../../../../pkg/hanjin_generals/init.lua) 既有加载断言确认有实际 effect。技能独立注册，仅用于汉晋模式。
- [mode.lua](../../../../pkg/hanjin_mode/mode.lua) 在启动时安装公开历史、奋迅距离、诈降／天义／好施持续效果及缔盟到期辅助；对应文件在 `pkg/hanjin_mode/skills/wu_*.lua`，公开事实层在 `rules/wu_history.lua`。客户端读取同步状态，不读取服务端事件树；涉猎整理规则随共享工具在正式扩展注册。
- 初始开发前先由 Codex 整理规则要点、公共接口方向及少量核心验收，DSH 分批实现并依审阅修正。采用按风险分层的验证，不将规则场景逐项变成新增测试义务。

## 3. 真实验证与发布

2026-11-14，三套专项已加入 [tests/all.lua](../../../../tests/all.lua) 默认国战套件：

| 专项 | 用例数 | 核心覆盖 |
| --- | --- | --- |
| `wu_support.lua` | 15 | 制衡、反间手装弃置及拒绝、结姻／直谏空栏与两来源、枭姬、英魂、固政多弃牌者选择、真实 ClientPlayer |
| `wu_phases.lua` | 12 | 克己／谋断历史、涉猎、国色两分支及不可重用、流离转移／取消不付费、谦逊、度势、短兵双闪与扩目标、奋迅失技持续 |
| `wu_damage.lua` | 22 | 伤害／失去体力、诈降累计与用杀次数、天香／红颜、天义／酣战、真实濒死不屈、好施与缔盟来源到期、两翼从 |

DSH 工具原生检查结果：

```text
python scripts/check_lua.py
退出码 0

python scripts/test.py --timeout 180
Ran 657 tests in 107.552 seconds, 657 successes, 0 failures
退出码 0

python scripts/build_release.py
Built .dev/dist/hanjin.zip (452 files)
退出码 0
```

Codex 核对安装包：本轮 39 个实现／数据／接线文件与工作区逐字节一致，包含吴区技能、两翼从、共享工具、公开历史与静态辅助；无 `tests/`、`scripts/`、`.dev/`。无需开发本体补丁提供上述效果。

## 4. 未完成人工验收与边界

未进行真实客户端逐项点击、多人联网／重连和干净本体安装运行验收。服务端真实请求及代表性 ClientPlayer 自动化不代替这些人工结果。少见红颜／禁弃组合、多次濒死完整求桃链、复杂嵌套与改目标组合未穷举，具体边界见所属机制专项；不因默认全量通过而宣称所有组合已验证。
