-- SHU022 马谡 · 制蛮
-- 当你对其他角色造成伤害时，你可以防止此伤害，然后获得其区域里的一张牌，
-- 若其与你势力相同，其可以变更副将（限一次）。
local H = require "packages.hegemony.util"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu022_2",
}
skill.qiaoImplemented = true

skill:addEffect(fk.DamageCaused, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data.to ~= nil and data.to ~= player
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu022_2-invoke::" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local dest = data.to
    data:preventDamage()
    if RemovedTargets.isPresent(dest) and #dest:getCardIds("hej") > 0 then
      local id = room:askToChooseCard(player, {
        target = dest,
        flag = "hej",
        skill_name = skill.name,
        prompt = "#qiao__skill_shu022_2-obtain::" .. dest.id,
      })
      if id ~= nil then
        room:obtainCard(player, id, false, fk.ReasonPrey, player, skill.name)
      end
    end
    if RemovedTargets.isPresent(dest) and H.compareKingdomWith(dest, player)
      and Change.canUseSkillChange(room, player, skill.name)
      and #Change.candidates(room, dest, true) > 0 then
      local choice = room:askToChoice(dest, {
        choices = { "changeDeputy", "Cancel" },
        skill_name = skill.name,
        prompt = "#qiao__skill_shu022_2-change",
      })
      if choice == "changeDeputy" then
        Change.performSkillChangeDeputy(room, dest, player, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "制蛮",
  [":" .. skill.name] = "当你对其他角色造成伤害时，你可以防止此伤害，然后获得其区域里的一张牌，若其与你势力相同，其可以变更副将（限一次）。",
  ["#qiao__skill_shu022_2-invoke"] = "制蛮：是否防止对 %dest 造成的伤害并获得其区域里的一张牌",
  ["#qiao__skill_shu022_2-obtain"] = "制蛮：选择获得 %dest 区域里的一张牌",
  ["#qiao__skill_shu022_2-change"] = "制蛮：你可以变更副将",
}

return skill
