# 实现与验证导航

按正式扩展的登记和接线整理。游戏语义见[项目规则](../../rules/README.md)与[规则集底稿](../../../rulebook/README.md)。[开发状态](../status.md#当前验收基线)记录当前验收基线。[共享验证证据](generals/verification-evidence.md)保留历史测试命令、批次和环境。

## 武将与翼从

- [标准包](generals/standard.md) · [汉势力](generals/han-standard.md) · [魏势力](generals/wei-standard.md) · [蜀势力](generals/shu-standard.md) · [吴势力](generals/wu-standard.md) · [群势力](generals/qun-standard.md) · [晋势力](generals/jin001-simayan.md)
- [阵包](generals/zhen.md) · [势包](generals/shi.md)
- [权包](generals/quan.md) · [变包](generals/bian.md) · [矢包](generals/shi-vector.md) · [弩包](generals/nu.md) 检索已正式接入的君主版，其余武将的状态见各包入口。
- [翼从专属技能](generals/retinues.md)可按兵种进入，包含标准包 14 种、阵包八阵兵、势包青州精锐与庐江上甲。各武将索引另给出实际关联的翼从。

## 基础机制

| 职责 | 实现入口 |
| --- | --- |
| 房间与开局 | [模式设置、选将和后置位手气卡](mode-rules.md#房间与开局) · [势力禁选](faction-ban.md) · [客将、配将与重抽](guest-factions.md) · [配将体力](generals/pair-hp.md) |
| 势力与身份 | [人数上限与首次奖励](mode-rules.md#势力与身份) · [野心家效忠](wild-allegiance.md) · [第二君主升变与继位](second-lord.md) |
| 武将牌与技能来源 | [明暗置接线](mode-rules.md#明暗置) · [交换与后天附将技能](general-exchange.md) · [变更、移除与武将弃牌堆](general-exchange.md#变更移除与武将弃牌堆) · [统领能力与翼从效果](commander-retinue.md) |
| 对局时序与状态 | [轮次、回合、阶段与死亡](mode-rules.md#轮次回合阶段与死亡) · [移出游戏](mode-rules.md#移出游戏) · [阵法召唤](mode-rules.md#阵法召唤) · [标记上限](mode-rules.md#标记上限) |
| 用牌与结算 | [用牌目标](card-use-targets.md) · [额外目标](extra-targets.md) · [多次结算](card-resolution.md) · [自由用牌](mode-rules.md#自由用牌) · [只能当](only-as.md) · [应变](adaptation.md) · [鏖战](battle-royal.md) |

<a id="效果分类"></a>

## 技能按效果检索

[伤害、体力与死亡](generals/damage.md) · [牌资源与授技](generals/support.md) · [转化与生成用牌](generals/conversion.md) · [用牌目标与距离](generals/active.md) · [阶段与回合流程](generals/phases.md) · [拼点](generals/pindian.md) · [判定与花色](generals/retrial.md) · [配将体力](generals/pair-hp.md) · [翼从专属技能](generals/retinues.md)

机制页收录该机制的技能主记录，也可链接位于逐将页的技能。跨机制时从两处入口指向同一条记录。

## 卡牌、客户端与加载

- [牌堆和正式卡牌](card-deck.md) · [君主装备](card-deck.md#君主装备) · [势力锦囊](card-deck.md#势力锦囊)
- [技能界面与请求](skill-ui.md) · [客将插画接线](../guest-illustrations.md) · [扩展加载与新核心布局](extension-loading.md)

## 共享验证证据与历史记录

- [共享验证证据](generals/verification-evidence.md)按机制和批次汇集历史结果。阵包、势包共同引用[分批验证](generals/verification-evidence.md#阵包与势包分批验证)。
- [开发状态](../status.md)记录现行实装、当前验收及待办。[测试规范](../testing.md)说明入口和验证分层。[故障案例](../lessons.md)记录可复用的故障根因。

## 分类与检索约定

1. **新增或调整武将。** 以真实卡面包别和正式登记为准，在所属包增加「编号｜武将｜技能」行。标准包按汉、魏、蜀、吴、群、晋，势力内按编号。技能按卡面顺序链接，君主版列在其正式内容包。关联、派生技能及专属旗、标记在卡面技能之后加链接，并注明关系。共用程序加载包、开发批次和测试不改变内容归属。尚在规则审阅的包链接到规则资料并注明未登记的范围。
2. **选择唯一主记录。** 技能可保留在主要机制页，相关武将及机制入口共同链接。同文共享技能在主条目注明相关武将、运行时 ID 及独立来源，已有锚点继续复用。确有两套独立机制和测试时，分记录只承载该侧细节并回链主记录。普通技能锚点用牌面编号与技能序号，例如 `#han001-1`、`#han016a-1`，运行时 ID 写实际值。君主版使用 `#em-wei001-1` 这类锚点，翼从用稳定兵种名。
3. **新增公共机制、卡牌或客户端接线。** 先查对应职责组及已有记录。公共模块记录入口、调用双方、数据、时机与正式加载。具体技能写本身如何调用、复核和处理特殊分支。客户端、卡牌内容及加载进入各自分类。部分接入或尚未验证时具体写出对应路径。
4. **每批稳定后同步。** 更新主记录、受影响索引和[开发状态](../status.md)。历史命令、原验证环境和批次结果集中在[共享验证证据](generals/verification-evidence.md)。移动内容后修复入站链接或保留锚点。用一次实际检索复核武将条目和公共机制。规则确认、正式接入、自动化和人工验收分别记录。

### 技能与专属效果条目

| 字段 | 内容 |
| --- | --- |
| **标识与依据** | 名称、所属武将及版本、运行时 ID、源码和项目规则。逐字引用对应牌面文字，用 Markdown 引用块并链接到原始图片、文字提取或外部资料的具体位置。项目登记与原始资料异文时明确采用口径，缺少可核实来源时说明具体缺口。 |
| **实现与接口** | 用完整句子写清谁在何时发动、验证哪些条件、选择什么、怎样支付和结算。事件名及 API 放在对应步骤中。涉及选牌和正式执行两步时分别写明，明确角色指代和服务端再次校验。明暗置、持续状态和多技能来源要写清归属、迁移和清理。 |
| **验证依据** | 链接能支持结论的用例，说明走了哪个入口、断言什么、是否有预设结果或请求替身。把离屏界面和真人操作实测的范围写清，整包通过数引用历史证据。 |
| **未完成与边界** | 写出与该条特有的暂行口径、限制或待验证场景。通用人工验收范围引用[开发状态](../status.md#当前验收基线)。 |

简单条目见[英姿](generals/support.md#wu005-1)。它用一段写出摸牌事件和手牌上限，并指向两项断言。复杂条目见[穿心](generals/shi-skills.md#qun024-1)，它沿候选产生、请求、变更成功或否则分支展开，并链接来源同步。写清按步骤支付的例子见[骁果](generals/damage.md#wei016-1)。
