-- EM(WEI001) 曹操 · 建安
-- 君主技：拥有霸者求贤状。旗由魏势力角色在准备阶段使用。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"

local skill = fk.CreateSkill {
  name = W.JIANAN,
}
skill.qiaoImplemented = true

local function grant(player)
  if player:hasSkill(W.BANNER, true, true) then
    player:addSkill(W.BANNER, W.JIANAN)
  else
    player.room:handleAddLoseSkills(player, W.BANNER, W.JIANAN, false, true)
  end
  local rule = Fk.skills[W.RULE]
  if rule ~= nil and not player.room:hasSkill(W.RULE) then player.room:addSkill(rule) end
end

local function remove(player)
  player.room:handleAddLoseSkills(player, "-" .. W.BANNER, W.JIANAN, false, true)
end

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    for _, p in ipairs(player.room.players) do
      if p:hasSkill(skill.name) then grant(p) end
    end
  end,
})

skill:addAcquireEffect(function(self, player) grant(player) end)
skill:addLoseEffect(function(self, player) remove(player) end)

Fk:loadTranslationTable {
  [W.JIANAN] = "建安",
  [":" .. W.JIANAN] = "君主技，你拥有“霸者求贤状”。",
}

return skill
