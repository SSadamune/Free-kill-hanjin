local H = require "packages.hegemony.util"
local skill = fk.CreateSkill {
  name = "qiao__peace_spell_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__peace_spell",
}

skill:addEffect(fk.DetermineDamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.damageType ~= fk.NormalDamage
  end,
  on_use = function(self, event, target, player, data)
    data:preventDamage()
  end,
})

skill:addEffect("maxcards", {
  correct_func = function(self, player)
    if player:hasSkill(self.name) then
      if player.kingdom == "unknown" then return 1 end
      -- 公共人数口径已含装备者自己；群势力的天兵人数也由该口径修正。
      return H.getSameKingdomPlayersNum(Fk:currentRoom(), player) or 0
    end
  end,
})


-- 原版银狮结构：等移动真正完成后，在 AfterCardsMove 统一处理失去此防具。
skill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not Fk.skills[skill.name]:isEffectable(player) then
      return false
    end
    for _, move in ipairs(data or {}) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = info.beforeCard or Fk:getCardById(info.cardId)
          if info.fromArea == Card.PlayerEquip and card ~= nil
            and card.name == skill.attached_equip then
            return true
          end
        end
      end
    end
    return false
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    player:drawCards(2, skill.name)
    if player.hp > 1 and player:isAlive() then
      room:loseHp(player, 1, skill.name)
    end
  end,
})Fk:loadTranslationTable {
  ["qiao__peace_spell_skill"] = "太平要术",
  [":qiao__peace_spell_skill"] = "锁定技，防止你受到属性伤害；你的手牌上限+X"
    .. "（X为与你势力相同的角色数）。当你失去装备区里的此牌后，"
    .. "你摸两张牌，然后若你的体力值大于1，你失去1点体力。",
}

return skill
