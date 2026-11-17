-- EM(JIN001) 司马炎 · 太康
-- 君主技：拥有诸王敕封册。
local skill = fk.CreateSkill {
  name = "qiao__skill_em_jin001_1",
}
skill.qiaoImplemented = true

local BANNER = "qiao__skill_em_jin001_banner"

local function grant(player)
  if player:hasSkill(BANNER, true, true) then
    player:addSkill(BANNER, skill.name)
  else
    player.room:handleAddLoseSkills(player, BANNER, skill.name, false, true)
  end
end

local function remove(player)
  player.room:handleAddLoseSkills(player, "-" .. BANNER, skill.name, false, true)
end

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player) return player.seat == 1 end,
  on_refresh = function(self, event, target, player)
    for _, p in ipairs(player.room.players) do
      if p:hasSkill(skill.name) then grant(p) end
    end
  end,
})
skill:addAcquireEffect(function(self, player) grant(player) end)
skill:addLoseEffect(function(self, player) remove(player) end)

Fk:loadTranslationTable {
  ["qiao__skill_em_jin001_1"] = "太康",
  [":qiao__skill_em_jin001_1"] = "君主技，你拥有“诸王敕封册”。",
}

return skill
