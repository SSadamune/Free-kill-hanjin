-- EM(SHU001) 六师率义旗的回合末临时技能清理。
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local skill = fk.CreateSkill { name = "qiao__skill_em_shu001_flag_rule" }
local GRANTED = "qiao_em_shu001_flag_granted"

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and #(player.room:getTag(GRANTED) or {}) > 0
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    local list = room:getTag(GRANTED) or {}
    room:setTag(GRANTED, {})
    for _, entry in ipairs(list) do
      local p = room:getPlayerById(entry.player)
      if p ~= nil then
        CardSkills.detachSource(room, p, entry.skill, Fk.skills["qiao__skill_em_shu001_flag"], true)
      end
    end
  end,
})

return skill
