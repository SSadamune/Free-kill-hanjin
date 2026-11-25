-- 汉晋的武将牌撤技与角色直接授技共用原生接口，分别保留来源。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}
M.DIRECT = "qiao__role_skill_source"
local hiding = setmetatable({}, { __mode = "k" })
local revealing = setmetatable({}, { __mode = "k" })
local addPrinted

--- 为引擎技能骨架登记汉晋规则中的非武将技能。
function M.registerNonGeneral(name)
  local skeleton = Fk.skill_skels[name]
  if skeleton then skeleton.extra.qiaoNonGeneralSkill = true end
end

--- 判断易读描述中的武将技能。归属于角色或武将牌由调用者另行判断。
function M.isGeneralSkill(skill, player)
  local skeleton = skill and skill:getSkeleton()
  return skeleton ~= nil
    and not skill.name:startsWith("#") and not skeleton.name:startsWith("#")
    and not skeleton.extra.qiaoNonGeneralSkill
    and (not skill.package or skill.package.name ~= "qiao_mode")
    and skill:isPlayerSkill(player)
end

local function skillObject(skill)
  if type(skill) == "string" then return Fk.skills[skill] end
  return skill
end

local function grants(player, skill, excluded)
  for source, skills in pairs(player.derivative_skills) do
    if source ~= excluded and source ~= skill and table.contains(skills, skill) then return true end
  end
  return false
end

function M.lossSource(player, skill, source)
  if source == nil and table.contains(player.derivative_skills[Fk.skills[M.DIRECT]] or {}, skill) then
    return M.DIRECT
  end
  return source
end

