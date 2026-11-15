# QUN016 田丰：死谏与随势的来源基线

采用[标准武将表](../standard-generals.md)和外部 JSON 的 QUN016 标准版，不采用当前程序资料中的不同版本。以下是来源核对，不是新增裁定。

- 死谏的两个时机为“失去最后的手牌后”和“体力值变化为 1 后”；后者没有限定体力必须减少。不是手牌数／体力值变为 0。
- 死谏弃置一名其他角色的一张牌，按[某人的牌](../../rulebook/terms/description-terms/limit_card.md)仅含手牌和装备；不包含判定区，不附带回复体力。
- 随势在其他角色进入濒死时检查伤害来源与自己是否势力相同；同势力其他角色死亡时，自己在“失去 1 点体力”和“弃置所有手牌”之间选择，不是强制失去体力。具体操作的可执行性依[弃置](../../rulebook/terms/card-op-terms/discard.md)及[技能使用事件](../../rulebook/events/use-skill.md)处理。

两技能目前均为空壳。本轮保留程序资料差异，未修改实现／测试；对应位置见[群包审阅](../../docs/development/implementation/generals/qun-standard.md)。
