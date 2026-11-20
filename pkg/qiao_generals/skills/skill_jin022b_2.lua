-- JIN022B 牵弘 · 勤边
-- 结束阶段：将一张手牌当【逐近弃远】〈助战→执行两项〉对攻击范围内
-- 距离最远的一名其他角色使用；并列最远时由使用者选择其一。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin022b_2",
}
skill.qiaoImplemented = true

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasShownSkill(skill.name)
      and target.phase == Player.Finish
      and #player:getCardIds("h") > 0
      and #U.farthestInRange(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local candidates = U.farthestInRange(player)
    local to, id
    if #candidates == 1 then
      to = candidates[1]
      id = room:askToCards(player, {
        min_num = 1, max_num = 1, cancelable = true,
        skill_name = skill.name, prompt = "#qiao__skill_jin022b_2-invoke",
      })[1]
    else
      local targets, cards = room:askToChooseCardsAndPlayers(player, {
        targets = candidates,
        min_card_num = 1, max_card_num = 1,
        min_num = 1, max_num = 1,
        pattern = ".|.|.|hand",
        skill_name = skill.name, prompt = "#qiao__skill_jin022b_2-invoke",
        cancelable = true,
      })
      to, id = targets and targets[1], cards and cards[1]
    end
    if not table.contains(candidates, to) or not table.contains(player:getCardIds("h"), id) then
      return false
    end
    event:setCostData(self, { tos = { to }, cards = { id } })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local to, id = cost.tos[1], cost.cards[1]
    if not table.contains(U.farthestInRange(player), to)
      or not table.contains(player:getCardIds("h"), id) then return end
    local card = Fk:cloneCard("qiao__chasing_near")
    if card == nil then return end
    card.skillName = skill.name
    card:addSubcards({ id })
    local use = {
      from = player,
      tos = { to },
      card = card,
      extra_data = {},
    }
    A.addEntry(use, {
      id = "qiao__skill_jin022b_2_support",
      condition = "zhuzhan",
      effect = "execute_both",
    })
    C.useCard(room, player, use, C.default())
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin022b_2"] = "勤边",
  ["#qiao__skill_jin022b_2-invoke"] = "勤边：结束阶段，将一张手牌当【逐近弃远】对攻击范围内最远角色使用",
}

return skill
