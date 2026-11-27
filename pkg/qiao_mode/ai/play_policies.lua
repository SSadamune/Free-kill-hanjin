local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Request = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Minsi = require "packages.qiao.pkg.qiao_generals.util.minsi"
local Heg = require "packages.hegemony.util"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"

local M = {}
local play = {}

local function spareWeapon(ai, id)
  return ai.room:getCardArea(id) == Card.PlayerHand and Fk:getCardById(id).sub_type == Card.SubtypeWeapon
    and not ai.player:prohibitDiscard(id) and Cost.value(ai, id) <= 2
end

function M.minsi(ai)
  local budget = ai.personality == "draw" and 3.5 or 3
  local points = { [0] = { benefit = 0, cards = {} } }
  local enabled = ai:getEnabledCards()
  table.sort(enabled)
  for _, id in ipairs(enabled) do
    local value, point = Cost.value(ai, id), Minsi.pointOf(id)
    if value <= budget and point > 0 and point <= Minsi.TARGET then
      for sum = Minsi.TARGET, point, -1 do
        local previous = points[sum - point]
        if previous then
          local benefit = previous.benefit + 4 - value
          if not points[sum] or benefit > points[sum].benefit then
            local cards = table.simpleClone(previous.cards)
            table.insert(cards, id)
            points[sum] = { benefit = benefit, cards = cards }
          end
        end
      end
    end
  end
  local best = points[Minsi.TARGET]
  if not best then return "" end
  for _, id in ipairs(best.cards) do
    if Cost.value(ai, id) > budget or not table.contains(ai:getEnabledCards(), id) then return "" end
    ai:selectCard(id, true)
  end
  return Request.reply(ai)
end

play.qiao__skill_han007_1 = M.minsi

function play.qiao__skill_wu004_1(ai)
  -- Losing HP is worthwhile here because the real HpLost event also triggers
  -- Zhaxiang. Recheck the skill on this player, even for granted copies.
  if Cost.zhaxiangTrade(ai.player) then return Request.reply(ai) end
end

function play.qiao__skill_wei012_1(ai)
  local player = ai.player
  local weapon = table.find(player:getCardIds("h"), function(id) return spareWeapon(ai, id) end)
  local combo = Cost.zhaxiangTrade(player)
  if not weapon and player.hp < 3 then return end
  ai.handler:updateInteraction((weapon and not combo) and "#qiao__skill_wei012_1-discard" or "#qiao__skill_wei012_1-hp")
  return Request.targets(ai, function(target)
    if combo or target.hp + target.shield == 1 then return ai:hostileScore(target, 20 - target.hp) end
  end)
end

function play.qiao__skill_qun013_2(ai)
  local allies = #table.filter(ai.room:getPresentPlayers(), function(target)
    return target ~= ai.player and ai:isFriend(target)
  end)
  if allies >= 2 or (allies == 1 and ai.player.hp == 1) then return Request.reply(ai) end
end

function play.qiao__skill_jin013_2(ai)
  local previous
  for _, id in ipairs(ai.player:getTableMark("qiao_jin013_2_targets")) do
    local old = ai.room:getPlayerById(id)
    if ai:isEnemy(old) and old.chained then
      previous = old
      break
    end
  end
  local oldScore = previous and ai:hostileScore(previous, previous:getHandcardNum())
  return Request.targets(ai, function(target)
    local score = ai:hostileScore(target, target:getHandcardNum())
    if score and (not previous or (ai:attitude(target) < ai:attitude(previous) and score > oldScore)) then
      return score
    end
  end)
end

function play.qiao__skill_qun018_1(ai)
  if Cost.select(ai, 1, 2) then
    return Request.targets(ai, function(target)
      if not target:isNude() then return ai:hostileScore(target, 20 - target.hp) end
    end)
  end
end

local function tryCardAndTarget(ai, qualifies, score)
  local enabled = ai:getEnabledCards()
  table.sort(enabled)
  for _, id in ipairs(enabled) do
    if qualifies(id) then
      ai:selectCard(id, true)
      local reply = Request.targets(ai, score)
      if reply ~= "" then return reply end
      ai:unSelectAllTargets()
      ai:selectCard(id, false)
    end
  end
end

function play.qiao__skill_wu015a_1(ai)
  local player = ai.player
  return tryCardAndTarget(ai, function(id)
    if ai.room:getCardArea(id) == Card.PlayerHand then return true end
    local card = Fk:getCardById(id)
    -- Preserve our slot coverage while letting Xiaoji pay back the move.
    return Cost.effectable(player, "qiao__skill_wu008_2")
      and card.sub_type == Card.SubtypeWeapon and #player:getEquipments(Card.SubtypeWeapon) > 1
  end, function(target)
    if ai:isFriend(target) then return 20 - target.hp end
  end)
end

function play.qiao__skill_wu008_1(ai)
  local player = ai.player
  local function benefit(target)
    if ai:isFriend(target) and target.hp ~= player.hp then
      local lower = player.hp < target.hp and player or target
      if lower:isWounded() then return 20 - lower.hp end
    end
  end
  ai.handler:updateInteraction("#qiao__skill_wu008_1-place")
  local reply = tryCardAndTarget(ai, function(id) return ai.room:getCardArea(id) == Card.PlayerHand end, benefit)
  if reply then return reply end
  ai.handler:updateInteraction("#qiao__skill_wu008_1-discard")
  if Cost.discard(ai, 1, 2) then return Request.targets(ai, benefit) end
