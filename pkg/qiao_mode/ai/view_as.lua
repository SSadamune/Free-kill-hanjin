local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Reactions = require "packages.qiao.pkg.qiao_mode.ai.damage_reactions"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"

local M = {}

local wusheng = "qiao__skill_shu002_1"
local longdan = "qiao__skill_shu005_1"
local wuku = "qiao__skill_jin006_3"
local xiewei, dianjun = "qiao__skill_qun139_1", "qiao__skill_shu054_1"
local tieji, gufen = "qiao__skill_wu027_1", "qiao__skill_shu091_2"
local converters = {
  slash = { wusheng, longdan, wuku, xiewei, dianjun },
  dismantlement = { "qiao__skill_wu002_1" },
  supply_shortage = { "qiao__skill_wei010_1" },
  jink = { "qiao__skill_wei007_1", longdan, wuku, xiewei },
  peach = { longdan, "qiao__skill_qun001_1", wuku },
  nullification = { "qiao__skill_shu011_3", "qiao__retinue_skill_bazhenbing_viewas", wuku },
  iron_chain = { "qiao__skill_shu010_1" },
  fire_attack = { "qiao__skill_shu011_2" },
  duel = { "qiao__qun_cards_state", wuku },
  unexpectation = { "qiao__skill_jin006_2", wuku },
}

