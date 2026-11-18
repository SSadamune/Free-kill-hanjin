-- 势力锦囊的共用流程：用牌时的势力时点记录，以及置入弃牌堆时改移出游戏。
--
-- 由 mode.lua 在 logic:start 时以 `room:addSkill("qiao__faction_trick_rule")` 接入；
-- 不属于任何武将、翼从或装备来源，也不随来源移除。规则依据见
-- docs/rules/card-deck.md「势力锦囊的结算审阅」与 BAN-004 第 7、8 条：
--   * fk.CardUsing：按牌本身所属势力写入「用牌时使用者是否已确定」的快照，
--     本次用牌的势力效果只读该快照，受益者另按各自时点核对；
--   * fk.BeforeCardsMove：此类实体牌将置入弃牌堆时，只把该牌自己的移动
--     目的地换成游戏外（Card.Void），同批其他牌照常移动，并保留原移动原因、
--     技能名、执行者与可见性，使既有触发语义按原动作成立。
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"

local skill = fk.CreateSkill {
  name = "qiao__faction_trick_rule",
  tags = { Skill.Compulsory },
}

--- 记录“本局曾公开出现野心家”，并立即同步诏书的公开可取候选。
--- 只看公开的 player.kingdom；不读取暗将或服务端私有信息。
local function notePublicWild(room, player)
  if room == nil or player == nil or player.kingdom ~= "wild" then return end
  -- 只认对局中的公开事实：选将阶段的临时势力设置发生在 Turn/Phase 之外，
  -- 不是“公开成为野心家”。
  local current = room.logic:getCurrentEvent()
  local inTurn = current ~= nil and (current:findParent(GameEvent.Turn, true) ~= nil
    or current:findParent(GameEvent.Phase, true) ~= nil)
  if not inTurn then return end
  Cards.markWildSeen(room)
  local ok, Zed = pcall(require, "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han")
  if ok and type(Zed.syncTricks) == "function" then
    Zed.syncTricks(room)
  end
end

--- 实体牌本身身份；不按锁定视为后的牌名判断「是不是势力锦囊」。
---@param info MoveInfo
---@return Card|nil
local function realCardOf(info)
  return Fk:getCardById(info.cardId, true) or info.beforeCard
end

---@param data MoveCardsData[]|nil
---@return boolean
local function hasRedirect(data)
  for _, move in ipairs(data or {}) do
    if move.toArea == Card.DiscardPile then
      for _, info in ipairs(move.moveInfo or {}) do
        if FactionTricks.isFactionTrick(realCardOf(info)) then return true end
      end
    end
  end
  return false
end

-- 用牌时（规则集的「牌被使用时」）记录势力快照。refresh 通道不进入发动选择，
-- 也不产生询问；同一事件只写一次。
skill:addEffect(fk.CardUsing, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if data == nil or FactionTricks.kingdomOf(data.card) == nil then return false end
    local room = Fk:currentRoom()
    if room:getTag(FactionTricks.USE_TAG) == event.id then return false end
    -- 已由其他来源写入的快照不再覆盖（例如同一张牌被重复触发时）。
    return data.extra_data == nil or data.extra_data[FactionTricks.USE_KEY] == nil
  end,
  on_refresh = function(self, event, target, player, data)
    Fk:currentRoom():setTag(FactionTricks.USE_TAG, event.id)
    FactionTricks.recordUse(data)
  end,
})

-- late_refresh：在其他普通触发处理完同批移动后再改道，避免与逐张取消的
-- 技能互相覆盖；只拆分移动信息，不丢弃同批的其他牌。
skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  late_refresh = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag(FactionTricks.MOVE_TAG) == event.id then return false end
    return hasRedirect(data)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag(FactionTricks.MOVE_TAG) == event.id then return end
    room:setTag(FactionTricks.MOVE_TAG, event.id)

    local redirects = {}
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.DiscardPile then
        local kept, redirected = {}, {}
        for _, info in ipairs(move.moveInfo or {}) do
          if FactionTricks.isFactionTrick(realCardOf(info)) then
            table.insert(redirected, info)
          else
            table.insert(kept, info)
          end
        end
        if #redirected > 0 then
          move.moveInfo = kept
          -- 只替换目的地：保留原移动原因、技能名、执行者与移动标记，
          -- 使「弃置」「使用后置入」等既有触发按原动作成立，而弃牌堆相关
          -- 的到达触发不会被误触发。
          table.insert(redirects, {
            moveInfo = redirected,
            from = move.from,
            to = nil,
            toArea = Card.Void,
            moveReason = move.moveReason,
            proposer = move.proposer,
            skillName = move.skillName,
            moveVisible = move.moveVisible == nil and true or move.moveVisible,
            moveMark = move.moveMark,
          })
        end
      end
    end
    table.insertTable(data, redirects)
  end,
})

-- 公开明置武将牌：明置时因超员或专属野心家而成为野心家的，在此登记。
skill:addEffect(fk.GeneralRevealed, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and target.kingdom == "wild"
  end,
  on_refresh = function(self, event, target, player, data)
    notePublicWild(Fk:currentRoom(), target)
  end,
})

-- 公开势力变化（如游戏中公开转野）：只认公开属性 kingdom 变为 wild。
skill:addEffect(fk.AfterPropertyChange, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if data == nil or target == nil then return false end
    if data.kingdom ~= "wild" or target.kingdom ~= "wild" then return false end
    return true
  end,
  on_refresh = function(self, event, target, player, data)
    notePublicWild(Fk:currentRoom(), target)
  end,
})

Fk:loadTranslationTable {
  ["qiao__faction_trick_rule"] = "势力锦囊规则",
}

return skill
