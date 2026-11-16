-- 八阵兵：轮次技，一名角色的出牌阶段开始时，可视为使用【调虎离山】。
-- 目标由 C.selectVirtualCard 正常选择 1-2 名其他角色；出牌阶段角色不必须
-- 成为目标，但其在本次 use 结算中获得临时“杀当无懈可击”的 viewAs。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_bazhenbing",
}
skill.hanjinImplemented = true

local LURE = "hanjin__lure_tiger"
local TEMP = "hanjin__retinue_skill_bazhenbing_viewas"
local TEMP_MARK = "@@hanjin_bazhen_viewas"
local ROUND = "hanjin__retinue_skill_bazhenbing-round"

local function roundMark(room)
  return (room:getBanner("RoundCount") or 0) + 1
end

local function canTriggerInstance(instance, room)
  return instance == nil or instance.bazhen_round ~= roundMark(room)
end

skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or player == nil or player.dead
      or not player:hasSkill(skill.name) or data == nil
      or data.phase ~= Player.Play or target.dead or target:isRemoved() then
      return false
    end
    local instances = R.instancesForSkill(player, skill.name)
    if #instances == 0 then
      return player:getMark(ROUND) ~= roundMark(player.room)
    end
    for _, instance in ipairs(instances) do
      if canTriggerInstance(instance, player.room) then return true end
    end
    return false
  end,
  on_trigger = function(self, event, target, player, data)
    if #R.instancesForSkill(player, skill.name) == 0 then
      return self:doCost(event, target, player, data)
    end
    return R.triggerEach(self, event, target, player, data, function(instance)
      return canTriggerInstance(instance, player.room)
    end)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local instance = R.currentForEvent(self, event)
    if instance ~= nil and not canTriggerInstance(instance, room) then return false end
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_bazhenbing-invoke::" .. target.id,
    }) then return false end
    -- 正常选择 1-2 名其他角色；不强制把出牌阶段角色作为目标。
    local use = C.selectVirtualCard(room, player, {
      name = LURE,
      skill_name = skill.name,
      policy = C.default(),
      prompt = "#hanjin__retinue_skill_bazhenbing-target",
      cancelable = true,
    })
    if use == nil or #use.tos == 0 or #use.tos > 2 then return false end
    event:setCostData(self, { use = use, phase = target, instance = instance })
    if instance ~= nil then
      instance.bazhen_round = roundMark(room)
      R.recordUse(instance)
    else
      room:setPlayerMark(player, ROUND, roundMark(room))
    end
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    local use, phase = cost.use, cost.phase
    if use == nil or phase == nil or phase.dead then return end
    local room = player.room
    room:setPlayerMark(phase, TEMP_MARK, 1)
    room:handleAddLoseSkills(phase, TEMP, skill.name, false, true)
    local ok, err = pcall(C.useCard, room, player, use)
    room:handleAddLoseSkills(phase, "-" .. TEMP, skill.name, false, true)
    room:setPlayerMark(phase, TEMP_MARK, 0)
    if not ok then error(err, 0) end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_bazhenbing"] = "八阵兵",
  [":hanjin__retinue_skill_bazhenbing"] = "轮次技，一名角色的出牌阶段开始时，你可以视为使用【调虎离山】，此牌结算中其可以将【杀】当【无懈可击】使用。",
  ["#hanjin__retinue_skill_bazhenbing-invoke"] = "八阵兵：是否视为使用【调虎离山】？",
  ["#hanjin__retinue_skill_bazhenbing-target"] = "八阵兵：选择一至两名其他角色",
}

return skill
