-- 游戏牌标记。实例身份与游戏牌 ID 只在服务端登记；客户端仍看原有的具名牌堆。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Sources = require "packages.qiao.pkg.qiao_mode.rules.skill_sources"
local M = {}
local rooms = setmetatable({}, { __mode = "k" })
local registered = {}
local instances = setmetatable({}, { __mode = "k" })

local function instance(room, key, label, general, root)
  instances[room] = instances[room] or {}
  local entry = instances[room][key]
  if not entry then
    entry = { key = key, label = label, general = general, root = root }
    instances[room][key] = entry
  end
  return entry
end

function M.register(skill, pile)
  registered[skill] = pile
end

local function ledger(room)
  rooms[room] = rooms[room] or {}
  return rooms[room]
end

local function cardKey(general, skill)
  return "general/" .. general .. "/" .. skill
end
local function grantKey(player, source, skill)
  return "grant/" .. player.id .. "/" .. source .. "/" .. skill
end

local function candidates(player, effect, root)
  local exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  local cards = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
  local runtime = effect:getSkeleton().name
  local general = exchange.skillOwner(player, runtime)
  local list = {}
  if runtime == root then
    local grants = {}
    for source, skills in pairs(player.derivative_skills) do
      if source.name ~= cards.SOURCE and table.contains(skills, Fk.skills[root]) then
        table.insert(grants, source.name)
      end
    end
    table.sort(grants)
    for _, grant in ipairs(grants) do
      local label = grant == Sources.DIRECT and root or grant
      table.insert(list, instance(player.room, grantKey(player, grant, root), label, nil, root))
    end
    -- 暗将预亮时，技能查询可能找到暗置的武将牌。已有直接授技且未预亮时
    -- 不能据此把角色授技所放的牌挂到暗将上。
    if general and #grants > 0 and general ~= player.general and general ~= player.deputyGeneral
      and not table.contains(player.prelighted_skills, Fk.skills[root]) then general = nil end

  end
  if general then
    local source = instance(player.room, cardKey(general, root), general, general, root)
    source.holder = player
    table.insert(list, 1, source)
  end
  return list
end

function M.cards(player, source, pile)
  local bindings = rooms[player.room] or {}
  return table.filter(player:getPile(pile), function(id)
    return bindings[id] and bindings[id].source == source
  end)
end

function M.available(event, effect, player, root, eligible)
  if not player:hasSkill(effect:getSkeleton().name) then return {} end
  local used = event:getSkillData(effect, "marker_sources") or {}
  return table.filter(candidates(player, effect, root), function(source)
    return not used[source.key] and (not eligible or eligible(source))
  end)
end

function M.limit(event, effect, player, root)
  return (event.invoked_times[effect.name] or 0) + #M.available(event, effect, player, root)
end

function M.choose(room, sources, root, player)
  if #sources <= 1 then return sources[1] end
  local choice = room:askToChoice(player, {
    choices = table.map(sources, function(source) return source.label end),
    skill_name = root, prompt = "#qiao_marker_source",
  })
  return table.find(sources, function(source) return source.label == choice end)
end

-- 主动技或转化技没有 TriggerEvent 的逐来源询问窗口，仍以同一账本绑定实体牌。
function M.chooseForSkill(player, effect, root)
  return M.choose(player.room, candidates(player, effect, root), root, player)
end

function M.used(event, effect, source)
  local used = event:getSkillData(effect, "marker_sources") or {}
  used[source.key] = true
  event:setSkillData(effect, "marker_sources", used)
end

function M.put(player, source, root, ids, visible)
  local room, pile = player.room, assert(registered[root])
  local bindings = ledger(room)
  local placed = {}
  for _, id in ipairs(ids) do
    placed[id] = { source = source, pile = pile, visible = visible }
    bindings[id] = placed[id]
  end
  room:moveCardTo(ids, Card.PlayerSpecial, source.holder or player, fk.ReasonPut, root, pile, visible, player)
  for _, id in ipairs(ids) do
    if bindings[id] == placed[id] then
      if source.ended then
        bindings[id] = nil
        local holder = room:getCardOwner(id)
        if holder and table.contains(holder:getPile(pile), id) then
          room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, root, nil, true)
        end
      elseif room:getCardArea(id) ~= Card.PlayerSpecial or not room:getCardOwner(id)
        or not table.contains(room:getCardOwner(id):getPile(pile), id) then
        bindings[id] = nil
      end
    end
  end
