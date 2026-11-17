-- EM(WU001) 孙权 · 嘉禾
-- 君主技：孙权拥有“缘江烽火图”；当前吴势力角色（含孙权本人）获得旗入口，
-- 随明置/失技/死亡/势力/座次变化同步。授予来源独立，不删除其他来源。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill {
  name = P.JIAHE,
}
skill.qiaoImplemented = true

local SYNCING = "qiao_em_wu001_flag_syncing"

local function sync(room)
  if room == nil or room:getTag(SYNCING) then return end
  room:setTag(SYNCING, true)
  local lord = P.lord(room)
  for _, p in ipairs(room.players) do
    local eligible = lord ~= nil and p:isAlive() and not p:isRemoved()
      and p.kingdom == "wu"
    if eligible then
      if not p:hasSkill(P.ENTRY) then
        room:handleAddLoseSkills(p, P.ENTRY, P.JIAHE, false, true)
      end
    elseif p:hasSkill(P.ENTRY) then
      room:handleAddLoseSkills(p, "-" .. P.ENTRY, P.JIAHE, false, true)
    end
  end
  room:setTag(SYNCING, nil)
end

local spec = {
  global = true,
  can_refresh = function(self, event, target, player)
    if player == nil or player.room == nil then return false end
    if event == fk.GameStart then return player.seat == 1 end
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    sync(player.room)
    -- 准备阶段授技的到期清理：旗来源存在期间保持安装一次。
    P.ensureRule(player.room)
  end,
}
skill:addEffect(fk.GameStart, spec)
skill:addEffect(fk.GeneralRevealed, spec)
-- 升变走 GeneralShown，不触发普通 GeneralRevealed；换将完成后仍需按实际
-- 主将牌重算旗入口，否则同势力角色拿不到入口。
skill:addEffect(fk.GeneralShown, spec)
skill:addEffect(fk.GeneralHidden, spec)
skill:addEffect(fk.EventAcquireSkill, spec)
skill:addEffect(fk.EventLoseSkill, spec)
skill:addEffect(fk.Death, spec)
skill:addEffect(fk.AfterPropertyChange, spec)
skill:addEffect(fk.TurnStart, spec)

local function grantFlag(player)
  if player:hasSkill(P.FLAG, true, true) then
    player:addSkill(P.FLAG, P.JIAHE)
  else
    player.room:handleAddLoseSkills(player, P.FLAG, P.JIAHE, false, true)
  end
  P.ensureRule(player.room)
end

local function removeFlag(player)
  player.room:handleAddLoseSkills(player, "-" .. P.FLAG, P.JIAHE, false, true)
end

skill:addAcquireEffect(function(self, player)
  grantFlag(player)
  sync(player.room)
end)
skill:addLoseEffect(function(self, player)
  removeFlag(player)
  sync(player.room)
end)

Fk:loadTranslationTable {
  [P.JIAHE] = "嘉禾",
  [":" .. P.JIAHE] = "君主技，你拥有“缘江烽火图”。",
}

return skill
