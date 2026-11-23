# 穆顺

[翼从索引](../retinues.md)

<a id="mushun"></a>

## 穆顺

- **标识与依据**：翼从 ID `qiao_heg__retinue_mushun`，技能 ID `qiao__retinue_skill_mushun`；源码 [retinue_skill_mushun.lua](../../../../../pkg/qiao_generals/skills/retinue_skill_mushun.lua)。规则见[标准武将表](../../../../rules/standard-generals.md)翼从穆顺、[移动事件](../../../../../rulebook/events/move-card.md)、[弃置](../../../../../rulebook/terms/card-op-terms/discard.md)。

牌面原文见[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L638)的统领条目。

> 每回合限一次，当你弃置任意角色的牌或被其他角色弃置牌后，你可以获得其中一张。若如此做，本回合你下次弃置任意角色的牌或被其他角色弃置牌后，你失去1点体力。

- **实现与接口**：
  - 监听真实 `fk.AfterCardsMove`：只认 `moveReason == fk.ReasonDiscard` 且目标为弃牌堆的移动；重铸、给牌等不计。
  - 分别按真实移动数据判断：`move.proposer == 穆顺` 为自己弃置任意角色的牌（含自己主动弃自己的牌）；`move.from == 穆顺` 且 `proposer` 为其他角色为被其他角色弃置。不按技能名或猜测的弃牌者判断。
  - 结算时通过 `askToChooseCards` 的独立牌组展示本次仍在弃牌堆的候选，允许取消。确认后再核对牌仍在弃牌堆，取得后写本回合限制标记。
  - 取得成功后才建立 `-turn` 的“下一次同条件弃牌失 1 点体力”标记；罚效果由房间级延迟监听器读取角色标记，不要求穆顺当前仍有技能。罚监听只判断“是否发生了符合条件的弃置”，不要求牌仍在弃牌堆：即使该次弃置的牌已被同优先级技能取走，仍失血。取得事件本身用事件标识抑制同一事件刚建立的罚效果，避免重复扣血。
  - 取得次数标记以技能名开头，随翼从武将迁移；罚标记附在角色身上、不带技能前缀，避免误迁。每回合取得一次由 `-turn` 标记限制。
- **验证依据**：[han_retinues.lua](../../../../../tests/han_retinues.lua) 夹具直接授予正式翼从技能、只验证技能本身，覆盖穆顺取得与下一次失血（弃置他人牌后取回一张；同回合下一次弃牌不再取得，失去 1 点体力）。历史记录见[共享验证证据](../verification-evidence.md#han_retinues)。
- **未完成与边界**：翼从取得／失去技能由统领公共流程覆盖，本测试直接授予技能，不替代该流程验收；真实客户端弃牌与取牌交互未人工验收。
