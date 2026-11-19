-- JIN005 羊祜 · 顺流
--
-- 规则基线：docs/rules/generals/jin005-yanghu.md（含 2026-11-15 用户裁定）。
-- 副将技；体力贡献 -1 已由 data/standard.lua 的 deputyHpAdjust 提供，本技能
-- 不另发标记。造成属性伤害后，先弃受伤角色一张，再弃所有当时横置角色各一张：
-- 受伤者通常已在 ChangeHp 的连环重置中解除横置，但若仍横置，后一部分仍会再次
-- 纳入，不做全局去重。读取当前横置状态，不使用伤害前快照，也不使用
-- DamageFinished 时机。弃牌由羊祜选择，目标只提供自己的牌。
local J = require "packages.qiao.pkg.qiao_generals.util.jin_chain"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin005_2",
  tags = { Skill.DeputyPlace },
}
skill.qiaoImplemented = true

--- 羊祜从一名角色手牌或装备区选择一张可弃置的牌弃置。
---@param room Room
---@param player ServerPlayer @ 羊祜
---@param target ServerPlayer
local function discardOne(room, player, target)
  if target == nil or target.dead or target:isRemoved() then return end
  local ids = table.filter(target:getCardIds("he"), function(id)
    return not target:prohibitDiscard(id)
  end)
  if #ids == 0 then return end
  local id = room:askToChooseCard(player, {
    target = target,
    flag = "he",
    skill_name = skill.name,
    prompt = "#qiao__skill_jin005_2-discard:" .. target.id,
  })
  if id == nil or id == -1 or not table.contains(ids, id) then return end
  room:throwCard({ id }, skill.name, target, player)
end

skill:addEffect(fk.Damage, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.from == player
      and J.isAttributeDamage(data.damageType)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin005_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- “所有当时横置的角色”以造成伤害后、第一次弃牌前的状态为准；先固定名单，
    -- 再先弃受伤角色、后弃名单中的每名横置角色。受伤者若仍在名单中，不做去重。
    local chained = J.chainedAlivePlayers(room)
    room:sortByAction(chained)
    discardOne(room, player, data.to)
    for _, p in ipairs(chained) do
      discardOne(room, player, p)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin005_2"] = "顺流",
  [":qiao__skill_jin005_2"] = "副将技（☯️-1），当你造成属性伤害后，你可以依次弃置受伤角色和所有横置的角色各一张牌。",
  ["#qiao__skill_jin005_2-invoke"] = "顺流：你可以依次弃置受伤角色和所有横置角色各一张牌",
  ["#qiao__skill_jin005_2-discard"] = "顺流：选择 %dest 的一张牌弃置",
}

return skill