end

function M.afterMove(room, moves)
  local bindings = rooms[room]
  if not bindings or not next(bindings) then return end
  for _, move in ipairs(moves) do
    for _, info in ipairs(move.moveInfo) do
      local id, entry = info.cardId, bindings[info.cardId]
      if entry and info.fromArea == Card.PlayerSpecial and info.fromSpecialName == entry.pile then
        local expected = entry.destination or move.from
        local owner = room:getCardOwner(id)
        if not owner or owner ~= expected or not table.contains(owner:getPile(entry.pile), id) then
          bindings[id] = nil
        end
      end
    end
  end
end

local function discard(room, match)
  local active = instances[room]
  if not active then return end
  for key, source in pairs(active) do
    if match(source) then
      source.ended = true
      active[key] = nil
    end
  end
  local bindings = rooms[room] or {}
  local batches = {}
  for id, entry in pairs(bindings) do
    if entry.source.ended then
      bindings[id] = nil
      local owner = room:getCardOwner(id)
      if owner and table.contains(owner:getPile(entry.pile), id) then
        batches[entry.source.root] = batches[entry.source.root] or {}
        table.insert(batches[entry.source.root], id)
      end
    end
  end
  for root, ids in pairs(batches) do
    table.sort(ids)
    room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, root, nil, true)
  end
end

function M.endCard(room, general, root)
  if not general then return end
  discard(room, function(entry) return entry.general == general and (not root or entry.root == root) end)
end

function M.endGrant(player, source, root)
  if not registered[root] then return end
  local key = grantKey(player, source or "", root)
  discard(player.room, function(entry) return entry.key == key end)
end

function M.transfer(from, to, general)
  if from == to then return end
  for _, source in pairs(instances[from.room] or {}) do
    if source.general == general then source.holder = to end
  end
  local bindings = rooms[from.room]
  if not bindings then return end
  for root, pile in pairs(registered) do
    -- 使用牌堆中的顺序。每个连续可见性组作为一次移牌，保留原可见性。
    local batches = {}
    for _, id in ipairs(from:getPile(pile)) do
      local entry = bindings[id]
      if entry and entry.source.general == general and entry.source.root == root then
        local batch = batches[#batches]
        if not batch or batch.visible ~= entry.visible then
          batch = { ids = {}, visible = entry.visible }
          table.insert(batches, batch)
        end
        table.insert(batch.ids, id)
      end
    end
    for _, batch in ipairs(batches) do
      local ids = table.filter(batch.ids, function(id)
        return bindings[id] and table.contains(from:getPile(pile), id)
      end)
      if #ids > 0 then
        for _, id in ipairs(ids) do bindings[id].destination = to end
        from.room:moveCardTo(ids, Card.PlayerSpecial, to, fk.ReasonJustMove, root, pile, batch.visible, to)
        for _, id in ipairs(ids) do if bindings[id] then bindings[id].destination = nil end end
      end
    end
  end
end

-- 引擎直接撤销父技能时也要清理实际结束的标记来源。
function M.install()
  if M.installed then return end
  M.installed = true
  local class = require "ltk.server.serverplayer"
  local exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  local loseSkill = class.loseSkill
  function class:loseSkill(skill, source)
    if not Modes.inRoom(self.room) then return loseSkill(self, skill, source) end
    local parent = type(skill) == "string" and Fk.skills[skill] or skill
    local root = parent.name
    -- 引擎撤销父技能时会直接删除其整张派生表，不会逐一调用 loseSkill。
    local children = {}
    for _, child in ipairs(self.derivative_skills[parent] or {}) do
      if registered[child.name] then table.insert(children, child.name) end
    end
    source = Sources.lossSource(self, parent, source)
    local sourceName = type(source) == "table" and source.name or source
    local result = loseSkill(self, skill, source)
    if not self.derivative_skills[parent] then
      for _, child in ipairs(children) do M.endGrant(self, root, child) end
    end
    if registered[root] then
      M.endGrant(self, sourceName, root)
      if not sourceName and not self:hasSkill(root, true, true) then
        for _, general in ipairs({ self.general, self.deputyGeneral }) do
          if exchange.cardProvidesSkill(self.room, general, root) then M.endCard(self.room, general, root) end
        end
      end
    end
    return result
  end
end

Fk:loadTranslationTable { ["#qiao_marker_source"] = "选择此次发动的技能来源" }
return M
