# 外部参考：《三国杀规则集》

本目录保存项目现有的《三国杀规则集》参考资料，涵盖术语、定义、事件流程及专题。条文已复制到 `rulebook/` 作为汉晋规则集的工作底稿，其他文档的具体规则引用统一转向新目录。本目录保留来源副本，不再作为项目日常条文引用入口。最终标准的独立编纂位置为 [`rulebook/`](../../rulebook/README.md)，现有项目设计与裁定另见 [`rules/`](../../rules/README.md)，项目方向见[愿景说明](../vision.md)。

## 查阅入口

- [定义与结算原则](definitions/settlement-principles.md)：术语和流程之间的关系。
- [描述术语](terms/description-terms/limit_card.md)：例如“某人的牌”；应按所处理文本查阅该目录中的相关术语。
- [技能使用事件](events/use-skill.md)：发动、消耗与效果的流程。
- [使用牌事件](events/use-card.md)：使用、目标、响应与结算。
- [阶段事件](events/phase.md)：阶段内的时机与空闲时间点。
- [牌的可使用条件](topics/card-usable-conditions.md)：使用合法性。

可用 `rg --files docs/rules` 查找目录，用关键词在 `definitions/`、`events/`、`terms/`、`topics/` 中定向搜索；无需在每个开发任务中全文加载所有资料。

## 来源与维护边界

当前仓库未提供足以确认这批参考资料具体上游版本的完整元数据；不补写未经核实的版本、作者或授权结论。后续补充来源信息时保留可追溯依据。

汉晋设计差异及裁定先记录于 `rules/`；正式规则条文和规范描述独立编纂于 `rulebook/`，不直接覆盖参考原文。发现参考资料的疑误或拟升级来源时，单独记录并审阅，避免把汉晋改编混入外部资料。

部分文章的 API 引用来自原资料组织结构，当前仓库未必包含目标文件。例如 `events/use-skill.md` 引用的 `docs/project-api/event/UseSkillEvent.md` 当前缺失。规则原文可供语义核对；当前新月杀接口仍须以锁定版本的本地源码核实，缺失的 API 引用不构成接口存在的证据。
