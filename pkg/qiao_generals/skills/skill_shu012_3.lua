-- SHU012 姜维 · 承志
-- 副将技：主将实际拥有观星来源时，观星卜算+2；否则由本技能授予独立观星。
-- 印刷来源与后天获得都按主将位置核对；独立授予保留自己的来源，不冒充主将。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local G = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu012_3",
  tags = { Skill.DeputyPlace },
}
skill.qiaoImplemented = true

local GUANXING = "qiao__skill_shu004_1"
local BONUS = "qiao__skill_shu012_3-guanxing-bonus"

---@param player ServerPlayer
---@return boolean
local function mainHasGuanxing(player)
  local main = Exchange.actualGeneral(player, false)
  return main ~= nil and Exchange.cardProvidesSkill(player.room,main,GUANXING)
end

local function refresh(player)
  if player == nil or player.room == nil or player.dead then return end
  local room = player.room
  local main = mainHasGuanxing(player)
  room:setPlayerMark(player, BONUS, main and 1 or 0)
  local source=Fk.skills[skill.name]
  local own=player.derivative_skills[source] or {}
  local granted=table.contains(own,Fk.skills[GUANXING])
  if main and granted then
    room:handleAddLoseSkills(player,"-"..GUANXING,skill.name,false,true)
    -- 变更主将时，引擎可能因已有承志派生观星而跳过印刷同名技能的安装。
    -- 撤掉承志来源后补齐仍明置且确实提供观星的主将来源。
    if player.general ~= "anjiang" and not player:hasSkill(GUANXING,true,true) then
      if G.provides(room,player.general,GUANXING) then G.sync(room)
      else room:handleAddLoseSkills(player,GUANXING,nil,false,true) end
    end
  elseif not main and not granted then
    if player:hasSkill(GUANXING,true,true) then player:addSkill(GUANXING,source)
    else room:handleAddLoseSkills(player,GUANXING,skill.name,false,true) end
  end
end

G.addChangeListener(function(room)
  for _, p in ipairs(room.players) do
    if p:hasSkill(skill.name) then refresh(p) end
  end
end)

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player) refresh(player) end,
})

local spec = {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player) refresh(player) end,
}
skill:addEffect(fk.EventAcquireSkill, spec)
skill:addEffect(fk.EventLoseSkill, spec)
skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.AfterPropertyChange, spec)
local H=require "packages.hegemony.util"
skill:addEffect(H.GeneralTransformed,spec)
skill:addEffect(fk.GeneralHidden,{
  global=true,
  can_refresh=function(self,event,target,player,data)
    local general=type(data)=="string" and Fk.generals[data] or nil
    return target==player and general~=nil
      and table.contains(general:getSkillNameList(true),skill.name)
  end,
  on_refresh=function(self,event,target,player)
    player.room:setPlayerMark(player,BONUS,0)
    player.room:handleAddLoseSkills(player,"-"..GUANXING,skill.name,false,true)
  end,
})

skill:addLoseEffect(function(self,player)
  player.room:setPlayerMark(player,BONUS,0)
  player.room:handleAddLoseSkills(player,"-"..GUANXING,skill.name,false,true)
end)

Fk:loadTranslationTable {
  ["qiao__skill_shu012_3"] = "承志",
  [":qiao__skill_shu012_3"] = "副将技（☯️-1），若你的主将拥有“观星”，则该技能卜算牌数+2，否则你拥有“观星”。",
}

return skill
