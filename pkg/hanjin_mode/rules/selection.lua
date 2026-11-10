-- Reuse the engine's initial-general UI and Request transport, validating before
-- dereferencing client-supplied general names (the upstream helper assumes validity).
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local M = {}

function M.decode(reply)
  if type(reply) ~= "table" or type(reply[1]) ~= "string" then return {}, {} end
  local generals = reply[1]:split(",")
  if #generals ~= 2 then return {}, {} end
  local extra = type(reply[2]) == "string" and reply[2]:split(",") or {}
  return generals, { kingdom = extra[1] == "kingdom" and extra[2] or nil }
end

function M.ask(room, players, offers, allowed)
  local req = Request:new(players, "CustomDialog")
  req.focus_text = "AskForGeneral"
  req.timeout = room:getSettings("generalTimeout") or room.timeout
  for _, player in ipairs(players) do
    local choices = offers[player]
    local default
    for _, a in ipairs(choices) do
      for _, b in ipairs(choices) do
        if a ~= b and #Ban.pairKingdoms(Fk.generals[a], Fk.generals[b], allowed) > 0 then
          default = { a, b }; break
        end
      end
      if default then break end
    end
    assert(default, "Each player must receive a legal pair")
    req:setData(player, { component = {
      name = "ChooseInitialGeneralBox", uri = "LunarLtk.Pages.Popups",
      model = { name = "ChooseInitialGeneralModel", uri = "LunarLtk.Models.Popups", prop = {
        generals = choices, choiceNum = 2, lordGeneral = "", lordDeputy = "",
        selfRole = "", lordRole = "", hegemony = true, hideRole = true,
        convertDisabled = room:getSettings("disableSameConvert") or false,
        enabledKingdoms = allowed,
      } },
    } })
    req:setDefaultReply(player, { table.concat(default, ","), "kingdom," })
  end
  local answers, extras = {}, {}
  for _, player in ipairs(players) do
    answers[player], extras[player] = M.decode(req:getResult(player))
  end
  return answers, extras
end

return M