local function targetedReply(ai, card, cost, skill)
  local function score(target)
    if card.trueName == "dismantlement" and cost > 2 then
      local payoff = Removal.effectValue(ai, card, target)
      if not payoff or payoff < 5 or payoff <= cost + 0.5 then return end
    end
    local value = Cards.scoreTarget(ai, card, target)
    if value and skill == dianjun then
      local damage = Damage.cardAmount(card, nil, ai.player)
      if damage < target.hp + target.shield or target:getHandcardNum() > 2 then return end
    end
    return value
  end
  local fixed = card:getFixedTargets(ai.player, ai.handler.extra_data)
  if fixed and (#fixed == 0 or not table.every(fixed, function(target) return score(target) ~= nil end)) then return "" end
  local targetLimit = card.trueName == "slash" and ai.player:getMark("qiao_wu012_tianyi_win-turn") > 0 and 2 or 1
  if skill == tieji then targetLimit = 2 end
  if card.trueName == "iron_chain" then targetLimit = 2 end
  return Requests.targets(ai, score, targetLimit)
end

local function convert(ai, result, budget, useTarget, cuipoIndex)
  local enabled = ai:getEnabledSkills()
  for _, name in ipairs(converters[result]) do
    if table.contains(enabled, name) and (name ~= dianjun or ai.player.hp >= 3) then
      ai:selectSkill(name, true)
      if name == xiewei then ai.handler:updateInteraction(result) end
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
          local reply = useTarget and targetedReply(ai, card, cost, name) or Requests.reply(ai)
          if reply ~= "" then return reply end
        end
        ai:unSelectAllTargets()
        ai:selectCard(id, false)
      end
      ai:unSelectAll()
    end
  end
end

local function ironSpine(ai, cuipoIndex)
  if not table.contains(ai:getEnabledSkills(), tieji) then return end
  ai:selectSkill(tieji, true)
  if Cost.select(ai, 2, 5) then
    local card = ai.handler:getUsingCard()
    if card and (not cuipoIndex or Cards.matchesCuipo(ai, card, cuipoIndex)) then
      local reply = targetedReply(ai, card, 5, tieji)
      if reply ~= "" and (#ai:getSelectedTargets() >= 2 or
        table.find(ai:getSelectedTargets(), function(to)
          return to.hp + to.shield <= 1 or Cost.effectable(to, "qiao__vine_skill")
        end)) then return reply end
    end
  end
  ai:unSelectAll()
end

local function wine(ai, dying)
  local player = ai.player
  local useful
  if not dying then
    local plan = Slash.plan(ai, { safe = Cards.safeDamage })
    useful = plan.free + math.min(plan.normal, plan.limit) > 0
    if not useful then return end
  end
  local enabled = ai:getEnabledSkills()
  if table.contains(enabled, gufen) then
    ai:selectSkill(gufen, true)
    if Cost.select(ai, 1, dying and math.huge or 3) then
      local card = ai.handler:getUsingCard()
      if card and card.trueName == "analeptic" then
        local reply = Requests.reply(ai)
        if reply ~= "" then return reply end
      end
    end
    ai:unSelectAll()
  end
  for _, name in ipairs({ "qiao__skill_wu027_2", "qiao__chunyi_other&" }) do
    if table.contains(enabled, name) then
      local mark
      for _, general in ipairs(Ci.cards(player)) do
        if Fk.generals[general].maxHp <= 3 then mark = general; break end
      end
      if dying and not mark then
        for _, entry in ipairs({ "yinyangfish", "vanguard", "companion" }) do
          if player:getMark("@!!" .. entry) > 0 then mark = "@!!" .. entry; break end
        end
        mark = mark or Ci.cards(player)[1]
      end
      if mark then
        ai:selectSkill(name, true)
        ai.handler:updateInteraction(mark)
        local reply = Requests.reply(ai)
        if reply ~= "" then return reply end
        ai:unSelectAll()
      end
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

function M.fiveElements(ai)
  local skill = "qiao__five_elements_fan_skill"
  if not table.contains(ai:getEnabledSkills(), skill) then return end
  ai:selectSkill(skill, true)
  for _, name in ipairs({ "qiao__fire__slash", "qiao__thunder__slash", "qiao__ice__slash" }) do
    ai.handler:updateInteraction(name)
    local enabled = ai:getEnabledCards()
    table.sort(enabled)
    for _, id in ipairs(enabled) do
      ai:selectCard(id, true)
      local card, original = ai.handler:getUsingCard(), Fk:getCardById(id)
      if card then
        local previous = original:getAvailableTargets(ai.player, ai.handler.extra_data)
        local function outcome(slash, target)
          return Damage.assess(ai, target, Damage.cardAmount(slash, nil, ai.player), Damage.cardNature(slash),
            { source = ai.player, card = slash })
        end
        local reply = Requests.targets(ai, function(target)
          if not ai:isEnemy(target) then return end
          local converted = outcome(card, target)
          local old = table.contains(previous, target) and outcome(original, target)
          if Damage.worth(converted) and (not old or not Damage.worth(old)
            or Damage.value(converted) >= Damage.value(old) + 2) then
            return ai:hostileScore(target, Damage.value(converted))
          end
        end)
        if reply ~= "" then return reply end
      end
      ai:unSelectAllTargets()
      ai:selectCard(id, false)
    end
  end
  ai:unSelectAll()
end

function M.play(ai, stage, cuipoIndex)
  if stage == "disrupt" then return convert(ai, "dismantlement", 7, true, cuipoIndex) end
  if stage == "damage" then
    return convert(ai, "slash", 3, true, cuipoIndex)
      or ironSpine(ai, cuipoIndex)
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
  return convert(ai, "slash", 3, true) or ironSpine(ai)
end

function M.wine(ai) return wine(ai, false) end

local function keshou(ai, name, budget)
  local skill = "qiao__skill_wu019_2"
  if ai.command ~= "AskForUseCard" or not table.contains(ai:getEnabledSkills(), skill) then return end
  ai:selectSkill(skill, true)
  ai.handler:updateInteraction(name)
  if Cost.select(ai, 2, budget) then
    local card = ai.handler:getUsingCard()
    if card and card.name == name then
      local reply = Requests.reply(ai)
      if reply ~= "" then return reply end
    end
  end
  ai:unSelectAll()
end

function M.response(ai, pattern)
  local budget = ai.player.hp <= 1 and 6 or 4
  return Cards.respond(ai, pattern) or convert(ai, pattern, budget, false)
    or (pattern == "jink" and keshou(ai, "qiao__jink", budget))
end

function M.nullification(ai, target, effect)
  local card = effect.card
  if not ai:isFriend(target) or not Cards.isHarmful(card) then return end
  if Removal.isCard(card) and (not ai:isEnemy(effect.from) or #target:getCardIds("e") + target:getHandcardNum() == 0) then
    return
  end
  local budget = target.hp <= 1 and card.is_damage_card and 5 or 3
  local reply = Cards.respond(ai, "nullification") or convert(ai, "nullification", math.min(4, budget), false)
    or keshou(ai, "qiao__nullification", budget)
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
  return Cards.respond(ai, data[2]) or convert(ai, "peach", 5, false)
    or (target == ai.player and data[2]:find("analeptic", 1, true) and wine(ai, true)) or ""
end

return M
