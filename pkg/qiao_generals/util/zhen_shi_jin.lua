-- JIN006 杜预、JIN022B 牵弘的共享状态。
-- 三陈“本回合已选目标”与“本阶段已用/已复原次数”用公开 player mark 保存，
-- 破竹客户端据此计算次数；武库只记录公开的上一张基本/普通锦囊牌名，
-- 不把服务端历史或私有字段交给客户端。
local U = {}

U.SANCHEN_TARGETS = "qiao_jin006_1_targets"
U.SANCHEN_PHASE = "qiao_jin006_1_phase"
U.LAST_USE = "qiao_jin006_3_last-turn"
U.RANGE = "qiao_jin022b_range"
U.RANGE_SKILL = "qiao__skill_jin022b_range"
U.CHEN_SKILL = "qiao__skill_jin006_1"

local function clone(value)
  return type(value) == "table" and table.simpleClone(value) or value
end

local function targets(player)
  local value = player:getMark(U.SANCHEN_TARGETS)
  if type(value) ~= "table" then value = {} end
  return clone(value)
end

local function phase(player)
  local value = player:getMark(U.SANCHEN_PHASE)
  if type(value) ~= "table" then value = {} end
  return {
    uses = tonumber(value.uses) or 0,
    restored = tonumber(value.restored) or 0,
  }
end

function U.resetTurn(player)
  player.room:setPlayerMark(player, U.SANCHEN_TARGETS, {})
  player.room:setPlayerMark(player, U.SANCHEN_PHASE, { uses = 0, restored = 0 })
end

function U.resetPhase(player)
  player.room:setPlayerMark(player, U.SANCHEN_PHASE, { uses = 0, restored = 0 })
end

function U.sanChenTargeted(player, target)
  return targets(player)[tostring(target.id)] == true
end

function U.markSanChenTarget(player, target)
  local value = targets(player)
  value[tostring(target.id)] = true
  player.room:setPlayerMark(player, U.SANCHEN_TARGETS, value)
end

function U.sanChenRestored(player)
  return phase(player).restored
end

function U.sanChenRemaining(player)
  local state = phase(player)
  return math.max(0, 1 + state.restored - state.uses)
end

function U.consumeSanChen(player)
  local state = phase(player)
  state.uses = state.uses + 1
  player.room:setPlayerMark(player, U.SANCHEN_PHASE, state)
end

function U.restoreSanChen(player)
  local state = phase(player)
  state.restored = state.restored + 1
  player.room:setPlayerMark(player, U.SANCHEN_PHASE, state)
end

function U.recordUse(player, card)
  -- 保留用牌本身的牌名。引擎的 trueName 会合并属性杀和两种无懈。
  local name = card.name
  local hanjinName = name == "heg__nullification" and "qiao__guozhan__nullification" or "qiao__" .. name
  if Fk.all_card_types[hanjinName] then name = hanjinName end
  player.room:setPlayerMark(player, U.LAST_USE, name)
end

function U.lastUse(player)
  local value = player:getMark(U.LAST_USE)
  return type(value) == "string" and Fk.all_card_types[value] and value or nil
end

function U.isBasicOrNormalTrick(card)
  if card == nil then return false end
  return card.type == Card.TypeBasic
    or (card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick)
end

function U.isTreasure(card)
  return card ~= nil and card.type == Card.TypeEquip
    and card.sub_type == Card.SubtypeTreasure
end

function U.treasureIds(player)
  return table.filter(player:getCardIds("he"), function(id)
    return U.isTreasure(Fk:getCardById(id))
  end)
end

--- 攻击范围内距离最远的其他角色；并列全返回。
function U.farthestInRange(player)
  local best, result = -1, {}
  for _, p in ipairs(player.room:getPresentPlayers()) do
    if p ~= player and not p.dead and not p:isRemoved() and player:inMyAttackRange(p) then
      local distance = player:distanceTo(p)
      if distance > best then
        best = distance
        result = { p }
      elseif distance == best then
        table.insert(result, p)
      end
    end
  end
  return result
end

return U
