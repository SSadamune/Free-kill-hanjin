-- EM(QUN010) 张角 · 弘法
-- 君主技：拥有黄巾天兵符（独立的旗入口技能）。
local P = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_lord_qun"

local skill = fk.CreateSkill {
  name = "hanjin__skill_em_qun010_1",
}
skill.hanjinImplemented = true

local function grantBanner(player)
  if player:hasSkill(P.BANNER_SKILL, true, true) then
    -- 已有其他来源时只追加弘法这份独立来源，不把其他来源吞并。
    player:addSkill(P.BANNER_SKILL, skill.name)
  else
    player.room:handleAddLoseSkills(player, P.BANNER_SKILL, skill.name, false, true)
  end
end

local function removeBanner(player)
  player.room:handleAddLoseSkills(player, "-" .. P.BANNER_SKILL, skill.name, false, true)
end

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    for _, p in ipairs(player.room.players) do
      if p:hasSkill(skill.name) then grantBanner(p) end
    end
  end,
})

skill:addAcquireEffect(function(self,player) grantBanner(player) end)
skill:addLoseEffect(function(self,player) removeBanner(player) end)

Fk:loadTranslationTable {
  ["hanjin__skill_em_qun010_1"] = "弘法",
  [":hanjin__skill_em_qun010_1"] = "君主技，你拥有“黄巾天兵符”。",
}

return skill
