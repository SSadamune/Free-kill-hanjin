-- WEI020 荀攸 · 智愚
-- 当你受到伤害后，你可以摸一张牌，展示所有手牌，若颜色均相同，来源弃置一张手牌。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei020_2",
}
skill.qiaoImplemented = true

skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wei020_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:drawCards(1, skill.name)
    if player.dead then return end
    local cards = player:getCardIds(Player.Hand)
    if #cards == 0 then return end
    player:showCards(cards)
    local firstColor = Fk:getCardById(cards[1]).color
    if firstColor == Card.NoColor then return end
    local allSame = table.every(cards, function(id)
      return Fk:getCardById(id).color == firstColor
    end)
    local from = data.from
    if allSame and from ~= nil and RemovedTargets.isPresent(from) and not from:isKongcheng() then
      room:askToDiscard(from, {
        min_num = 1,
        max_num = 1,
        include_equip = false,
        skill_name = skill.name,
        prompt = "#qiao__skill_wei020_2-discard",
        cancelable = false,
      })
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "智愚",
  [":" .. skill.name] = "当你受到伤害后，你可以摸一张牌，展示所有手牌，若颜色均相同，来源弃置一张手牌。",
  ["#qiao__skill_wei020_2-invoke"] = "智愚：是否摸一张牌并展示所有手牌",
  ["#qiao__skill_wei020_2-discard"] = "智愚：你须弃置一张手牌",
}

return skill
