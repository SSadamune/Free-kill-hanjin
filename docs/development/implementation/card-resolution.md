# 同一张牌的多次结算：实现与验证

游戏语义见[对应规则](../../../rules/card-resolution.md)；当前实装与待办见[开发状态](../status.md)。本页保留接口、接线和验收依据，不替代规则裁定，历史覆盖说明不代表已完成全部人工验收。

## 3. 当前实现与验证

- 正式【酒】为独立牌名 `hanjin__analeptic`，通过 `pkg/hanjin_cards/data/reuse.lua` 复用上游 `analeptic_skill`。濒死求桃流程在用牌数据 `extra_data.analepticRecover` 中确立回复用途；每次生效读取同一次用牌传下来的标记，而非重新检查当前体力是否小于 1。新增视为使用入口时也须正确传递已确立的使用方法。
- 引擎 `ltk/server/events/usecard.lua` 在目标流程结束后，通过 `UseCardData.additionalEffect` 重复普通牌的结算；不会重新调用 `room:useCard`。本文不要求修改 `.dev/` 中的上游依赖。
- `tests/card_resolution.lua` 已纳入 `tests/all.lua`，覆盖真实濒死求桃入口中【酒】②回复两次、【酒】①额外结算两次、双目标【杀】逐轮结算及使用／目标时机仅一次，并记录以牌为目标的抵消效果仅一次的现状。
