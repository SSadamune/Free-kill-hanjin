-- QUN024 张任 · 穿心
-- 使用【杀】/【决斗】造成伤害时，若实际翼从数（含 shared）<2，可从可用
-- 翼从中随机亮出至多三种并选一张；目标副将位置有真实武将牌才可变更，
-- 否则本次伤害+1且张任永久获得该翼从。
local Transform = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_chuanxin"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local S = require "packages.qiao.pkg.qiao_generals.util.retinue_instance_sources"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun024_1",
}
skill.qiaoImplemented = true

local DAMAGE_CARDS = { slash = true, ["qiao__slash"] = true, duel = true, ["qiao__duel"] = true }

local function actualDeputy(target)
  local name = target.deputyGeneral
  if name == "anjiang" then name = target:getMark("__heg_deputy") end
  return type(name) == "string" and name ~= "" and name ~= "anjiang"
    and Fk.generals[name] ~= nil and not Commander.isSoldier(name)
end

local function candidatePool(player)
  local list = {}
  local used = Commander.usedLimitedRetinues(player.room)
  for general in pairs(Commander.retinues) do
    if not Commander.isLimitedRetinue(general) or used[general] == nil then
      table.insert(list, general)
    end
  end
  table.sort(list)
  return list
end

local function randomThree(player)
  local list = candidatePool(player)
  for i = #list, 2, -1 do
    local j = math.random(i)
    list[i], list[j] = list[j], list[i]
  end
  local result = {}
  for i = 1, math.min(3, #list) do table.insert(result, list[i]) end
  return result
end

local function grantToZhangRen(player, general)
  local skillName = S.skillFor(general)
  if skillName == nil then return end
  R.grant(player, {
    general = general,
    skill = skillName,
    origin = "granted",
  })
  if Commander.isLimitedRetinue(general) then
    local used=Commander.usedLimitedRetinues(player.room)
    used[general]={player=player.id,seat=player.seat}
    player.room:setTag(Commander.USED_RETINUE_TAG,used)
  end

end

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or data == nil or data.card == nil then
      return false
    end
    if not player:hasSkill(skill.name) then return false end
    if not DAMAGE_CARDS[data.card.trueName] then return false end
    if data.to == nil or data.to.dead then return false end
    return R.count(player) < 2 and #candidatePool(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    if not player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun024_1-invoke",
    }) then return false end
    local list = randomThree(player)
    if #list == 0 then return false end
    local chosen = player.room:askToChoice(player, {
      choices = list,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun024_1-choose",
      cancelable = true,
    })
    if chosen == nil or not table.contains(list, chosen) then return false end
    event:setCostData(self, { general = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    local general = cost.general
    if general == nil or data.to == nil then return end
    local victim = data.to
    local changed = false
    if actualDeputy(victim) then
      local choice = player.room:askToChoice(victim, {
        choices = { "change", "refuse" },
        skill_name = skill.name,
        prompt = "#qiao__skill_qun024_1-change",
        cancelable = false,
      })
      if choice == "change" then
        local ok = Transform.replaceDeputy(player.room, victim, general, skill.name)
        if ok then
          S.syncPlayer(victim)
          changed = true
        end
      end
    end
    if not changed then
      data.damage = (data.damage or 0) + 1
      grantToZhangRen(player, general)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun024_1"] = "穿心",
  ["#qiao__skill_qun024_1-invoke"] = "穿心：可亮出三种翼从并选择一张",
  ["#qiao__skill_qun024_1-choose"] = "穿心：选择一张翼从",
  ["#qiao__skill_qun024_1-change"] = "穿心：是否将副将变更为该翼从",
  ["change"] = "变更副将",
  ["refuse"] = "拒绝",
}

return skill
