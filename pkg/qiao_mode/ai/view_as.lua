local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Reactions = require "packages.qiao.pkg.qiao_mode.ai.damage_reactions"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"

local M = {}

local wusheng = "qiao__skill_shu002_1"
local longdan = "qiao__skill_shu005_1"
local wuku = "qiao__skill_jin006_3"
local converters = {
  slash = { wusheng, longdan, wuku },
  dismantlement = { "qiao__skill_wu002_1" },
  supply_shortage = { "qiao__skill_wei010_1" },
  jink = { "qiao__skill_wei007_1", longdan, wuku },
  peach = { longdan, "qiao__skill_qun001_1", wuku },
  nullification = { "qiao__skill_shu011_3", "qiao__retinue_skill_bazhenbing_viewas", wuku },
  iron_chain = { "qiao__skill_shu010_1" },
  fire_attack = { "qiao__skill_shu011_2" },
  duel = { "qiao__qun_cards_state", wuku },
  unexpectation = { "qiao__skill_jin006_2", wuku },
}

local function targetedReply(ai, card, cost)
  local function score(target)
    if card.trueName == "dismantlement" and cost > 2 then
      local payoff = Removal.effectValue(ai, card, target)
      if not payoff or payoff < 5 or payoff <= cost + 0.5 then return end
    end
    return Cards.scoreTarget(ai, card, target)
  end
  local fixed = card:getFixedTargets(ai.player, ai.handler.extra_data)
  if fixed and (#fixed == 0 or not table.every(fixed, function(target) return score(target) ~= nil end)) then return "" end
  local targetLimit = card.trueName == "slash" and ai.player:getMark("qiao_wu012_tianyi_win-turn") > 0 and 2 or 1
  if card.trueName == "iron_chain" then targetLimit = 2 end
  return Requests.targets(ai, score, targetLimit)
end

local function convert(ai, result, budget, useTarget, cuipoIndex)
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
        local cost = Cost.value(ai, id)
        if cost > budget then break end
        ai:selectCard(id, true)
        local card = ai.handler:getUsingCard()
        if card and card.trueName == result and (not useTarget or Cards.priority(ai, card))
          and (not cuipoIndex or Cards.matchesCuipo(ai, card, cuipoIndex)) then
          local reply = useTarget and targetedReply(ai, card, cost) or Requests.reply(ai)
          if reply ~= "" then return reply end
        end
        ai:unSelectAllTargets()
        ai:selectCard(id, false)
      end
      ai:unSelectAll()
    end
  end
end

local function luanji(ai, cuipoIndex)
  local name = "qiao__skill_qun004_1"
  if not table.contains(ai:getEnabledSkills(), name) then return end
  ai:selectSkill(name, true)
  if Cost.select(ai, 2, 4) then
    local card = ai.handler:getUsingCard()
    if card and (not cuipoIndex or Cards.matchesCuipo(ai, card, cuipoIndex)) then
      local outcome = Cards.groupOutcome(ai, card)
      if Damage.worth(outcome) and outcome.enemies - outcome.friends - outcome.unknown >= 2 then
        local reply = Requests.reply(ai)
        if reply ~= "" then return reply end
      end
    end
  end
  ai:unSelectAll()
end

function M.play(ai, stage, cuipoIndex)
  if stage == "disrupt" then return convert(ai, "dismantlement", 7, true, cuipoIndex) end
  if stage == "damage" then
    return convert(ai, "slash", 3, true, cuipoIndex)
      or convert(ai, "duel", 3, true, cuipoIndex)
      or convert(ai, "unexpectation", 3, true, cuipoIndex)
      or convert(ai, "fire_attack", 2, true, cuipoIndex)
      or luanji(ai, cuipoIndex)
  end
  if stage == "support" then return convert(ai, "iron_chain", 2, true, cuipoIndex) end
  if stage == "setup" and ai.player:isWounded() then return convert(ai, "peach", 4, false, cuipoIndex) end
  if stage == "delayed" then return convert(ai, "supply_shortage", 2, true, cuipoIndex) end
end

function M.slash(ai)
  return convert(ai, "slash", 3, true)
end

function M.response(ai, pattern)
  return Cards.respond(ai, pattern) or convert(ai, pattern, ai.player.hp <= 1 and 6 or 4, false)
end

function M.nullification(ai, target, effect)
  local card = effect.card
  if not ai:isFriend(target) or not Cards.isHarmful(card) then return end
  if Removal.isCard(card) and (not ai:isEnemy(effect.from) or #target:getCardIds("e") + target:getHandcardNum() == 0) then
    return
  end
  local reply = Cards.respond(ai, "nullification")
    or convert(ai, "nullification", target.hp <= 1 and card.is_damage_card and 4 or 3, false)
  if reply and card.is_damage_card and card.trueName ~= "duel" and card.trueName ~= "collateral"
    and target == ai.player and Damage.acceptIncoming(ai, effect, Reactions.responseCost(ai, reply)) then
    return ""
  end
  return reply
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
