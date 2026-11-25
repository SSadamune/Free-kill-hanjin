-- HAN024 灵雎 · 焚心
-- 当你杀死角色后，你可以变更副将，此次变更额外获得三张其副将牌面势力的备选武将牌。
-- 依定稿规则：每技能来源每局限一次变更；常规 3 候选按公共变更规则，额外 3 候选按死者副将牌面势力检索。
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local skill = fk.CreateSkill {
  name = "qiao__skill_han024_2",
}
skill.qiaoImplemented = true

local function victimDeputyPrintedKingdoms(victim)
  if victim == nil then return {} end
  local deputy = Exchange.actualGeneral(victim, true)
  if type(deputy) ~= "string" or deputy == "" or Exchange.isSoldier(deputy) then return {} end
  local general = Fk.generals[deputy]
  if general == nil or general.kingdom == "wild" then return {} end
  return Ban.affiliations(general)
end

skill:addEffect(fk.Deathed, {
  anim_type = "special",
  can_trigger = function(self, event, target, player, data)
    if target == nil or target == player or data == nil or data.killer ~= player then return false end
    if player.dead or player:isRemoved() or not player:hasSkill(skill.name) then return false end
    local room = player.room
    if not Change.canUseSkillChange(room, player, skill.name) then return false end
    if #Change.candidates(room, player, true) > 0 then return true end
    local extra = victimDeputyPrintedKingdoms(target)
    return #extra > 0 and #Change.candidates(room, player, true, { kingdoms = extra }) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han024_2-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local extra = victimDeputyPrintedKingdoms(target)
    Change.performSkillChangeDeputy(room, player, player, skill.name, {
      num = 3,
      extra_kingdoms = extra,
      extra_num = 3,
      prompt = "#qiao__skill_han024_2-choose",
    })
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "焚心",
  [":" .. skill.name] = "当你杀死角色后，你可以变更副将，此次变更额外获得三张其副将牌面势力的备选武将牌。",
  ["#qiao__skill_han024_2-invoke"] = "焚心：是否变更副将（额外获得三张 %dest 副将牌面势力的备选武将牌）",
  ["#qiao__skill_han024_2-choose"] = "焚心：选择一名备选武将牌变更副将",
}

return skill
