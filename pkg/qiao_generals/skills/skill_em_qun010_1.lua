-- EM(QUN010) 张角 · 弘法
-- 君主技：拥有黄巾天兵符（独立的旗入口技能）。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"

local skill = fk.CreateSkill {
  name = P.HONGFA,
}
skill.qiaoImplemented = true

local function grantBanner(player)
  if player:hasSkill(P.BANNER_SKILL, true, true) then
    -- 已有其他来源时只追加弘法这份独立来源，不把其他来源吞并。
    player:addSkill(P.BANNER_SKILL, skill.name)
  else
    player.room:handleAddLoseSkills(player, P.BANNER_SKILL, skill.name, false, true)
  end
end

local function removeBanner(player)
  -- 引擎移除弘法时已撤掉它提供的旗，但不会为该派生技能调用失技回调。
  -- 若仍有独立旗来源，其牌堆和入口应保留。
  if not player:hasSkill(P.BANNER_SKILL, true, true) then
    Fk.skills[P.BANNER_SKILL]:getSkeleton():onLose(player, false)
  end
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
  ["qiao__skill_em_qun010_1"] = "弘法",
  [":qiao__skill_em_qun010_1"] = "君主技，你拥有“黄巾天兵符”。",
}

return skill
