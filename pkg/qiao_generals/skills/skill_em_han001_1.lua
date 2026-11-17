-- EM(HAN001) 君刘协 · 初平
-- 此君主牌实际明置后取得“诏书”特殊标记；同势力角色（含本人）获得诏书入口。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local skill = fk.CreateSkill { name = P.JIANPING }
skill.qiaoImplemented = true

local function sync(room)
  if room == nil then return end
  local lord = P.lord(room)
  for _, p in ipairs(room.players) do
    local eligible = lord ~= nil and p:isAlive() and not p:isRemoved()
      and p.kingdom == lord.kingdom
    if eligible then
      if not p:hasSkill(P.BANNER) then
        room:handleAddLoseSkills(p, P.BANNER, P.JIANPING, false, true)
      end
      if p == lord and not p:hasSkill(P.CONSUME) then
        room:handleAddLoseSkills(p, P.CONSUME, P.JIANPING, false, true)
      end
    else
      if p:hasSkill(P.BANNER) then
        room:handleAddLoseSkills(p, "-" .. P.BANNER, P.JIANPING, false, true)
      end
      if p:hasSkill(P.CONSUME) then
        room:handleAddLoseSkills(p, "-" .. P.CONSUME, P.JIANPING, false, true)
      end
    end
  end
end

local revealSpec = {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and target.general == P.LORD and target:getMark(P.MARK) == 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(target, P.MARK, 1)
    P.syncTricks(player.room)
    sync(player.room)
  end,
}
skill:addEffect(fk.GeneralShown, revealSpec)
skill:addEffect(fk.GeneralRevealed, revealSpec)

local syncSpec = {
  global = true,
  can_refresh = function(self, event, target, player)
    if event == fk.GameStart then return player.seat == 1 end
    return target == player
  end,
  on_refresh = function(self, event, target, player) sync(player.room) end,
}
skill:addEffect(fk.GameStart, syncSpec)
skill:addEffect(fk.AfterPropertyChange, syncSpec)
skill:addEffect(fk.Death, syncSpec)

skill:addAcquireEffect(function(self, player) sync(player.room) end)
skill:addLoseEffect(function(self, player) sync(player.room) end)

Fk:loadTranslationTable {
  [P.JIANPING] = "初平",
  [":" .. P.JIANPING] = "君主技，此武将牌明置后，你获得游戏外的“诏书”；你因“诏书”获得的势力锦囊由你选择。",
}

return skill
