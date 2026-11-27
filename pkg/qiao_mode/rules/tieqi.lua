local PrivateMarks = require "packages.qiao.pkg.qiao_mode.rules.private_marks"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Sources = require "packages.qiao.pkg.qiao_mode.rules.skill_sources"

local M = { POSITIONS = "qiao__skill_shu006_2_positions-turn" }
local PUBLIC = "qiao_shu_tieqi_public-turn"
local PRIVATE = "qiao_shu_tieqi_private-turn"

function M.hasGeneral(player, deputy)
  local name = Exchange.actualGeneral(player, deputy)
  return name ~= "anjiang" and Fk.generals[name] ~= nil and not Exchange.isSoldier(name)
end

local function affected(room, player)
  local shown, hidden, spared = {}, {}, {}
  local positions = player:getTableMark(M.POSITIONS)
  for _, deputy in ipairs({ false, true }) do
    if M.hasGeneral(player, deputy) then
      local marked = table.contains(positions, deputy and "deputy" or "main")
      local revealed = Exchange.isRevealed(player, deputy)
      if marked or revealed then
        local result = marked and (revealed and shown or hidden) or spared
        for id in pairs(Exchange.positionSkillKeys(room, player, deputy, false)) do
          local skill = Fk.skills[id]
          if Sources.isGeneralSkill(skill) and not skill:hasTag(Skill.Compulsory) then
            result[id] = true
          end
        end
      end
    end
  end
  -- A name may still be provided by the other active position or a separate
  -- role grant. Runtime IDs already distinguish independently tracked copies.
  for source, skills in pairs(player.derivative_skills) do
    if source.name ~= Cards.SOURCE then
      for _, skill in ipairs(skills) do
        if skill ~= source then spared[skill.name] = true end
      end
    end
  end
  for id in pairs(spared) do
    shown[id], hidden[id] = nil, nil
  end
  return shown, hidden
end

local function list(set)
  local ids = {}
  for id in pairs(set) do table.insert(ids, id) end
  table.sort(ids)
  return ids
end

local function update(room, player, forcePrivate)
  local shown, hidden = affected(room, player)
  shown, hidden = list(shown), list(hidden)
  if not table.isEqual(player:getTableMark(PUBLIC), shown) then
    room:setPlayerMark(player, PUBLIC, #shown > 0 and shown or 0)
  end
  if forcePrivate or not table.isEqual(player.tag.qiaoTieqiHidden or {}, hidden) then
    player.tag.qiaoTieqiHidden = hidden
    PrivateMarks.notify(player, PRIVATE, #hidden > 0 and hidden or 0)
  end
end

function M.mark(room, player, deputy)
  room:addTableMarkIfNeed(player, M.POSITIONS, deputy and "deputy" or "main")
  update(room, player, true)
end

function M.invalidates(player, skill)
  if not next(player:getTableMark(M.POSITIONS)) then return false end
  local skeleton = skill:getSkeleton()
  local id = skeleton and skeleton.name or skill.name
  if player:isInstanceOf(ServerPlayer) then
    local shown, hidden = affected(player.room, player)
    return shown[id] or hidden[id] or false
  end
  if table.contains(player:getTableMark(PUBLIC), id) then return true end
  local client = Fk:currentRoom()
  return player == Self and not client.observing and not client.replaying
    and table.contains(player:getTableMark(PRIVATE), id)
end

function M.install(room)
  PrivateMarks.register(room, PRIVATE, function(currentRoom, viewer)
    if next(viewer:getTableMark(M.POSITIONS)) then
      local _, hidden = affected(currentRoom, viewer)
      if next(hidden) then return list(hidden) end
    end
  end)
  local handle = room.handleAddLoseSkills
  function room:handleAddLoseSkills(player, ...)
    local result = handle(self, player, ...)
    if next(player:getTableMark(M.POSITIONS)) then update(self, player) end
    return result
  end
end

Cards.addChangeListener(function(room)
  for _, player in ipairs(room.alive_players) do
    if next(player:getTableMark(M.POSITIONS)) then update(room, player) end
  end
end)

return M
