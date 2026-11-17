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
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin022b_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local id = room:askToChooseCard(player, {
      target = player,
      flag = "h",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin022b_2-card",
    })
    if id == nil or id == -1 or not table.contains(player:getCardIds("h"), id) then return end

    local candidates = U.farthestInRange(player)
    if #candidates == 0 then return end
    local to = candidates[1]
    if #candidates > 1 then
      local chosen = room:askToChoosePlayers(player, {
        targets = candidates,
        min_num = 1,
        max_num = 1,
        skill_name = skill.name,
        prompt = "#qiao__skill_jin022b_2-target",
      })
      to = chosen and chosen[1] or nil
    end
    if to == nil or to.dead or not player:inMyAttackRange(to) then return end

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
  ["#qiao__skill_jin022b_2-card"] = "勤边：选择一张手牌",
  ["#qiao__skill_jin022b_2-target"] = "勤边：选择攻击范围内距离最远的一名角色",
}

return skill
