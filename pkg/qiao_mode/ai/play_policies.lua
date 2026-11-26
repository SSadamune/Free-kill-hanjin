local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Request = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Minsi = require "packages.qiao.pkg.qiao_generals.util.minsi"

local M = {}
local play = {}

local function preferWeakEnemy(ai, target)
  if ai:isEnemy(target) then return 20 - target.hp end
end

local function spareWeapon(ai, id)
  return ai.room:getCardArea(id) == Card.PlayerHand and Fk:getCardById(id).sub_type == Card.SubtypeWeapon
    and not ai.player:prohibitDiscard(id) and Cost.value(ai, id) <= 2
end

function M.minsi(ai)
  local points = { [0] = { benefit = 0, cards = {} } }
  local enabled = ai:getEnabledCards()
  table.sort(enabled)
  for _, id in ipairs(enabled) do
    local value, point = Cost.value(ai, id), Minsi.pointOf(id)
    if value <= 3 and point > 0 and point <= Minsi.TARGET then
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
    if Cost.value(ai, id) > 3 or not table.contains(ai:getEnabledCards(), id) then return "" end
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
    if combo or target.hp + target.shield == 1 then return preferWeakEnemy(ai, target) end
  end)
end

function play.qiao__skill_qun013_2(ai)
  local allies = #table.filter(ai.room:getPresentPlayers(), function(target)
    return target ~= ai.player and ai:isFriend(target)
  end)
  if allies >= 2 or (allies == 1 and ai.player.hp == 1) then return Request.reply(ai) end
end

function play.qiao__skill_jin013_2(ai)
  for _, id in ipairs(ai.player:getTableMark("qiao_jin013_2_targets")) do
    local old = ai.room:getPlayerById(id)
    if ai:isEnemy(old) and old.chained then return end
  end
  return Request.targets(ai, function(target)
    if ai:isEnemy(target) then return target:getHandcardNum() end
  end)
end

function play.qiao__skill_qun018_1(ai)
  if Cost.select(ai, 1, 2) then
    return Request.targets(ai, function(target)
      if ai:isEnemy(target) and not target:isNude() then return 20 - target.hp end
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
  if Cost.select(ai, 1, 2) then return Request.targets(ai, benefit) end
end

function play.qiao__retinue_skill_qingzhou_jingrui(ai)
  return Request.targets(ai, function(target) return preferWeakEnemy(ai, target) end)
end

function play.qiao__retinue_skill_lujiang_shangjia(ai)
  if ai.player:getHandcardNum() < #ai.player:getCardIds("e") then return Request.reply(ai) end
end

function play.qiao__skill_wu001_1(ai)
  for _ = 1, ai.player.maxHp do
    if not Cost.select(ai, 1, 2) then break end
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
    if ai:isEnemy(target) and cards >= count - 1 then return 20 - cards end
  end)
end

function M.play(ai, name)
  local action = play[name]
  if not action then return end
  ai:selectSkill(name, true)
  local reply = action(ai)
  if reply and reply ~= "" then return reply end
  ai:unSelectAll()
end

return M
