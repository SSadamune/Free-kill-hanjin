-- EM(QUN010) 张角 · 问道
-- 出牌阶段限一次：弃自己一张红色牌，获得弃牌堆或场上的【太平要术】。
local PEACE = "hanjin__peace_spell"

local skill = fk.CreateSkill {
  name = "hanjin__skill_em_qun010_3",
}
skill.hanjinImplemented = true

local function findPeace(room)
  if room == nil then return nil end
  -- 只查弃牌堆和公开场区（装备区、判定区）；不查牌堆、手牌或暗置手牌。
  for _, id in ipairs(room.discard_pile or {}) do
    if Fk:getCardById(id) ~= nil and Fk:getCardById(id).name == PEACE then return id end
  end
  for _, player in ipairs(room.alive_players) do
    for _, area in ipairs({ Player.Equip, Player.Judge }) do
      for _, id in ipairs(player:getCardIds(area)) do
        local card = Fk:getCardById(id)
        if card ~= nil and card.name == PEACE then return id end
      end
    end
  end
  return nil
end

local function redCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.color == Card.Red and not player:prohibitDiscard(card)
  end)
end

skill:addEffect("active", {
  prompt = "#hanjin__skill_em_qun010_3-prompt",
  target_num = 0,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player.phase == Player.Play and not player.dead
      and #redCards(player) > 0 and findPeace(player.room or Fk:currentRoom()) ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    local peace = findPeace(room)
    if peace == nil or #redCards(player) == 0 then return end
    local ids = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = ".|.|red",
      skill_name = skill.name,
      prompt = "#hanjin__skill_em_qun010_3-discard",
      cancelable = false,
    })
    if ids == nil or #ids ~= 1 then return end
    peace = findPeace(room)
    if peace == nil then return end
    room:obtainCard(player, peace, true, fk.ReasonPrey, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_em_qun010_3"] = "问道",
  [":hanjin__skill_em_qun010_3"] = "出牌阶段限一次，你可以弃置一张红色牌，然后获得弃牌堆或场上的【太平要术】。",
  ["#hanjin__skill_em_qun010_3-prompt"] = "问道：弃置一张红色牌，获得【太平要术】",
  ["#hanjin__skill_em_qun010_3-discard"] = "问道：弃置一张红色牌",
}

return skill
