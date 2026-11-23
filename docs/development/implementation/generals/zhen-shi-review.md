# 阵包与势包 · 旧入口

[阵包](zhen.md)与[势包](shi.md)各有逐将索引。每个已登记武将的技能按卡面顺序链接到主记录。

## 标识与依据

[阵包与势包规则](../../../rules/zhen-shi-generals.md)保留逐将来源、裁定与暂行口径。[正式登记](../../../../pkg/qiao_generals/init.lua)显示两包共用加载位置。

## 实现与接口

[阵包逐将索引](zhen.md#逐将检索) · [势包逐将索引](shi.md#逐将检索) · [翼从专属效果](retinues.md) · [公共技能来源](../general-exchange.md#公共武将来源职责)

### 阵法与技能来源

[阵法召唤](../mode-rules.md#阵法召唤)记录邀请、客户端请求、计次与专项用例。[统领与翼从](../commander-retinue.md)维护公共来源和实例。曹洪、蒋钦、姜维等武将如何接入见各自技能。

### 已查的上游接口

分批审阅使用 FreeKill 0.5.25，hegemony `e8d93acd34a3`、utility `b14e45d9adf6`。完整版本见[锁定文件](../../../../dependencies.lock.json)。下列路径相对于锁定运行时的 `packages/hegemony/`。

| 上游入口 | 采用或区分的内容 |
| --- | --- |
| `util.lua` 的 `getFormationRelation`、`inFormationRelation`、`inSiegeRelation` | 复用座次和势力关系。队列查询返回其他成员，围攻查询区分两名围攻者及被围攻者。 |
| `pkg/mobile_heg/skills/heyi.lua`、`pkg/formation/skills/tianfu.lua`、`pkg/formation/skills/niaoxiang.lua` | 参考阵法来源刷新、主将标签及逐目标入口。汉晋的实际效果分别见[鹤翼](zhen/wei018.md#wei018-2)、[天覆](zhen/shu012.md#shu012-2)、[鸟翔](zhen/wu017.md#wu017-2)。 |
| `pkg/hegemony_nos/skills/huyuan.lua`、`pkg/formation/skills/{qianhuan,shengxi,shoucheng}.lua` | 参考装备置入、目标取消、阶段和移牌事件。[护援](zhen/wei018.md#wei018-1)、[千幻](zhen/qun011.md#qun011-1)、[生息](zhen/shu018b.md#shu018b-1)、[守成](zhen/shu018b.md#shu018b-2)各自记录汉晋使用的条件和后续。 |
| `pkg/mobile_heg/skills/chuanxin.lua`、`pkg/momentum/skills/{hongfa,yingyang}.lua` | 区分上游穿心的伤害后入口，参考旗来源和拼点点数修改。[穿心](shi/qun024.md#qun024-1)、[弘法](shi/em-qun010.md#em-qun010-1)及[鹰扬](shi/wu010.md#wu010-2)按各自规则进入。 |

## 验证依据

两包共用[历史分批验证](verification-evidence.md#阵包与势包分批验证)，当前验收状态见[开发状态](../../status.md#当前验收基线)。

## 未完成与边界

修体、武库的暂行口径以及未完成的独立验证分别记录在技能条目中。
