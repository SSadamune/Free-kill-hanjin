-- HAN014 朱儁 · 虎翼
--
-- 阵法技，每回合限一次：与自己处于同一围攻关系的另一名围攻者对被围攻者使用
-- 【杀】后，自己可以对同一被围攻者使用一张真实【杀】。
local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_han014_2",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"

---@param player ServerPlayer
---@param use UseCardData
---@return ServerPlayer|nil
local function victimFor(player, use)
  if use == nil or use.from == nil then return nil end
  for _, to in ipairs(use.tos or {}) do
    if to:isAlive() and not to:isRemoved() and H.inSiegeRelation(player, use.from, to) then
      return to
    end
  end
  return nil
end

skill:addEffect(fk.CardUseFinished, {
  global = true,
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player.dead then return false end
    if data == nil or data.card == nil or data.card.trueName ~= "slash" then return false end
    return player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and victimFor(player, data) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han014_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local victim = victimFor(player, data)
    if victim == nil then return end
    local room = player.room
    local use = C.askToUseCard(room, player, {
      names = { SLASH },
      skill_name = skill.name,
      prompt = "#qiao__skill_han014_2-slash::" .. victim.id,
      cancelable = true,
    })
    if use == nil or #use.tos ~= 1 or use.tos[1] ~= victim then return end
    room:useCard(use)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_han014_2"] = "虎翼",
  [":qiao__skill_han014_2"] = "阵法技，每回合限一次，与你处于同一围攻关系的围攻角色对被围攻角色使用【杀】后，另一名围攻角色可以对被围攻角色使用一张【杀】。",
  ["#qiao__skill_han014_2-invoke"] = "虎翼：你可以对同一被围攻角色使用一张【杀】",
  ["#qiao__skill_han014_2-slash"] = "虎翼：对被围攻角色 %dest 使用一张【杀】",
}

return skill
