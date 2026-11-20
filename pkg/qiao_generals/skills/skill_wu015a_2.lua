-- WU015A 张昭 · 固政
--
-- 规则基线：docs/rules/standard-generals.md 吴区 WU015A。
-- 每回合限一次：当其他角色至少两张牌因弃置置入弃牌堆后，可以将其中一张
-- 交给该角色，然后获得其余至多三张牌。只处理真实弃置与弃牌堆；牌若已被
-- 其他同时机效果取走，则不再作为可选候选。同一事件有多名其他角色满足时，
-- 由张昭选择对应的该名角色，不自动合并或挑数量最多者。
local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"
local skill = fk.CreateSkill {
  name = "qiao__skill_wu015a_2",
}
skill.qiaoImplemented = true

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 某次移动是否属于“其他角色因弃置置入弃牌堆”。
---@param player ServerPlayer
---@param move MoveCardsData
---@return boolean
local function isOtherDiscard(player, move)
  return move.moveReason == fk.ReasonDiscard
    and move.toArea == Card.DiscardPile
    and move.from ~= nil
    and move.from ~= player
end

--- 本事件中每名满足条件的其他角色各自的事件张数与仍在弃牌堆的牌。
--- 不把不同角色的牌合并成一组。
---@param player ServerPlayer
---@param data MoveCardsData[]
---@return { owner: ServerPlayer, total: integer, ids: integer[] }[]
local function discardEntries(player, data)
  local room = currentRoom(player)
  local byPlayer, entries = {}, {}
  for _, move in ipairs(data or {}) do
    if isOtherDiscard(player, move) then
      local owner = move.from
      local entry = byPlayer[owner.id]
      if entry == nil then
        entry = { owner = owner, total = 0, ids = {} }
        byPlayer[owner.id] = entry
      end
      for _, info in ipairs(move.moveInfo or {}) do
        entry.total = entry.total + 1
        if room:getCardArea(info.cardId) == Card.DiscardPile
          and not table.contains(entry.ids, info.cardId) then
          table.insert(entry.ids, info.cardId)
        end
      end
    end
  end
  for _, entry in pairs(byPlayer) do
    if entry.total >= 2 and #entry.ids > 0 and not entry.owner.dead and not entry.owner:isRemoved() then
      table.insert(entries, entry)
    end
  end
  table.sort(entries, function(a, b) return a.owner.id < b.owner.id end)
  return entries
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player.dead then return false end
    if player:usedEffectTimes(self.name, Player.HistoryTurn) > 0 then return false end
    return #discardEntries(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local entries = discardEntries(player, data)
    local chosen = Invoke.ask(room, player, {
      min_num = 1, max_num = 1,
      targets = table.map(entries, function(entry) return entry.owner end),
      skill_name = skill.name,
      prompt = "#qiao__skill_wu015a_2-owner",
      invoke_prompt = "#qiao__skill_wu015a_2-invoke",
    })
    if #chosen == 0 then return false end
    event:setCostData(self, { to = chosen[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local selected = event:getCostData(self).to
    local entry = table.find(discardEntries(player, data), function(candidate)
      return candidate.owner == selected
    end)
    if entry == nil then return end

    local owner = entry.owner
    local ids = entry.ids
    if owner.dead or owner:isRemoved() or #ids == 0 then return end

    local giveId = room:askToChooseCard(player, {
      target = player,
      flag = { card_data = { { "弃牌堆", ids } } },
      skill_name = skill.name,
      prompt = "#qiao__skill_wu015a_2-give",
    })
    if giveId == nil or not table.contains(ids, giveId)
      or room:getCardArea(giveId) ~= Card.DiscardPile then
      return
    end
    -- 交给原角色：一次移动一张。
    room:moveCardTo({ giveId }, Card.PlayerHand, owner, fk.ReasonGive,
      skill.name, nil, true, player)

    local remaining = table.filter(ids, function(id)
      return id ~= giveId and room:getCardArea(id) == Card.DiscardPile
    end)
    local maxGain = math.min(3, #remaining)
    if maxGain <= 0 then return end
    local gain = room:askToCustomDialog(player, {
      skill_name = skill.name,
      component = {
        url = "packages/qiao/pkg/qiao_mode/qml/GuzhengGainBox.qml",
        prop = { cards = remaining, maxGain = maxGain },
      },
    })
    if type(gain) ~= "table" or #gain > maxGain then return end
    local gainIds = {}
    for _, id in ipairs(gain) do
      if not table.contains(remaining, id) or table.contains(gainIds, id) then return end
      if room:getCardArea(id) == Card.DiscardPile then
        table.insert(gainIds, id)
      end
    end
    -- 其余牌一次批量移动，避免逐张移动产生多次触发/多个事件。
    if #gainIds > 0 then
      room:moveCardTo(gainIds, Card.PlayerHand, player, fk.ReasonPrey,
        skill.name, nil, true, player)
    end
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_wu015a_2-invoke"] = "固政：你可以将其中一张牌交给该角色，然后获得其余至多三张牌",
  ["#qiao__skill_wu015a_2-owner"] = "固政：选择本事件中要结算的一名其他角色",
  ["#qiao__skill_wu015a_2-give"] = "固政：选择交给该角色的一张牌",
  ["#qiao__skill_wu015a_2-gain"] = "固政：保留至多三张要获得的牌，点击可取消选中",
}

return skill
