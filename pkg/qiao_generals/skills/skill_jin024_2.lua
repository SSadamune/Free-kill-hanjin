-- JIN024 贾南风 · 废戮
-- 每名角色限一次，当一名角色进入濒死时，你可以令其选择一项：
-- 1.你移除其一个武将，其回复1点体力；
-- 2.你失去此技能，其死亡。
local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Duanchang = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local TriggerSelection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin024_2",
}
skill.qiaoImplemented = true

local OPT_REMOVE = "#qiao__skill_jin024_2-opt1"
local OPT_KILL = "#qiao__skill_jin024_2-opt2"

local function findSourceCard(room, player)
  for _, isDeputy in ipairs({ false, true }) do
    if Exchange.hasPosition(player, isDeputy) then
      local name = Exchange.actualGeneral(player, isDeputy)
      if type(name) == "string" and name ~= "" and name ~= "anjiang"
        and Exchange.cardProvidesSkill(room, name, skill.name) then
        return name, isDeputy
      end
    end
  end
  return nil, nil
end

local function sourceKey(room, player)
  local cardName = findSourceCard(room, player)
  return cardName or ("player:" .. tostring(player.id))
end

local function hasUsedOn(room, player, target)
  local record = room:getTag(Quan.FEILU_USED_TAG)
  local key = sourceKey(room, player)
  return type(record) == "table" and type(record[key]) == "table" and record[key][target.id] == true
end

local function markUsedOn(room, player, target)
  local record = table.simpleClone(room:getTag(Quan.FEILU_USED_TAG) or {})
  local key = sourceKey(room, player)
  record[key] = table.simpleClone(record[key] or {})
  record[key][target.id] = true
  room:setTag(Quan.FEILU_USED_TAG, record)
end

local function removablePositions(target)
  local items = {}
  if Quan.canRemoveOrdinaryPosition(target, false) then
    local label = Exchange.isRevealed(target, false) and target.general or "mainGeneral"
    table.insert(items, { isDeputy = false, label = label })
  end
  if Quan.canRemoveOrdinaryPosition(target, true) then
    local label = Exchange.isRevealed(target, true) and target.deputyGeneral or "deputyGeneral"
    table.insert(items, { isDeputy = true, label = label })
  end
  return items
end

skill:addEffect(fk.EnterDying, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target == data.who
      and RemovedTargets.isPresent(target)
      and RemovedTargets.isPresent(player)
      and player:hasSkill(skill.name)
      and not hasUsedOn(player.room, player, target)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin024_2-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(target) then return end
    markUsedOn(room, player, target)

    local removable = removablePositions(target)
    local allOpts = { OPT_REMOVE, OPT_KILL }
    local availOpts = #removable > 0 and { OPT_REMOVE, OPT_KILL } or { OPT_KILL }
    local pick = TriggerSelection.askOption(room, target, {
      choices = availOpts,
      all_choices = allOpts,
      cancelable = false,
      buttons = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin024_2-choice:" .. player.id,
    })
    if pick ~= OPT_REMOVE and pick ~= OPT_KILL then
      pick = availOpts[1]
    end

    if pick == OPT_REMOVE and #removable > 0 then
      local chosen = removable[1]
      if #removable > 1 then
        local choices = table.map(removable, function(item) return item.label end)
        local selected = room:askToChoice(player, {
          choices = choices,
          skill_name = skill.name,
          prompt = "#qiao__skill_jin024_2-remove::" .. target.id,
          cancelable = false,
        })
        for _, item in ipairs(removable) do
          if item.label == selected then chosen = item; break end
        end
      end
      H.removeGeneral(target, chosen.isDeputy)
      if RemovedTargets.isPresent(target) and target:isWounded() then
        room:recover {
          who = target,
          num = 1,
          recoverBy = player,
          skillName = skill.name,
        }
      end
      return
    end

    -- 选项 2：贾南风失去【废戮】（按失去技能状态归属记在该武将牌上），目标无伤害来源直接死亡。
    local cardName, isDeputy = findSourceCard(room, player)
    if cardName ~= nil then
      Duanchang.loseCardSkill(room, player, isDeputy, skill.name)
    elseif player:hasSkill(skill.name, true, true) then
      room:handleAddLoseSkills(player, "-" .. skill.name, nil, true, false)
    end
    if not target.dead then
      room:killPlayer { who = target }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "废戮",
  [":" .. skill.name] = "每名角色限一次，当一名角色进入濒死时，你可以令其选择一项：1.你移除其一个武将，其回复1点体力；2.你失去此技能，其死亡。",
  ["#qiao__skill_jin024_2-invoke"] = "废戮：是否令濒死的 %dest 选择移除武将回血或直接死亡？",
  ["#qiao__skill_jin024_2-choice"] = "废戮：请选择一项（由 %src 发动）",
  ["#qiao__skill_jin024_2-remove"] = "废戮：选择移除 %dest 的一张武将牌",
  [OPT_REMOVE] = "令其移除你一个武将，你回复1点体力",
  [OPT_KILL] = "令其失去【废戮】，你死亡",
}

return skill
