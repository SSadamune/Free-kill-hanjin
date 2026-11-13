-- HAN 翼从 · 西园军
--
-- 规则基线：rules/standard-generals.md 翼从西园军、rulebook/events/phase.md、
-- rulebook/terms/card-op-terms/showCards.md。同势力角色出牌阶段开始时（含
-- 自己），可以选择一名角色的一张手牌；本回合该牌对所有角色可见且持有者
-- 不能使用/打出，其受到伤害后来源获得之。牌离开手牌即清理禁用约束；回合末
-- 清理公开与限制。
local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_xiyuanjun",
}
skill.hanjinImplemented = true

local H = require "packages.hegemony.util"

local VISIBLE_MARK = "hanjin_retinue_xiyuanjun_visible-turn"
-- 同时含 "-turn" 与 "-inhand"：回合末清理，牌离开手牌时立即清理。
local LOCK_MARK = "hanjin_retinue_xiyuanjun_lock-turn-inhand"

---@param player ServerPlayer
---@param target ServerPlayer
---@return boolean
local function sameKingdom(player, target)
  return player == target or H.compareKingdomWith(player, target)
end

--- 把 askToChooseCard 的 Card/ID/数组返回值统一成单个 id。
---@param value any
---@return integer?
local function normalizeCardId(value)
  local ids = Card:getIdList(value)
  return ids[1]
end

--- 虚拟/转化牌是否有任一实体子牌带锁定标记。
---@param card Card
---@return boolean
local function cardLocked(card)
  if card == nil then return false end
  if card:getMark(LOCK_MARK) > 0 then return true end
  for _, id in ipairs(Card:getIdList(card)) do
    local real = Fk:getCardById(id, true)
    if real ~= nil and real:getMark(LOCK_MARK) > 0 then return true end
  end
  return false
end

--- 目标手牌中仍带本技能约束的牌。
---@param target ServerPlayer
---@return integer[]
local function lockedCards(target)
  return table.filter(target:getCardIds(Player.Hand), function(id)
    local card = Fk:getCardById(id, true)
    return card:getMark(LOCK_MARK) > 0
  end)
end

-- 触发条件是“同势力角色的出牌阶段开始”；被选牌角色是“一名角色”，
-- 不要求其与西园军同势力，也不要求当前阶段角色自己有手牌。
skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or player == nil or not player:hasSkill(skill.name) then
      return false
    end
    if target.phase ~= Player.Play or target.dead or target:isRemoved() then
      return false
    end
    if not sameKingdom(player, target) then return false end
    for _, p in ipairs(player.room.alive_players) do
      if not p.dead and not p:isRemoved() and #p:getCardIds(Player.Hand) > 0 then
        return true
      end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_xiyuanjun-invoke::" .. target.id,
    }) then
      return false
    end

    -- 全场有手牌的合法角色均可选，包括敌方角色。
    local candidates = table.filter(room.alive_players, function(p)
      return not p.dead and not p:isRemoved() and #p:getCardIds(Player.Hand) > 0
    end)
    if #candidates == 0 then return false end
    local tos = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = candidates,
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_xiyuanjun-target",
      cancelable = true,
    })
    local to = tos and tos[1]
    if to == nil then return false end

    -- 隐藏选牌；返回值可能是 Card、id 或数组，统一规范化。
    local raw = room:askToChooseCard(player, {
      target = to,
      flag = "h",
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_xiyuanjun-card::" .. to.id,
    })
    local id = normalizeCardId(raw)
    if id == nil or not table.contains(to:getCardIds(Player.Hand), id) then return false end

    event:setCostData(self, { to = to, card = id })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to, id = cost.to, cost.card
    if to == nil or id == nil or to.dead or to:isRemoved() then return end
    if not table.contains(to:getCardIds(Player.Hand), id) then return end

    local card = Fk:getCardById(id, true)
    room:setCardMark(card, VISIBLE_MARK, 1)
    room:setCardMark(card, LOCK_MARK, 1)
  end,
})

-- 公开：所有角色均可看到带标记的牌。
skill:addEffect("visibility", {
  card_visible = function(self, player, card)
    return card:getMark(VISIBLE_MARK) > 0
  end,
})

-- 持有者不能使用或打出该牌；弃置、给予等其他操作不受限。
skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return cardLocked(card)
  end,
  prohibit_response = function(self, player, card)
    return cardLocked(card)
  end,
})

-- 被标记牌的角色受到伤害后，由伤害来源获得该牌；无来源不获得。
skill:addEffect(fk.Damaged, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and data.from ~= nil
      and #lockedCards(target) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = target.room
    local ids = lockedCards(target)
    if #ids == 0 then return end
    local card = Fk:getCardById(ids[1], true)
    room:setCardMark(card, VISIBLE_MARK, 0)
    room:setCardMark(card, LOCK_MARK, 0)
    -- 离开手牌时标记也会由 -inhand 清理；此处显式清理避免残留。
    room:obtainCard(data.from, ids[1], true, fk.ReasonPrey, target, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_xiyuanjun"] = "西园军",
  [":hanjin__retinue_skill_xiyuanjun"] = "与你势力相同的角色出牌阶段开始时，你可以选择一名角色的一张手牌，本回合此牌对所有角色可见且其不能使用或打出之，其受到伤害后来源获得之。",
  ["#hanjin__retinue_skill_xiyuanjun-invoke"] = "西园军：你可以选择一名角色的一张手牌",
  ["#hanjin__retinue_skill_xiyuanjun-target"] = "西园军：选择一名有手牌的角色",
  ["#hanjin__retinue_skill_xiyuanjun-card"] = "西园军：选择 %dest 的一张手牌",
}

return skill
