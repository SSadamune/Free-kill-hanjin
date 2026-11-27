-- JIN020 荀勖 · 应政
-- 与你势力相同的角色回合内限一次，当其使用应变牌后，其可以令你获得此牌，
-- 然后若此牌触发应变，你可以令其变更副将（限一次）。
local H = require "packages.hegemony.util"
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin020_1",
}
skill.qiaoImplemented = true

local function obtainIds(room, card)
  if card == nil then return {} end
  local ids = room:getSubcardsByRule(card, { Card.Processing })
  if #ids == 0 then
    ids = room:getSubcardsByRule(card, { Card.DiscardPile })
  end
  return ids
end

skill:addEffect(fk.CardUseFinished, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if target == nil or target ~= player.room.current then return false end
    if player.dead or player:isRemoved() or not player:hasSkill(skill.name) then return false end
    if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
    if not H.compareKingdomWith(target, player) then return false end
    if data == nil or not A.isAdaptationCard(data.card, data) then return false end
    return #obtainIds(player.room, data.card) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(target, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin020_1-invoke:" .. player.id .. "::" .. data.card:toLogString(),
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = obtainIds(room, data.card)
    if #ids == 0 then return end
    room:obtainCard(player, ids, true, fk.ReasonJustMove, target, skill.name)
    local obtained = table.find(ids, function(id)
      return room:getCardOwner(id) == player
    end) ~= nil
    if not obtained then return end

    local result = A.getResult(data)
    if result ~= nil and result.triggered == true
      and RemovedTargets.isPresent(player) and RemovedTargets.isPresent(target)
      and Change.canUseSkillChange(room, player, skill.name)
      and #Change.candidates(room, target, true) > 0 then
      if room:askToSkillInvoke(player, {
        skill_name = skill.name,
        prompt = "#qiao__skill_jin020_1-change::" .. target.id,
      }) then
        Change.performSkillChangeDeputy(room, target, player, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "应政",
  [":" .. skill.name] = "与你势力相同的角色回合内限一次，当其使用应变牌后，其可以令你获得此牌，然后若此牌触发应变，你可以令其变更副将（限一次）。",
  ["#qiao__skill_jin020_1-invoke"] = "应政：是否令 %src 获得 %arg",
  ["#qiao__skill_jin020_1-change"] = "应政：此牌触发了应变，是否令 %dest 变更副将",
}

return skill
