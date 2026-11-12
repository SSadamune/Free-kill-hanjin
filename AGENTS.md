# 紫乔汉晋项目约定

- 本扩展的规则、设计、实现与测试以手杀国战为基础，具体规则以用户确认的设计和 `rules/README.md` 及其引用的规范为准。规则差异尚未明确时应标明。
- `docs/rules/` 下的全部文章是解读三国杀技能描述和编写「规范化描述」的基础参考。技能描述按规则集定义的术语、逻辑结构、时机、消耗与效果解析，不凭日常自然语言猜测，不把已有明确定义的规则写成建议或重新请求裁定；处理具体技能时须查阅相关原文。项目已确认的设计差异依用户裁定与 `rules/` 规范执行，须明确标注差异。
- 具体武将的结算细节、裁定和测试设计统一放在 `rules/generals/`，按武将编号一将一文件（如 `han001-liuxie.md`）；公共规则留在 `rules/` 顶层，由武将文档引用，不重复另定。
- 国战流程的实现参考 `Qsgs-Fans/hegemony` 的 `new_heg_mode`；`hegemony`、`utility` 的版本固定在 `dependencies.lock.json`。不要直接修改 `.dev/` 中的上游依赖。
- 处理技能时需考虑主副将、明暗置、技能所属武将、势力及敌友关系；移除或替换武将时需处理国战关联结算。
- 统领与翼从的公共规则应集中实现。始终区分“统领能力”和“翼从效果”，提到其中一个概念时不得混用另一个概念；二者的效果、作用范围和生效时间分别遵循 `rules/commander-retinue.md`。
- `hanjin_heg_mode` 是独立模式，正式武将和卡牌须独立创建。已有牌复用新月杀实装并适配汉晋规则；多个版本由用户选择，未找到实装的牌保留空壳。上游内容与测试占位内容不得直接填入正式将池或牌堆。
- 势力禁选、跨局记录、野心家数量及装备/锦囊策略遵循 `rules/faction-ban.md` 的 MUST 约束；实体规则可转换为等价程序流程。
- 应变实现遵循 `rules/adaptation.md`，使用汉晋应变 API，并区分 `isAdaptationCard` 与 `Triggered` 事件。上游应变参考源码位于 `.dev/reference/gamemode`，版本登记在 `dependencies.lock.json`，仅供核对。
- 默认运行 `python scripts/test.py`（`tests/all.lua`）。国战技能测试加入默认国战套件，汉晋技能 `addTest` 回调仅在汉晋测试房间运行；`--skills` 使用官方默认房间，仅用于工具或上游测试验证。
- `tests/support/hanjin_content.lua` 为测试专用内容，不得发布。实装进度集中记录在 `rules/README.md` 及对应规范中，对外说明须与当前实现一致。
- `rules/` 由 Codex 维护。DSH 默认只读；需要修改时，须先说明具体文件、理由和拟议改动，经 Codex 审阅并明确允许后再修改。
- 需要 UI 素材时，先向用户说明需求并索取原材料，再按指示加工。从零生图或绘制素材须事先得到用户明确批准。
- 用户安装包使用 `python scripts/build_release.py` 构建，仅包含 `init.lua`、`pkg/`、`image/`、`audio/`。本体适配仅由开发脚本应用于本地运行环境，不得从扩展入口执行或打入用户安装包；仅开发环境生效的功能须在 README 中注明。

## 提交格式

- 使用规范式提交，格式为 `类型: 中文标题`，标题简洁说明改动。功能使用 `feature`，修复使用 `fix`，文档使用 `docs`；其他改动可使用 `refactor`、`test`、`chore` 等对应类型。
- 示例：`feature: 完善客将逐张重抽并更新汉晋势力素材`。
- 根据实际参与开发的模型，在提交消息末尾附上对应的合作编辑者署名，与正文之间留一个空行。多位合作编辑者各占一行，署名行之间不留空行，作为同一个连续的提交尾注段落：

  ```text
  Co-authored-by: Codex <codex@openai.com>
  Co-authored-by: DeepSeek <noreply@deepseek.com>
  ```
