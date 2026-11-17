-- JIN008 夏侯徽 · 宜室
--
-- 规则基线：rules/generals/jin008-xiahouhui.md。
-- 每回合限一次：与夏侯徽势力相同的角色作为弃置操作者（proposer，不是牌的原
-- 拥有者 from）弃置任意角色的牌后，从本批仍在弃牌堆的牌中选一张交给该操作者，
-- 然后从剩余牌中再获得一张。只取一张，不收取全部剩余；只有一张时不获得第二张。
-- 已被其他同时机效果移走的牌不再从新区域强取，第一步合法执行后不因第二步
-- 无法执行而倒推取消。
local B = require "packages.qiao.pkg.qiao_generals.util.jin_basic"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin008_1",
}

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 按弃置操作者和事件分批收集仍在弃牌堆的牌。
---@param player ServerPlayer
---@param data MoveCardsData[]
---@return { proposer: ServerPlayer, ids: integer[] }[]
local function discardEntries(player, data)
  local room = currentRoom(player)
  local byProposer, entries = {}, {}
  for _, move in ipairs(data or {}) do
    local proposer = move.proposer
    if move.moveReason == fk.ReasonDiscard
      and move.toArea == Card.DiscardPile
      and proposer ~= nil and not proposer.dead
      and B.sameKingdom(proposer, player) then
      local entry = byProposer[proposer.id]
      if entry == nil then
        entry = { proposer = proposer, ids = {} }
        byProposer[proposer.id] = entry
      end
      for _, info in ipairs(move.moveInfo or {}) do
        if room:getCardArea(info.cardId) == Card.DiscardPile
          and not table.contains(entry.ids, info.cardId) then
          table.insert(entry.ids, info.cardId)
        end
      end
    end
  end
  for _, entry in pairs(byProposer) do
    if #entry.ids > 0 then table.insert(entries, entry) end
  end
  table.sort(entries, function(a, b) return a.proposer.id < b.proposer.id end)
  return entries
end

--- 从候选弃牌堆牌中选牌。
---@return integer[]
local function chooseFromDiscard(room, player, ids, count, prompt)
  if #ids == 0 or count < 1 then return {} end
  return room:askToChooseCards(player, {
    target = player,
    flag = { card_data = { { "弃牌堆", ids } } },
    min = count,
    max = math.min(count, #ids),
    skill_name = skill.name,
    prompt = prompt,
    cancelable = false,
  }) or {}
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not player:hasSkill(skill.name) then return false end
    if player:usedEffectTimes(self.name, Player.HistoryTurn) > 0 then return false end
    return #discardEntries(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin008_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local entries = discardEntries(player, data)
    if #entries == 0 then return end

    local entry = entries[1]
    if #entries > 1 then
      local owners = table.map(entries, function(e) return e.proposer end)
      local chosen = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = owners,
        skill_name = skill.name,
        prompt = "#qiao__skill_jin008_1-owner",
        cancelable = false,
      })
      local proposer = chosen and chosen[1]
      if proposer == nil then return end
      for _, e in ipairs(entries) do
        if e.proposer == proposer then entry = e break end
      end
    end

    local proposer = entry.proposer
    local ids = entry.ids
    if proposer.dead or #ids == 0 then return end

    local give = chooseFromDiscard(room, player, ids, 1,
      "#qiao__skill_jin008_1-give")
    local giveId = give[1]
    if giveId == nil or not table.contains(ids, giveId)
      or room:getCardArea(giveId) ~= Card.DiscardPile then
      return
    end
    room:moveCardTo({ giveId }, Card.PlayerHand, proposer, fk.ReasonGive,
      skill.name, nil, true, player)

    local remaining = table.filter(ids, function(id)
      return id ~= giveId and room:getCardArea(id) == Card.DiscardPile
    end)
    if #remaining == 0 then return end
    local gain = chooseFromDiscard(room, player, remaining, 1,
      "#qiao__skill_jin008_1-gain")
    local gainId = gain[1]
    if gainId ~= nil and table.contains(remaining, gainId)
      and room:getCardArea(gainId) == Card.DiscardPile then
      room:moveCardTo({ gainId }, Card.PlayerHand, player, fk.ReasonPrey,
        skill.name, nil, true, player)
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin008_1-invoke"] = "宜室：你可以将其中一张交给该弃置者，然后获得其余一张",
  ["#qiao__skill_jin008_1-owner"] = "宜室：选择本事件中要结算的弃置者",
  ["#qiao__skill_jin008_1-give"] = "宜室：选择交给其的一张牌",
  ["#qiao__skill_jin008_1-gain"] = "宜室：选择获得的其余一张牌",
}

return skill