end

function play.qiao__skill_qun007_2(ai)
  local outcome = Damage.luanwu(ai)
  if Damage.worth(outcome) and (outcome.enemyDying > 0 or outcome.enemies >= outcome.friends + outcome.unknown + 2) then
    return Request.reply(ai)
  end
end

function play.qiao__retinue_skill_qingzhou_jingrui(ai)
  return Request.targets(ai, function(target) return ai:hostileScore(target, 20 - target.hp) end)
end

function M.alliance(ai, cooperation)
  local name = "qiao__alliance"
  if not ai.player:isFakeSkill(name) and not ai.player:hasSkill(name) then return end
  local handler = ai.handler
  if not handler:skillButtonValidity(name) then return end

  -- The mode grants the public rule action as a fake skill. The upstream AI
  -- dashboard omits fake buttons, but its native handler can select it directly.
  handler:selectSkill(name, { selected = true })
  local material, cost = Cost.cheapest(ai, function(id) return ai.room:getCardArea(id) == Card.PlayerHand end)
  if material and cost <= (cooperation and 3 or 1) then
    ai:selectCard(material, true)
    local reply = Request.targets(ai, function(target)
      if not ai:isEnemy(target) or target:isHandAreaSealed()
        or not Heg.compareKingdomWith(target, ai.player, true) then return end
      local attitude = ai:attitude(target)
      if cooperation and attitude <= 0 then return end
      local benefit = cooperation and (2.5 + 2.5 * attitude) or 1.25
      if benefit > cost then return benefit - cost + 10 * attitude end
    end)
    if reply ~= "" then return reply end
  end
  handler:selectSkill(name, { selected = false })
end

function M.tianyiCard(ai, ids, optional)
  local best, rank, price
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id)
    local value = Cost.value(ai, id)
    if (not optional or (card.trueName ~= "slash" and card.number >= 12 and value <= 5))
      and (not rank or card.number > rank or (card.number == rank
        and (value < price or (value == price and id < best)))) then
      best, rank, price = id, card.number, value
    end
  end
  return best
end

function play.qiao__skill_wu012_1(ai)
  if not M.tianyiCard(ai, ai.player:getCardIds("h"), true) then return end
  local near = Slash.plan(ai, { safe = Cards.safeDamage })
  local far = Slash.plan(ai, { far = true, safe = Cards.safeDamage })
  if far.normal + far.free < 2 or (far.normal == near.normal and far.free == near.free
    and near.limit >= near.normal) then return end
  return Request.targets(ai, function(target)
    local count = target:getHandcardNum()
    if count > 0 and count <= 2 then return ai:hostileScore(target, 5 - count) end
  end)
end

function play.qiao__retinue_skill_lujiang_shangjia(ai)
  if ai.player:getHandcardNum() < #ai.player:getCardIds("e") then return Request.reply(ai) end
end

function play.qiao__skill_wu001_1(ai)
  local budget = ai.personality == "draw" and 3 or 2
  for _ = 1, ai.player.maxHp do
    if not Cost.discard(ai, 1, budget, true) then break end
  end
  return Request.reply(ai)
end

function M.yinghun(ai)
  local count = ai.player:getLostHp()
  if count < 2 then return "" end
  ai.handler:updateInteraction("#qiao__skill_wu009_1-draw:::" .. count)
  local reply = Request.targets(ai, function(target)
    if ai:isFriend(target) then return 20 - target:getHandcardNum() end
  end)
  if reply ~= "" then return reply end
  ai.handler:updateInteraction("#qiao__skill_wu009_1-discard:::" .. count)
  return Request.targets(ai, function(target)
    local cards = target:getHandcardNum() + #target:getCardIds("e")
    if cards >= count - 1 then return ai:hostileScore(target, 20 - cards) end
  end)
end

local stages = {
  qiao__skill_han007_1 = "draw", -- 敏思
  qiao__skill_wu001_1 = "draw", -- 制衡
  qiao__skill_wu004_1 = "draw", -- 苦肉与诈降
  qiao__skill_qun013_2 = "draw", -- 雄异
  qiao__retinue_skill_lujiang_shangjia = "draw",
  qiao__skill_wu008_1 = "support", -- 结姻
  qiao__skill_wu015a_1 = "support", -- 直谏
  qiao__skill_jin013_2 = "disrupt", -- 克清
  qiao__skill_qun018_1 = "disrupt", -- 祸水
  qiao__skill_wu012_1 = "attack_prep", -- 天义
  qiao__skill_wei012_1 = "damage", -- 强袭
  qiao__skill_qun007_2 = "damage", -- 乱武
  qiao__retinue_skill_qingzhou_jingrui = "damage",
}

function M.play(ai, name, stage)
  local action = play[name]
  if not action or stages[name] ~= stage then return end
  ai:selectSkill(name, true)
  local reply = action(ai)
  if reply and reply ~= "" then return reply end
  ai:unSelectAll()
end

return M
