-- EM(SHU001) 六师率义旗的回合末临时技能清理。
local skill = fk.CreateSkill { name = "hanjin__skill_em_shu001_flag_rule" }
local GRANTED = "hanjin_em_shu001_flag_granted"

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
      if p ~= nil and p:hasSkill(entry.skill) then
        room:handleAddLoseSkills(p, "-" .. entry.skill,
          "hanjin__skill_em_shu001_flag", false, true)
      end
    end
  end,
})

return skill
