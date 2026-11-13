-- WEI014 曹丕 · 行殇
--
-- 其他角色死亡时，你可以获得其所有牌；若其没有牌，则改为回复1点体力。
-- 时机为 fk.Death（弃置其牌之前）。“某人的牌”依 rules/general-principles.md
-- 仅指手牌区与装备区的牌，不含判定区；因此只有判定区有牌的死亡角色视为没有牌，
-- 改为回复1点体力，其判定区牌不因本技能移动。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei014_1",
}
skill.hanjinImplemented = true

local function ownCards(who)
  return who:getCardIds("he")
end

skill:addEffect(fk.Death, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if target == player or not player:hasSkill(skill.name) then return false end
    local who = data.who or target
    if who == nil or who == player then return false end
    return #ownCards(who) > 0 or player.hp < player.maxHp
  end,
  on_cost = function(self, event, target, player, data)
    local who = data.who or target
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei014_1-invoke:" .. who.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local who = data.who or target
    if who == nil then return end
    local ids = ownCards(who)
    if #ids > 0 then
      room:obtainCard(player, ids, true, fk.ReasonPrey, player, skill.name)
    elseif player.hp < player.maxHp then
      room:recover {
        who = player,
        num = 1,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei014_1-invoke"] = "行殇：获得 %src 的手牌和装备牌，若其没有牌则回复1点体力",
}

return skill
