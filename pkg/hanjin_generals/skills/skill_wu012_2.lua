-- WU012 太史慈 · 酣战
--
-- 你拼点后，可以获得拼点牌之中点数最大的【杀】。拼点结束时牌仍在处理区，
-- 这里在该时机取得；点数相同的最大【杀】有多张时由你选择一张。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu012_2",
}
skill.hanjinImplemented = true

--- 本次拼点中仍在处理区、点数最大的【杀】。
---@param data PindianData
---@param room Room
---@return integer[]
local function bestSlashCards(data, room)
  local cards = {}
  local best
  local function consider(card)
    if card == nil or card.trueName ~= "slash" then return end
    local id = card:getEffectiveId()
    if id == nil or room:getCardArea(id) ~= Card.Processing then return end
    if best == nil or card.number > best then
      best = card.number
      cards = { id }
    elseif card.number == best and not table.contains(cards, id) then
      table.insert(cards, id)
    end
  end

  consider(data.fromCard)
  for _, to in ipairs(data.tos or {}) do
    local result = data.results and data.results[to]
    consider(result and result.toCard)
  end
  return cards
end

skill:addEffect(fk.PindianFinished, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not player:hasSkill(skill.name) then return false end
    if data == nil then return false end
    if data.from ~= player and not table.contains(data.tos or {}, player) then return false end
    return #bestSlashCards(data, player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu012_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = bestSlashCards(data, room)
    if #ids == 0 then return end
    -- 原文没有“一张”限制：点数最大的【杀】若并列，全部取得。
    for _, id in ipairs(ids) do
      if room:getCardArea(id) == Card.Processing then
        room:obtainCard(player, id, true, fk.ReasonPrey, player, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu012_2"] = "酣战",
  [":hanjin__skill_wu012_2"] = "你拼点后，你可以获得拼点牌之中点数最大的【杀】。",
  ["#hanjin__skill_wu012_2-invoke"] = "酣战：你可以获得拼点牌中点数最大的【杀】",
}

return skill
