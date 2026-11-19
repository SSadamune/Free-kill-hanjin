-- EM(WEI001) 曹操 · 建安旗的公共入口与限制。
--
-- 限制绑定“那张被暗置的武将牌”：记录角色、主/副位置和牌名；明置由
-- RevealProhibited 基础标记拦截，移除、交换、变更分别接入公共入口。
-- 记录只在受益者自己的下一个回合开始解除；君主失去旗不提前清理。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local H = require "packages.hegemony.util"

local M = {}

M.LORD = "qiao_heg__em_wei001"
M.JIANAN = "qiao__skill_em_wei001_1"
M.HUIBIAN = "qiao__skill_em_wei001_2"
M.ZONGYU = "qiao__skill_em_wei001_3"
M.BANNER = "qiao__skill_em_wei001_banner"
M.SOURCE = "qiao__skill_em_wei001_banner_source"
M.RULE = "qiao__skill_em_wei001_rule"
M.TAG = "qiao_em_wei001_restrictions"
M.TEMP = "qiao_em_wei001_temp_skills"

local function isQiaoRoom(room)
  return room ~= nil and type(room.getSettings) == "function"
    and Modes.inRoom(room)
end

local function records(room)
  return room:getTag(M.TAG) or {}
end

function M.record(room, player)
  if room == nil or player == nil then return nil end
  return records(room)[player.id]
end

local function actual(room, player, isDeputy)
  local public = isDeputy and player.deputyGeneral or player.general
  if public ~= "anjiang" and public ~= nil and public ~= "" then return public end
  return player:getMark(isDeputy and "__heg_deputy" or "__heg_general")
end

--- 该位置上的牌是否正是被限制的牌。仅服务端公共入口使用。
function M.isPositionRestricted(room, player, isDeputy)
  if not isQiaoRoom(room) then return false end
  local rec = M.record(room, player)
  if rec == nil or rec.isDeputy ~= isDeputy then return false end
  return actual(room, player, isDeputy) == rec.general
end

local function setTempEntry(room, player, entry)
  if entry == nil or next(entry) == nil then
    room:setPlayerMark(player, M.TEMP, 0)
  else
    room:setPlayerMark(player, M.TEMP, entry)
  end
end

function M.bind(room, player, isDeputy, generalName)
  local list = table.simpleClone(records(room))
  local mark = table.simpleClone(player:getTableMark(MarkEnum.RevealProhibited))
  local place = isDeputy and "d" or "m"
  -- 只记录本次是否新增基础标记；已有同位置禁亮来源时既不重复添加，
  -- 解除时也不删除别人的记录。
  local added = not table.contains(mark, place)
  if added then table.insert(mark, place) end
  list[player.id] = { isDeputy = isDeputy, general = generalName, added = added }
  room:setTag(M.TAG, list)
  if added then room:setPlayerMark(player, MarkEnum.RevealProhibited, mark) end
  -- 绑定位置随授技来源同步给客户端，供同名技能的有效性判断使用。
  local entry = player:getTableMark(M.TEMP)
  entry.isDeputy, entry.general, entry.added = isDeputy, generalName, added
  setTempEntry(room, player, entry)
end

function M.unbind(room, player)
  local entry = player:getTableMark(M.TEMP)
  entry.isDeputy, entry.general, entry.added = nil, nil, nil
  setTempEntry(room, player, entry)
  local list = table.simpleClone(records(room))
  local rec = list[player.id]
  if rec == nil then return end
  list[player.id] = nil
  room:setTag(M.TAG, next(list) ~= nil and list or nil)
  if rec.added then
    local mark = table.simpleClone(player:getTableMark(MarkEnum.RevealProhibited))
    table.removeOne(mark, rec.isDeputy and "d" or "m")
    room:setPlayerMark(player, MarkEnum.RevealProhibited, mark)
  end
end

local function rootName(skill)
  local obj = skill
  if type(obj) == "string" then obj = Fk.skills[obj] end
  if obj ~= nil and obj.main_skill ~= nil then obj = obj.main_skill end
  local skel = obj and obj:getSkeleton()
  if skel ~= nil then return skel.name end
  return obj ~= nil and obj.name or (type(skill) == "string" and skill or "")
end

local function printsSkill(generalName, skillName)
  local general = Fk.generals[generalName]
  return general ~= nil and table.contains(general:getSkillNameList(true), skillName)
end

