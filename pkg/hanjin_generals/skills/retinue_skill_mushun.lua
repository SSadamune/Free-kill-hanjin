-- HAN 翼从 · 穆顺
--
-- 规则基线：rules/standard-generals.md 翼从穆顺、rulebook/events/move-card.md、
-- rulebook/terms/card-op-terms/discard.md。每回合限一次：自己弃置任意角色的
-- 牌，或被其他角色弃置牌后，可以获得其中一张；取得后才建立本回合下一次
-- 同条件弃牌事件失去1点体力。重铸/给牌不是弃置，不触发。
--
-- 下一次失血是已建立的延迟效果：房间级监听器只看角色身上的罚标记，不要求
-- 穆顺当前仍拥有技能。是否“发生弃置”与牌是否仍在弃牌堆分别判断：即使该次
-- 弃置的牌已被同优先级技能取走，只要发生了符合条件的弃置事件，仍须失血。
local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_mushun",
}
skill.hanjinImplemented = true

-- 取得次数以技能名开头，Exchange 按来源武将迁移。
local USED_MARK = "hanjin__retinue_skill_mushun-used-turn"
-- 罚标记附在角色身上，不能随翼从来源迁移；不带技能名前缀。
local PUNISH_MARK = "hanjin_mushun_punish-turn"
local DELAY_SKILL_NAME = "#hanjin_retinue_skill_mushun_delay"

local delay_skill

---@param player ServerPlayer
---@param move MoveCardsData
---@return boolean
local function qualifies(player, move)
  if move.moveReason ~= fk.ReasonDiscard or move.toArea ~= Card.DiscardPile then
    return false
  end
  return move.proposer == player
    or (move.from == player and move.proposer ~= nil and move.proposer ~= player)
end

--- 事件中符合条件的弃置（只判断事件，不要求牌还在弃牌堆）。
---@param player ServerPlayer
---@param data MoveCardsData[]
---@return boolean
local function hasQualifyingDiscard(player, data)
  for _, move in ipairs(data or {}) do
    if qualifies(player, move) then return true end
  end
  return false
end

--- 仍实际留在弃牌堆、可被取得的候选牌。
---@param player ServerPlayer
---@param data MoveCardsData[]
---@return integer[]
local function eligibleCards(player, data)
  local room = player.room
  local ids = {}
  for _, move in ipairs(data or {}) do
    if qualifies(player, move) then
      for _, info in ipairs(move.moveInfo or {}) do
        if room:getCardArea(info.cardId) == Card.DiscardPile
          and not table.contains(ids, info.cardId) then
          table.insert(ids, info.cardId)
        end
      end
    end
  end
  return ids
end

--- 安装/复用房间级“下一次弃牌失血”监听器。
---@param room Room
local function ensureDelaySkill(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }
    skel:addEffect(fk.AfterCardsMove, {
      global = true,
      can_trigger = function(self, event, target, player, data)
        if data.__mushun_punish_done then return false end
        local room = player.room
        for _, p in ipairs(room.players) do
          if p:getMark(PUNISH_MARK) > 0
            and not (data.__mushun_suppress and data.__mushun_suppress[p.id])
            and hasQualifyingDiscard(p, data) then
            return true
          end
        end
        return false
      end,
      on_cost = Util.TrueFunc,
      on_use = function(self, event, target, player, data)
        local room = player.room
        data.__mushun_punish_done = true
        for _, p in ipairs(room.players) do
          if p:getMark(PUNISH_MARK) > 0
            and not (data.__mushun_suppress and data.__mushun_suppress[p.id])
            and hasQualifyingDiscard(p, data) then
            room:setPlayerMark(p, PUNISH_MARK, 0)
            if not p.dead then
              room:loseHp(p, 1, skill.name)
            end
          end
        end
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY_SKILL_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_SKILL_NAME) then
    room:addSkill(delay_skill)
  end
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead
      and player:getMark(USED_MARK) == 0
      and #eligibleCards(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_mushun-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player:getMark(USED_MARK) > 0 then return end
    local ids = eligibleCards(player, data)
    if #ids == 0 then return end
    local chosen = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_mushun-choose",
      cancelable = true,
      expand_pile = ids,
    })
    local id = chosen and chosen[1]
    if id == nil or not table.contains(ids, id)
      or room:getCardArea(id) ~= Card.DiscardPile then
      return
    end
    room:obtainCard(player, id, true, fk.ReasonPrey, player, skill.name)
    ensureDelaySkill(room)
    room:setPlayerMark(player, USED_MARK, 1)
    room:setPlayerMark(player, PUNISH_MARK, 1)
    -- 同一次取得事件不触发刚建立的罚效果。
    data.__mushun_suppress = data.__mushun_suppress or {}
    data.__mushun_suppress[player.id] = true
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelaySkill(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_mushun"] = "穆顺",
  [":hanjin__retinue_skill_mushun"] = "每回合限一次，当你弃置任意角色的牌或被其他角色弃置牌后，你可以获得其中一张。若如此做，本回合你下次弃置任意角色的牌或被其他角色弃置牌后，你失去1点体力。",
  ["#hanjin__retinue_skill_mushun-invoke"] = "穆顺：你可以获得其中一张弃置的牌",
  ["#hanjin__retinue_skill_mushun-choose"] = "穆顺：选择获得其中一张",
}

return skill
