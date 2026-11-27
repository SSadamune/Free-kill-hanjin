-- WEI021B 毛玠 · 奉迎
-- 限定技，你可以将所有手牌当【挟天子以令诸侯】使用（无视大势力限制），
-- 使用时所有与你势力相同的角色摸牌至其体力上限。
local H = require "packages.hegemony.util"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei021b_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

skill:addEffect("viewas", {
  anim_type = "support",
  prompt = "#qiao__skill_wei021b_2-prompt",
  pattern = "qiao__threaten_emperor",
  card_filter = Util.FalseFunc,
  view_as = function(self, player, cards)
    local hand = player:getCardIds(Player.Hand)
    if #hand == 0 then return nil end
    local card = Fk:cloneCard("qiao__threaten_emperor")
    card.skillName = skill.name
    card:addSubcards(hand)
    return card
  end,
  enabled_at_play = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryGame) > 0 then return false end
    local card = self:viewAs(player, {})
    return card ~= nil and player:canUse(card)
  end,
  enabled_at_response = Util.FalseFunc,
})

-- 使用时（无懈可击响应前）所有与毛玠势力相同的在场角色按座次摸牌至其体力上限。
skill:addEffect(fk.CardUsing, {
  is_delay_effect = true,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and data.card ~= nil and data.card.skillName == skill.name
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local allies = table.filter(room:getPresentPlayers(), function(p)
      return H.compareKingdomWith(p, player)
    end)
    room:sortByAction(allies)
    for _, ally in ipairs(allies) do
      if RemovedTargets.isPresent(ally) and ally:getHandcardNum() < ally.maxHp then
        ally:drawCards(ally.maxHp - ally:getHandcardNum(), skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "奉迎",
  [":" .. skill.name] = "限定技，你可以将所有手牌当【挟天子以令诸侯】使用（无视大势力限制），使用时所有与你势力相同的角色摸牌至其体力上限。",
  ["#qiao__skill_wei021b_2-prompt"] = "奉迎：将所有手牌当【挟天子以令诸侯】使用（无视大势力限制）",
}

return skill