local function hiddenSkillSources(player, skillName)
  local sources = {}
  for _, place in ipairs({ "m", "d" }) do
    local deputy = place == "d"
    if (deputy and player.deputyGeneral or player.general) == "anjiang" then
      local generalName = player:getMark(deputy and "__heg_deputy" or "__heg_general")
      if printsSkill(generalName, skillName) then sources[place] = generalName end
    end
  end
  return sources
end

--- 该技能是否已由角色实际持有，或由别的独立来源提供。
--- 暗将牌的 fake／预亮状态不是独立来源：它随牌暗置失效，也不能代替本次授技。
local function hasRealSource(player, skill)
  if table.contains(player.player_skills, skill) then return true end
  for _, list in pairs(player.derivative_skills or {}) do
    if table.contains(list, skill) then return true end
  end
  return false
end

local function independentSource(player, skillName)
  local skill = Fk.skills[skillName]
  if skill == nil then return false end
  local own = Fk.skills[M.SOURCE]
  if table.contains(player.player_skills, skill) then return true end
  for source, list in pairs(player.derivative_skills or {}) do
    if source ~= own and table.contains(list, skill) then return true end
  end
  return false
end

function M.addTempSkill(room, player, skillName)
  if room == nil or player == nil or Fk.skills[skillName] == nil then return end
  -- 只跳过真正的独立来源；已有暗将同名 fake／预亮时仍要建立本次来源。
  if independentSource(player, skillName) then return end
  local skill = Fk.skills[skillName]
  M.installInvalidityBypass()
  -- fake／预亮会让 addSkill 误判“已拥有”而跳过建立导数来源。先暂时收起预亮与
  -- 同名 fake，写入本次来源后再恢复预亮；fake 在到期时按同一位置恢复。
  local prelighted = table.contains(player.prelighted_skills, skill)
  local hadFake = player:isFakeSkill(skill)
  if prelighted then player:prelightSkill(skill, false) end
  if hadFake then player:loseFakeSkill(skill) end
  room:handleAddLoseSkills(player, skillName, M.SOURCE, false, true)
  if prelighted then player:prelightSkill(skill, true) end
  -- 只有确实建立了导数来源才记账；失败时不得留下可绕开失效的假来源标记。
  if not table.contains(player.derivative_skills[Fk.skills[M.SOURCE]] or {}, skill) then
    if hadFake then player:addFakeSkill(skill) end
    return
  end
  local entry = player:getTableMark(M.TEMP)
  entry.skills = entry.skills or {}
  table.insertIfNeed(entry.skills, skillName)
  setTempEntry(room, player, entry)
  -- 暗置的同名技能来源只用于到期恢复，不能随公开的授技标记广播。
  if hadFake then
    local players = table.simpleClone(room:getTag(M.TEMP) or {})
    local skills = table.simpleClone(players[player.id] or {})
    skills[skillName] = hiddenSkillSources(player, skillName)
    players[player.id] = skills
    room:setTag(M.TEMP, players)
  end
end

--- 本次授技来源是否仍在。技能名按骨架名归一；只读角色标记，供客户端共用。
function M.isTempProvided(player, skillName)
  if player == nil then return false end
  local entry = player:getTableMark(M.TEMP)
  return table.contains(entry.skills or {}, rootName(skillName))
end

--- 仅对霸者求贤状授予、且确实持有本次导数来源的同名技能，绕开上游
--- reveal_prohibited 因“被绑位置仍印刷同名技能”造成的按名失效。
--- 不解除禁亮，也不触碰其他 invalidity 或其他禁亮来源。
function M.bypassesRevealInvalidity(from, skill)
  if from == nil or skill == nil then return false end
  local entry = from:getTableMark(M.TEMP)
  local name = rootName(skill)
  if not table.contains(entry.skills or {}, name) then return false end
  if entry.isDeputy == nil or entry.general == nil or not entry.added then return false end
  local ownPlace = entry.isDeputy and "d" or "m"
  local function hiddenAt(place)
    return (place == "m" and from.general == "anjiang")
      or (place == "d" and from.deputyGeneral == "anjiang")
  end
  local function generalAt(place)
    return place == "m" and from:getMark("__heg_general") or from:getMark("__heg_deputy")
  end
  local function prints(place, sname)
    return printsSkill(generalAt(place), sname)
  end
  -- 本旗记录的位置必须仍是该隐藏将牌；位置被换掉后不再豁免。
  local base = from:getTableMark(MarkEnum.RevealProhibited)
  if not table.contains(base, ownPlace) then return false end
  if not hiddenAt(ownPlace) or generalAt(ownPlace) ~= entry.general then return false end
  -- 基础禁亮表里其他位置若也印刷同名技能，属于别的来源，不豁免。
  for _, place in ipairs(base) do
    if place ~= ownPlace and hiddenAt(place) and prints(place, name) then return false end
  end
  -- 带后缀的禁亮来源不是本旗写入；只要仍能命中同名技能，就不豁免。
  for mark, value in pairs(from.mark) do
    if mark:startsWith(MarkEnum.RevealProhibited .. "-") and type(value) == "table" then
      for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
        if mark:find(suffix, 1, true) then
          for _, place in ipairs(value) do
            if hiddenAt(place) and prints(place, name) then return false end
          end
        end
      end
    end
  end
  return true
