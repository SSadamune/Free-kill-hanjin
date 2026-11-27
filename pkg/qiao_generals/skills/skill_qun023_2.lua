-- QUN023 张绣 · 附敌
-- 当你受到伤害后，你可以交给来源一张手牌，然后对其势力中体力值最大且大于等于你的一名角色造成1点伤害。
local H = require "packages.hegemony.util"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun023_2",
}
skill.qiaoImplemented = true

skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and RemovedTargets.isPresent(player) and player:hasSkill(skill.name)
      and data.from ~= nil and data.from ~= player and RemovedTargets.isPresent(data.from)
      and not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player, data)
    local cards = player.room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun023_2-invoke::" .. data.from.id,
      cancelable = true,
    })
    if type(cards) == "table" and #cards == 1 then
      event:setCostData(self, { cards = cards })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local cards = cost.cards
    local source = data.from
    if type(cards) ~= "table" or #cards ~= 1 or not table.contains(player:getCardIds("h"), cards[1]) then
      return
    end
    if source == nil or not RemovedTargets.isPresent(source) then return end
    room:obtainCard(source, cards, false, fk.ReasonGive, player, skill.name)

    if not RemovedTargets.isPresent(player) or source == nil then return end
    local sameKingdom = table.filter(room:getPresentPlayers(), function(p)
      return H.compareKingdomWith(p, source)
    end)
    if #sameKingdom == 0 then return end

    local maxHp
    for _, p in ipairs(sameKingdom) do
      if maxHp == nil or p.hp > maxHp then maxHp = p.hp end
    end
    if maxHp == nil or maxHp < player.hp then return end

    local candidates = table.filter(sameKingdom, function(p)
      return p.hp == maxHp
    end)
    if #candidates == 0 then return end

    local dest = candidates[1]
    if #candidates > 1 then
      local chosen = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 1,
        max_num = 1,
        skill_name = skill.name,
        prompt = "#qiao__skill_qun023_2-target",
        cancelable = false,
      })
      dest = (chosen and chosen[1]) or candidates[1]
    else
      room:doIndicate(player, { dest })
    end
    if RemovedTargets.isPresent(dest) then
      room:damage {
        from = player,
        to = dest,
        damage = 1,
        damageType = fk.NormalDamage,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "附敌",
  [":" .. skill.name] = "当你受到伤害后，你可以交给来源一张手牌，然后对其势力中体力值最大且大于等于你的一名角色造成1点伤害。",
  ["#qiao__skill_qun023_2-invoke"] = "附敌：你可以交给 %dest 一张手牌，对其势力体力最大且不小于你的一名角色造成1点伤害",
  ["#qiao__skill_qun023_2-target"] = "附敌：选择一名目标角色，对其造成1点伤害",
}

return skill
