-- EM(SHU001) 刘备 · 章武
-- 君主技：刘备拥有“六师率义旗”；旗入口授予其他蜀势力角色，随明置/失技/
-- 死亡/势力/座次变化同步。授予来源独立，不删除其他来源。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_em_shu001_1",
}
skill.qiaoImplemented = true

local FLAG = "qiao__skill_em_shu001_flag"
local SYNCING = "qiao_em_shu001_flag_syncing"

local function lordOf(room)
  for _, p in ipairs(room:getPresentPlayers()) do
    if not p.dead and not p:isRemoved() and p:hasShownSkill(skill.name) then return p end
  end
  return nil
end

local function syncFlags(room)
  if room == nil or room:getTag(SYNCING) then return end
  room:setTag(SYNCING, true)
  local lord = lordOf(room)
  for _, p in ipairs(room.players) do
    if p ~= lord and p:isAlive() and not p:isRemoved() and lord ~= nil
      and H.compareKingdomWith(lord, p) then
      if not p:hasSkill(FLAG) then
        room:handleAddLoseSkills(p, FLAG, skill.name, false, true)
      end
    elseif p:hasSkill(FLAG) then
      room:handleAddLoseSkills(p, "-" .. FLAG, skill.name, false, true)
    end
  end
  room:setTag(SYNCING, nil)
end

local spec = {
  global = true,
  can_refresh = function(self, event, target, player)
    if player == nil or player.room == nil then return false end
    -- GameStart 只由首座触发一次；其余事件只由事件目标触发，避免全局每
    -- player 重复重算八遍。
    if event == fk.GameStart then return player.seat == 1 end
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    syncFlags(player.room)
  end,
}
skill:addEffect(fk.GameStart, spec)
skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.GeneralHidden, spec)
skill:addEffect(fk.EventAcquireSkill, spec)
skill:addEffect(fk.EventLoseSkill, spec)
skill:addEffect(fk.Death, spec)
skill:addEffect(fk.AfterPropertyChange, spec)
skill:addEffect(fk.TurnStart, spec)

skill:addAcquireEffect(function(self,player) syncFlags(player.room) end)
skill:addLoseEffect(function(self,player) syncFlags(player.room) end)

Fk:loadTranslationTable {
  ["qiao__skill_em_shu001_1"] = "章武",
  [":qiao__skill_em_shu001_1"] = "君主技，你拥有“六师率义旗”。",
}

return skill