end

local invalidityBypassInstalled = false
function M.installInvalidityBypass()
  if invalidityBypassInstalled then return end
  local skill = Fk.skills["reveal_prohibited"]
  if skill == nil or type(skill.getInvalidity) ~= "function" then return end
  invalidityBypassInstalled = true
  local original = skill.getInvalidity
  skill.getInvalidity = function(self, from, targetSkill)
    if M.bypassesRevealInvalidity(from, targetSkill) then return false end
    return original(self, from, targetSkill)
  end
end

--- 到期：只撤本次来源的临时技能与限制，不触碰独立同名来源。
function M.expire(room, player)
  local entry = player:getTableMark(M.TEMP)
  for _, skillName in ipairs(entry.skills or {}) do
    -- 即使已有预亮，也按来源删除导数记账；预亮本身不在此撤销。
    room:handleAddLoseSkills(player, "-" .. skillName, M.SOURCE, false, true)
  end
  -- 恢复仍在原位置的同名暗将技能，包含来自未被霸者绑定的另一张牌的来源。
  local players = table.simpleClone(room:getTag(M.TEMP) or {})
  for skillName, sources in pairs(players[player.id] or {}) do
    local skill = Fk.skills[skillName]
    if skill ~= nil and not hasRealSource(player, skill) then
      for place, generalName in pairs(hiddenSkillSources(player, skillName)) do
        if sources[place] == generalName then
          player:addFakeSkill(skill)
          break
        end
      end
    end
  end
  players[player.id] = nil
  room:setTag(M.TEMP, next(players) and players or nil)
  room:setPlayerMark(player, M.TEMP, 0)
  M.unbind(room, player)
end

--- 当前持旗君主：建安已明置有效，且霸者求贤状来源存在。
function M.lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room:getPresentPlayers()) do
    if not p.dead and not p:isRemoved() and p.kingdom == "wei"
      and p:hasShownSkill(M.JIANAN) and p:hasSkill(M.BANNER) then
      return p
    end
  end
  return nil
end

local installed = false
function M.install()
  if installed then return end
  local Room = require "ltk.server.room"
  local ServerPlayer = require "ltk.server.serverplayer"
  installed = true
  M.installInvalidityBypass()
  local originalRemove = H.removeGeneral
  H.removeGeneral = function(player, isDeputy)
    local room = player and player.room
    if isQiaoRoom(room) and M.record(room, player) ~= nil
      and M.isPositionRestricted(room, player, isDeputy == true) then
      return false
    end
    return originalRemove(player, isDeputy)
  end
  local originalChange = Room.changeHero
  Room.changeHero = function(self, player, newGeneral, full, isDeputy, ...)
    if isQiaoRoom(self) and M.record(self, player) ~= nil
      and M.isPositionRestricted(self, player, isDeputy == true) then
      return false
    end
    return originalChange(self, player, newGeneral, full, isDeputy, ...)
  end
  -- 授技是角色获得技能，不附在任何武将牌上。发动时若某个暗将恰好印刷同名
  -- 技能，原入口会明置该牌；本次来源存在时跳过明置，暗将保持原状。
  local originalReveal = ServerPlayer.revealBySkillName
  ServerPlayer.revealBySkillName = function(player, skillName)
    local room = player and player.room
    if isQiaoRoom(room) and M.isTempProvided(player, skillName) then
      return
    end
    return originalReveal(player, skillName)
  end
end

-- 新核心的 ServerPlayer 要从核心目录解析，标准包的技能也在此时就绪。
Fk:addPostLoadFunc(M.install)

return M
