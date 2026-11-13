-- WEI006 郭嘉 · 遗计
--
-- 当你受到伤害后，你可以观看牌堆顶两张牌，将其中一至两张牌交给一名角色，
-- 然后将其余的牌交给一名角色。一次伤害事件只发动一次（不按伤害点数拆分）：
-- 第一次分配限定一至两张并选定一名角色；仍有剩余时，再把全部剩余牌交给
-- 由发动者选定的另一名角色，剩余为空则不进行第二次分配。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei006_2",
}
skill.hanjinImplemented = true

local function giveCards(room, player, ids, to)
  room:moveCardTo(ids, Card.PlayerHand, to, fk.ReasonGive, skill.name, nil, false, player)
end

skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei006_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:getNCards(2)
    if #ids == 0 then return end

    local tos, cards = room:askToChooseCardsAndPlayers(player, {
      min_num = 1,
      max_num = 1,
      min_card_num = 1,
      max_card_num = math.min(2, #ids),
      targets = room.alive_players,
      pattern = tostring(Exppattern { id = ids }),
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei006_2-give",
      cancelable = false,
      expand_pile = ids,
    })
    local first = tos and tos[1]
    if first == nil or #cards == 0 then
      -- 防御性回退：没有合法选择时由发动者收下全部牌，不丢牌。
      giveCards(room, player, ids, player)
      return
    end

    for _, id in ipairs(cards) do
      table.removeOne(ids, id)
    end
    giveCards(room, player, cards, first)
    if #ids == 0 or player.dead then return end

    local rest = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = room.alive_players,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei006_2-rest",
      cancelable = false,
    })
    local second = rest and rest[1] or player
    giveCards(room, player, ids, second)
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei006_2-invoke"] = "遗计：你可以观看牌堆顶两张牌并交给角色",
  ["#hanjin__skill_wei006_2-give"] = "遗计：选择一至两张牌和一名角色",
  ["#hanjin__skill_wei006_2-rest"] = "遗计：将其余的牌交给一名角色",
}

return skill
