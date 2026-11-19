-- SHU019 马岱 · 潜袭
--
-- 准备阶段摸一张、弃置一张，然后令一名距离1的角色本回合不能使用或打出
-- 被弃置颜色的手牌。限制由独立静态技能读取手牌材料颜色，不只看转化后的
-- 牌面颜色；成功建立后不因马岱失去潜袭或暗置而撤销。
local Q = require "packages.qiao.pkg.qiao_generals.util.shu019_qianxi"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu019_2",
}
skill.qiaoImplemented = true

--- 距离1的其他存活角色；正常距离0不能选择自己。
---@param player ServerPlayer
---@return ServerPlayer[]
local function candidates(player)
  return table.filter(player.room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
      and player:distanceTo(p) == 1
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    -- 先摸/弃，再按弃牌后的距离选目标；不能以当前已有距离1目标为门槛。
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu019_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    player:drawCards(1, skill.name)
    if player.dead then return end

    -- 只选择不弃置，先按弃置时持有者的锁定视为（如红颜）保存颜色，再实际弃牌。
    -- 牌离开原区域后 Fk:getCardById 可能恢复原牌颜色，不能在离区后取色。
    local discarded = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu019_2-discard",
      cancelable = false,
      skip = true,
    })
    local id = discarded and discarded[1]
    if id == nil or not table.contains(player:getCardIds("he"), id) then return end
    room:filterCard(id, player)
    local card = Fk:getCardById(id)
    local color = card and card.color or nil
    room:throwCard({ id }, skill.name, player, player)
    if color ~= Card.Red and color ~= Card.Black then return end

    local targets = candidates(player)
    if #targets == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu019_2-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return end

    Q.ensureRule(room)
    Q.addRestriction(room, to, player, color)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu019_2"] = "潜袭",
  [":qiao__skill_shu019_2"] = "准备阶段，你可以摸一张牌，弃置一张牌，令一名距离1的角色本回合不能使用或打出你弃置颜色的手牌。",
  ["#qiao__skill_shu019_2-invoke"] = "潜袭：你可以摸一张牌并弃置一张牌",
  ["#qiao__skill_shu019_2-discard"] = "潜袭：弃置一张牌",
  ["#qiao__skill_shu019_2-target"] = "潜袭：选择一名距离1的角色",
}

return skill
