local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"

local M = {}

local wusheng = "qiao__skill_shu002_1"
local longdan = "qiao__skill_shu005_1"
local converters = {
  slash = { wusheng, longdan },
  dismantlement = { "qiao__skill_wu002_1" },
  supply_shortage = { "qiao__skill_wei010_1" },
  jink = { "qiao__skill_wei007_1", longdan },
  peach = { longdan, "qiao__skill_qun001_1" },
}

local function targetedReply(ai, card)
  local function score(target) return Cards.scoreTarget(ai, card, target) end
  local fixed = card:getFixedTargets(ai.player, ai.handler.extra_data)
  if fixed and (#fixed == 0 or not table.every(fixed, function(target) return score(target) ~= nil end)) then return "" end
  return Requests.targets(ai, score)
end

local function convert(ai, result, budget, useTarget)
  local enabled = ai:getEnabledSkills()
  for _, name in ipairs(converters[result]) do
    if table.contains(enabled, name) then
      ai:selectSkill(name, true)
      local cards = ai:getEnabledCards()
      table.sort(cards, function(a, b)
        local va, vb = Cost.value(ai, a), Cost.value(ai, b)
        return va == vb and a < b or va < vb
      end)
      for _, id in ipairs(cards) do
        if Cost.value(ai, id) > budget then break end
        ai:selectCard(id, true)
        local card = ai.handler:getUsingCard()
        if card and card.trueName == result then
          local reply = useTarget and targetedReply(ai, card) or Requests.reply(ai)
          if reply ~= "" then return reply end
        end
        ai:unSelectAllTargets()
        ai:selectCard(id, false)
      end
      ai:unSelectAll()
    end
  end
end

function M.play(ai)
  return convert(ai, "dismantlement", 2, true)
    or convert(ai, "supply_shortage", 2, true) or convert(ai, "slash", 3, true)
end

function M.slash(ai)
  return convert(ai, "slash", 3, true)
end

function M.response(ai, pattern)
  return Cards.respond(ai, pattern) or convert(ai, pattern, ai.player.hp <= 1 and 6 or 4, false)
end

function M.rescue(ai, data)
  local prompt = data[3] or ""
  if not prompt:startsWith("#AskForPeaches") then return nil end
  local id = tonumber(prompt:split(":")[2])
  local target = prompt:startsWith("#AskForPeachesSelf") and ai.player
    or (id and ai.room:getPlayerById(id))
  if not ai:isFriend(target) then return "" end
  return Cards.respond(ai, data[2]) or convert(ai, "peach", 5, false) or ""
end

return M