function M.install(room)
  if room.qiaoSkillSourcesInstalled then return end
  room.qiaoSkillSourcesInstalled = true
  local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  local H = require "packages.hegemony.util"
  local class = require "ltk.server.serverplayer"

  local function printedOnShownCard(player, name, except)
    local skill = Fk.skills[name]
    if skill:hasTag(Skill.AttachedKingdom)
      and not table.contains(skill:getSkeleton().attached_kingdom, player.kingdom) then return false end
    for _, deputy in ipairs({ false, true }) do
      local general = Exchange.publicGeneral(player, deputy)
      local card = Fk.generals[general]
      if general ~= except and card and not skill:hasTag(deputy and Skill.MainPlace or Skill.DeputyPlace)
        and table.contains(card:getSkillNameList(true), name)
        and Exchange.cardProvidesSkill(player.room, general, name) then return true end
    end
    return false
  end

  local function trackable(skill)
    -- 这里只维护引擎授技来源，模式技及大旗等入口也需要记账。
    return skill and skill:isPlayerSkill(nil, true)
  end

  if not M.installed then
    M.installed = true
    addPrinted = class.addSkill
    local lose = class.loseSkill
    local getSkillNameList = class.getSkillNameList
    function class:getSkillNameList()
      local names = getSkillNameList(self)
      if Modes.inRoom(self.room) then
        -- 角色直接获授仍是其武将技能。保持原查询对限定技等规则的可见性。
        for _, skill in ipairs(self.derivative_skills[Fk.skills[M.DIRECT]] or {}) do
          if not skill.name:startsWith("#") then
            table.insertIfNeed(names, skill:getSkeleton().name)
          end
        end
      end
      return names
    end

    function class:addSkill(skill, source)
      local object = skillObject(skill)
      if not source and Modes.inRoom(self.room) and trackable(object)
        and not self.room:getTag("qiao_sync_same_name_skills")
        and (table.contains(self.player_skills, object) or not printedOnShownCard(self, object.name)) then
        source = M.DIRECT
      end
      return addPrinted(self, skill, source)
    end

    function class:loseSkill(skill, source)
      if not Modes.inRoom(self.room) then return lose(self, skill, source) end
      local object = skillObject(skill)
      local resolved = M.lossSource(self, object, source)
      local origin = skillObject(resolved)
      if origin == Fk.skills[M.DIRECT] and not printedOnShownCard(self, object.name) then
        -- 断肠已终止牌面来源。原生合并条目可能仍随角色来源留在基础表。
        table.removeOne(self.player_skills, object)
      end
      if origin and (table.contains(self.player_skills, object) or grants(self, object, origin)) then
        -- 原生 loseSkill 同时删除关联技能表。仅撤销一个来源时须保留它。
        local skills = self.derivative_skills[origin]
        if skills then
          table.removeOne(skills, object)
          if #skills == 0 then self.derivative_skills[origin] = nil end
        end
        return {}
      end
      return lose(self, skill, resolved)
    end
    local hide = class.hideGeneral
    function class:hideGeneral(deputy)
      if not Modes.inRoom(self.room) then return hide(self, deputy) end
      local previous = hiding[self]
      hiding[self] = { Exchange.publicGeneral(self, deputy), self.room.logic:getCurrentEvent() }
      local ok, result = pcall(hide, self, deputy)
      hiding[self] = previous
      if not ok then error(result, 0) end
      return result
    end

    local reveal = class.revealGeneral
    function class:revealGeneral(deputy, noTrigger)
      if not Modes.inRoom(self.room) or Exchange.publicGeneral(self, deputy) ~= "anjiang" then
        return reveal(self, deputy, noTrigger)
      end
      -- 上游明置会额外撤回没有 fake 条目的原生牌面技能。
      local general = Fk.generals[Exchange.actualGeneral(self, deputy)]
      local removals = {}
      for _, name in ipairs(general and general:getSkillNameList(true) or {}) do
        if not self:isFakeSkill(name) then table.insert(removals, "-" .. name) end
      end
      if #removals == 0 then return reveal(self, deputy, noTrigger) end
      local previous = revealing[self]
      revealing[self] = { names = table.concat(removals, "|"), event = self.room.logic:getCurrentEvent() }
      local ok, result = pcall(reveal, self, deputy, noTrigger)
      revealing[self] = previous
      if not ok then error(result, 0) end
      return result
    end
  end

  local handle = room.handleAddLoseSkills
  function room:handleAddLoseSkills(player, names, source, sendlog, noTrigger)
    if (source and skillObject(source) ~= Fk.skills[M.DIRECT]) or self:getTag("qiao_sync_same_name_skills") then
      return handle(self, player, names, source, sendlog, noTrigger)
    end
    local event = self.logic:getCurrentEvent()
    local cardBatch, departing
    if not source and event and sendlog == false then
      local data = event.data
      if event.event == H.GameEvent.RemoveGeneral and data.who == player and data.origName
        and not event.qiaoCardSkillBatch and type(names) == "string" and noTrigger == nil then
        local general = Exchange.publicGeneral(player, data.isDeputy)
        local card = Fk.generals[general]
        if card and names == table.concat(table.map(card:getSkillNameList(), function(name)
          return "-" .. name
        end), "|") then
          cardBatch, departing = true, general
          event.qiaoCardSkillBatch = true
        end
      elseif event.event == GameEvent.ChangeProperty and data.from == player and type(names) == "table"
        and noTrigger == false and (data.results.generalChange or data.results.deputyChange or data.results.kingdomChange)
        and not event.qiaoCardSkillBatch then
        cardBatch = true
        event.qiaoCardSkillBatch = true
      end
    end
    local hidden = hiding[player]
    if not source and not cardBatch and hidden and hidden[2] == event and sendlog == false and noTrigger == false then
      local card = Fk.generals[hidden[1]]
      if card and type(names) == "string" and names:sub(1, 1) == "-"
        and table.contains(card:getSkillNameList(), names:sub(2)) then
        cardBatch, departing = true, hidden[1]
      end
    end

    local revealed = revealing[player]
    local revealCleanup = not source and not cardBatch and revealed and not revealed.used and revealed.event == event
      and sendlog == false and noTrigger == nil and names == revealed.names
    if revealCleanup then
      cardBatch = true
      revealed.used = true
    end

    -- 仅过滤原生牌面批次，真实角色撤技仍按授予来源处理。
    local adjusted = {}
    for _, name in ipairs(type(names) == "string" and names:split("|") or names) do
      local losing = name:sub(1, 1) == "-"
      local skill = Fk.skills[losing and name:sub(2) or name]
      if losing and skill and cardBatch then
        local independent = grants(player, skill)
        local staysOnCard = (not revealCleanup or independent)
          and printedOnShownCard(player, skill.name, departing)
        if not staysOnCard and independent then
          -- 只从基础表撤掉离开的牌面来源，同时保留关联技能和失效状态。
          table.removeOne(player.player_skills, skill)
        elseif not staysOnCard then
          table.insert(adjusted, name)
        end
      elseif losing and skill and skillObject(M.lossSource(player, skill, source)) == Fk.skills[M.DIRECT]
        and ((table.contains(player.player_skills, skill) and printedOnShownCard(player, skill.name))
          or grants(player, skill, Fk.skills[M.DIRECT])) then
        player:loseSkill(skill, M.DIRECT)
      elseif not losing and skill and cardBatch then
        if printedOnShownCard(player, name) then
          if not player:hasSkill(skill, true, true) then
            table.insert(adjusted, name)
          elseif not table.contains(player.player_skills, skill) then
            addPrinted(player, skill)
          end
        end
      else
        if not losing and trackable(skill) and player:hasSkill(skill, true, true) then
          player:addSkill(skill, M.DIRECT)
        end
        table.insert(adjusted, name)
      end
    end
    return handle(self, player, adjusted, source, sendlog, noTrigger)
  end
end

Fk:loadTranslationTable { [M.DIRECT] = "角色直接获得" }
return M
