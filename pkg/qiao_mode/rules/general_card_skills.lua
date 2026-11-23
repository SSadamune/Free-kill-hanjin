-- 明确由武将牌获得的后天技能：每房间、每张牌记录，不修改全局将牌定义。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}
M.TAG="qiao_general_card_skills_v1"
M.SOURCE="qiao__general_card_skill_source"
local HIDDEN="qiao_general_card_skills_hidden"
local SYNCING="qiao_general_card_skills_syncing"
local listeners={}
local primarySource = function() return true end

function M.setPrimarySourceFilter(filter)
  primarySource = filter
end
local function data(room,create)
  local value=room:getTag(M.TAG)
  if type(value)~="table" then
    value={}
    if create then room:setTag(M.TAG,value) end
  end
  return value
end
function M.addChangeListener(fn)
  assert(type(fn)=="function")
  table.insertIfNeed(listeners,fn)
  return fn
end
function M.skills(room,generalName)
  local entry=data(room,false)[generalName]
  return entry and table.simpleClone(entry.skills) or {}
end
function M.provides(room,generalName,skillName)
  return table.contains(M.skills(room,generalName),skillName)
end
local function actual(player,deputy)
  local name=deputy and player.deputyGeneral or player.general
  if name=="anjiang" then return player:getMark(deputy and "__heg_deputy" or "__heg_general") end
  return name
end
local function printedAt(player,skillName,hiddenOnly)
  for _,deputy in ipairs({false,true}) do
    local public=deputy and player.deputyGeneral or player.general
    local general=Fk.generals[actual(player,deputy)]
    if general and (not hiddenOnly or public=="anjiang")
      and table.contains(general:getSkillNameList(true),skillName) then return true end
  end
  return false
end
local function otherSource(player,skill,source)
  if table.contains(player.player_skills,skill) then return true end
  for key,list in pairs(player.derivative_skills) do
    if key~=source and table.contains(list,skill) then return true end
  end
  return false
end
--- 撤回这一份派生来源。角色仍有同名来源时，保留关联技能及无效状态。
function M.detachSource(room,player,name,source,noTrigger)
  local skill=Fk.skills[name]
  local list=player.derivative_skills[source]
  if not list or not table.contains(list,skill) then return end
  if otherSource(player,skill,source) then
    table.removeOne(list,skill)
    if #list==0 then player.derivative_skills[source]=nil end
  else
    room:handleAddLoseSkills(player,"-"..name,source,false,noTrigger or false)
  end
end
function M.grant(room,generalName,skillName)
  local E=require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  assert(Fk.generals[generalName] and not E.isSoldier(generalName),"Expected a general card")
  assert(Fk.skills[skillName],"Unknown card-bound skill")
  local all=data(room,true)
  all[generalName]=all[generalName] or {skills={}}
  table.insertIfNeed(all[generalName].skills,skillName)
  room:setTag(M.TAG,all)
  M.sync(room)
end
function M.revoke(room,generalName,skillName)
  local all=data(room,false)
  if not all[generalName] then return end
  table.removeOne(all[generalName].skills,skillName)
  if #all[generalName].skills==0 then all[generalName]=nil end
  room:setTag(M.TAG,all)
  M.sync(room)
end
-- 位置交换的牌技列表仍包含后天技能；真实授予由本模块的独立来源统一管理。
function M.manages(player,name)
  for _,deputy in ipairs({false,true}) do
    if M.provides(player.room,actual(player,deputy),name) then return true end
  end
  return false
end
function M.sync(room)
  if not room or room:getTag(SYNCING) then return end
  if type(room:getTag(M.TAG))~="table" and type(room:getTag(HIDDEN))~="table" then
    for _,fn in ipairs(listeners) do fn(room) end
    return
  end
  M.installRevealAdapter()
  local source=assert(Fk.skills[M.SOURCE],"Missing pre-registered card-skill source")
  local E=require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  room:setTag(SYNCING,true)
  local ok,err=pcall(function()
    local previous=room:getTag(HIDDEN) or {}
    local nextHidden={}
    for _,player in ipairs(room.players) do
      local desired,hidden={},{}
      if not player.dead then
        for _,deputy in ipairs({false,true}) do
          local name=actual(player,deputy)
          local shown=(deputy and player.deputyGeneral or player.general)~="anjiang"
          for _,skillName in ipairs(M.skills(room,name)) do
            local skill=Fk.skills[skillName]
            local wrong=(deputy and skill:hasTag(Skill.MainPlace))
              or (not deputy and skill:hasTag(Skill.DeputyPlace))
            if not wrong and E.cardProvidesSkill(room,name,skillName)
              and primarySource(player, name, skillName) then
              if shown then desired[skillName]=true else hidden[skillName]=true end
            end
          end
        end
      end
      local prior=table.simpleClone(player.derivative_skills[source] or {})
      for _,skill in ipairs(prior) do
        if not desired[skill.name] then M.detachSource(room,player,skill.name,source) end
      end
      for name in pairs(previous[player.id] or {}) do
        if not hidden[name] and not printedAt(player,name,true) and player:isFakeSkill(name) then
          player:prelightSkill(name,false)
          player:loseFakeSkill(name)
        end
      end
      for name in pairs(desired) do
        if player:isFakeSkill(name) then
          player:prelightSkill(name,false)
          player:loseFakeSkill(name)
        end
        local skill=Fk.skills[name]
        if not table.contains(player.derivative_skills[source] or {},skill) then
          if player:hasSkill(name,true,true) then player:addSkill(skill,source)
          else room:handleAddLoseSkills(player,name,source,false,false) end
        end
      end
      for name in pairs(hidden) do
        if not desired[name] and not otherSource(player,Fk.skills[name],source) then
          if not player:isFakeSkill(name) then player:addFakeSkill(name) end
        end
      end
      nextHidden[player.id]=hidden
    end
    room:setTag(HIDDEN,nextHidden)
  end)
  room:setTag(SYNCING,nil)
  if not ok then error(err,0) end
  for _,fn in ipairs(listeners) do fn(room) end
end
-- 所有原生技能发动入口仍调用 revealBySkillName；补齐其对后天附将技能的识别。
function M.installRevealAdapter()
  local ServerPlayer=require "ltk.server.serverplayer"
  if ServerPlayer.__qiao_card_skills then return end
  ServerPlayer.__qiao_card_skills=true
  local original=ServerPlayer.revealBySkillName
  ServerPlayer.revealBySkillName=function(player,name)
    if Modes.inRoom(player.room) then
      local effect=Fk.skills[name]
      local root=effect and effect:getSkeleton().name or name
      local E=require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
      for _,deputy in ipairs({false,true}) do
        local public=deputy and player.deputyGeneral or player.general
        local generalName=actual(player,deputy)
        if public=="anjiang" and M.provides(player.room,generalName,root)
          and E.cardProvidesSkill(player.room,generalName,root) then
          player:revealGeneral(deputy)
          return
        end
      end
    end
    return original(player,name)
  end
end
return M
