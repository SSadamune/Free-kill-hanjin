-- Shared deterministic national-war fixtures for skill suites.
-- Public API: installDualGenerals, installBlankGenerals, withSkillRequests.
-- Return values are not part of the API; callers must not rely on them.
-- Room-mutating helpers must be called inside FkTest.runInRoom; they never
-- install process globals of their own.
local M = {}

local function checkRoom(room)
  assert(room and room.players, "skill_test: room is required")
  assert(RoomInstance == room,
    "skill_test: call this helper inside FkTest.runInRoom(function() ... end)")
end

--- Install an explicit main/deputy pair on one player.
--- @param room Room
--- @param player ServerPlayer must already belong to room
--- @param options table { main = string, deputy = string, kingdom = string?, hp = number? }
---
--- Revealing through the engine first clears the old hidden generals' fake
--- skills; changeHero alone only detaches the currently visible general.
--- The __heg_* marks are rewritten before hp/maxHp are recomputed because
--- Player:getGeneralMaxHp reads those marks.
--- Caller contract: must run inside FkTest.runInRoom. Returns nothing.
function M.installDualGenerals(room, player, options)
  checkRoom(room)
  assert(player and player.room == room, "skill_test: player must belong to room")
  options = options or {}
  local main = assert(options.main, "skill_test: options.main is required")
  local deputy = assert(options.deputy, "skill_test: options.deputy is required")
  assert(Fk.generals[main], "skill_test: unknown main general: " .. tostring(main))
  assert(Fk.generals[deputy], "skill_test: unknown deputy general: " .. tostring(deputy))
  local kingdom = options.kingdom or Fk.generals[main].kingdom
  assert(type(kingdom) == "string" and kingdom ~= "",
    "skill_test: options.kingdom must be a non-empty string")

  player:revealGeneral(false, true)
  player:revealGeneral(true, true)
  room:changeHero(player, deputy, true, true, false, false, false)
  room:changeHero(player, main, true, false, false, false, false)
  player.kingdom = kingdom
  room:setPlayerProperty(player, "kingdom", kingdom)
  room:setPlayerMark(player, "__heg_general", player.general)
  room:setPlayerMark(player, "__heg_deputy", player.deputyGeneral)
  room:setPlayerMark(player, "__heg_kingdom", kingdom)
  room:setPlayerMark(player, "__heg_init_kingdom", kingdom)
  room:setPlayerMark(player, "__heg_wild", 0)
  player.maxHp = player:getGeneralMaxHp()
  if options.hp ~= nil then
    player.hp = options.hp
  else
    player.hp = player.maxHp
  end
end

--- Install the deterministic blank test pair (_1 main, _2 deputy) on every seat.
--- @param room Room
--- @param kingdoms string|string[] one kingdom, or an array indexed by seat;
---   a short array reuses its last entry.
--- Caller contract: must run inside FkTest.runInRoom. Returns nothing.
function M.installBlankGenerals(room, kingdoms)
  checkRoom(room)
  for index, player in ipairs(room.players) do
    local kingdom
    if type(kingdoms) == "table" then
      kingdom = kingdoms[index] or kingdoms[#kingdoms]
    else
      kingdom = kingdoms
    end
    kingdom = kingdom or "han"
    M.installDualGenerals(room, player, {
      main = "hanjin_test__" .. kingdom .. "_1",
      deputy = "hanjin_test__" .. kingdom .. "_2",
      kingdom = kingdom,
    })
  end
end

--- Override room request methods only for requests whose params.skill_name
--- equals `skillName`; every other request is forwarded unchanged to the
--- original function. `overrides` may wrap several room methods at once, and
--- handlers receive (self, player, params, original, ...).
--- @param room Room
--- @param skillName string
--- @param overrides table<string, fun(self, player, params, original, ...)>
--- @param fn fun() code that triggers the real skill flow
---
--- All originals are restored when `fn` or a handler raises, and the original
--- error is re-raised rather than swallowed. Returns nothing; observed values
--- must be captured by the caller (upvalues).
function M.withSkillRequests(room, skillName, overrides, fn)
  assert(room, "skill_test: room is required")
  assert(type(skillName) == "string" and skillName ~= "",
    "skill_test: skillName is required")
  assert(type(overrides) == "table" and next(overrides) ~= nil,
    "skill_test: overrides are required")
  assert(type(fn) == "function", "skill_test: fn is required")

  local saved = {}
  for method, handler in pairs(overrides) do
    assert(type(handler) == "function",
      "skill_test: handler must be a function: " .. tostring(method))
    assert(type(room[method]) == "function",
      "skill_test: room has no method: " .. tostring(method))
    saved[method] = room[method]
  end
  for method, handler in pairs(overrides) do
    local original = saved[method]
    room[method] = function(self, player, params, ...)
      if not (type(params) == "table" and params.skill_name == skillName) then
        return original(self, player, params, ...)
      end
      return handler(self, player, params, original, ...)
    end
  end

  local ok, err = pcall(fn)
  for method, original in pairs(saved) do
    room[method] = original
  end
  if not ok then error(err, 0) end
end

return M
