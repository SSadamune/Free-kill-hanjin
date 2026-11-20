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

local function grantToZhangRen(player, general)
  local skillName = S.skillFor(general)
  if skillName == nil then return end
  R.grant(player, {
    general = general,
    skill = skillName,
    origin = "granted",
  })
end

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or data == nil or data.card == nil then
      return false
    end
    if not player:hasSkill(skill.name) then return false end
    if not DAMAGE_CARDS[data.card.trueName] then return false end
    if data.to == nil or data.to.dead then return false end
    return R.count(player) < 2 and #Commander.randomRetinueCandidates(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    if not player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun024_1-invoke",
    }) then return false end
    local room = player.room
    local candidates = Commander.randomRetinueCandidates(room)
    if #candidates == 0 then return false end
    local list = room:tableRandomPick(candidates, math.min(3, #candidates))
    room:sendLog {
      type = "#QiaoChuanxinReveal" .. #list, from = player.id,
      arg = list[1], arg2 = list[2], arg3 = list[3],
    }
    local chosen = player.room:askToChoice(player, {
      choices = list,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun024_1-choose",
      cancelable = true,
    })
    if not table.contains(list, chosen) or not table.contains(Commander.randomRetinueCandidates(room), chosen) then
      return false
    end
    room:sendLog { type = "#QiaoChuanxinChosen", from = player.id, arg = chosen }
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
  ["#QiaoChuanxinReveal1"] = "%from 亮出了翼从 %arg",
  ["#QiaoChuanxinReveal2"] = "%from 亮出了翼从 %arg、%arg2",
  ["#QiaoChuanxinReveal3"] = "%from 亮出了翼从 %arg、%arg2、%arg3",
  ["#QiaoChuanxinChosen"] = "%from 选择了翼从 %arg",
  ["change"] = "变更副将",
  ["refuse"] = "拒绝",
}

return skill
