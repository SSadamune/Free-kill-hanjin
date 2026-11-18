-- 青龙偃月刀：锁定技，你使用【杀】指定一个目标时，令其不能明置武将牌且
-- 不能使用此【杀】花色的手牌，直到此【杀】结算结束。
--
-- 规则基线：docs/rules/card-deck.md「普通锦囊与装备的审阅结论 · 青龙偃月刀」
-- 及《势备应变牌堆差异》「发动时机改到指定一个目标时」「新版加小潜袭」。
--   * 逐目标在 fk.TargetSpecifying 建立限制，此时目标增减已经处理完毕。
--   * 已经建立的限制不因装备牌离开装备区而消失，故清理放在房间级规则技能，
--     不检查装备者是否仍有此技能。
--   * 只禁止“使用”该花色手牌，不禁止打出/响应或弃置；来牌无标准花色时不建立
--     花色限制（无花色不等于某一种花色）。
local J = require "packages.qiao.pkg.qiao_generals.util.jin_deck"

local skill = fk.CreateSkill {
  name = "qiao__blade_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__blade",
}

Fk:loadTranslationTable {
  ["qiao__blade_skill"] = "青龙偃月刀",
}

--- 房间级静态规则技能。禁止使用按角色标记读取，不依赖装备者是否仍装备此牌，
--- 因此装备牌在本次使用中途离开装备区后，已建立的限制仍持续到结算结束。
local RULE_SKILL = "qiao__blade_rule"
--- 每次使用一个序号：禁明置标记按序号区分来源，花色限制记录也带序号。
local USE_SEQ_TAG = "qiao_blade_use_seq"
--- 花色限制记录：{ { suit = Card.Suit, use = 使用序号 }, ... }
local BANS = "qiao_blade_bans"
--- 禁明置标记前缀；含 -turn，使引擎按临时标记处理，并让 prohibitReveal 识别。
local REVEAL_PREFIX = "RevealProhibited-turn-qiao_blade-"
local PLACES = { "m", "d" }

local function revealKey(seq)
  return REVEAL_PREFIX .. tostring(seq)
end

--- 当前仍适用的被禁花色（去重）。
local function bannedSuits(player)
  local suits = {}
  for _, record in ipairs(player:getTableMark(BANS)) do
    if J.validSuit(record.suit) then
      table.insertIfNeed(suits, record.suit)
    end
  end
  return suits
end

--- 本次使用的牌是否含被禁花色的手牌材料。虚拟牌按实体材料逐张判断；装备区等
--- 非手牌来源不受限制，纯虚拟牌（无实体材料）也不因转化后的花色被禁止。
local function prohibitedFromHand(player, card)
  if player == nil or card == nil then return false end
  local suits = bannedSuits(player)
  if #suits == 0 then return false end
  local hand = player:getCardIds(Player.Hand)
  for _, id in ipairs(Card:getIdList(card)) do
    if table.contains(hand, id) then
      local material = Fk:getCardById(id)
      if material ~= nil and table.contains(suits, material.suit) then
        return true
      end
    end
  end
  return false
end

--- 撤销一次使用建立的全部限制。
local function clearUse(room, seq)
  if room == nil or seq == nil then return end
  local key = revealKey(seq)
  for _, player in ipairs(room.players) do
    if player:getMark(key) ~= 0 then
      room:setPlayerMark(player, key, 0)
    end
    local records = player:getTableMark(BANS)
    local kept = table.filter(records, function(record) return record.use ~= seq end)
    if #kept ~= #records then
      room:setPlayerMark(player, BANS, #kept > 0 and kept or 0)
    end
  end
end

--- 兜底清理：单张牌的使用不会跨过回合结束，回合结束时清掉残留记录。
local function clearAll(room)
  if room == nil then return end
  for _, player in ipairs(room.players) do
    for _, name in ipairs(player:getMarkNames()) do
      if name:startsWith(REVEAL_PREFIX) then
        room:setPlayerMark(player, name, 0)
      end
    end
    if #player:getTableMark(BANS) > 0 then
      room:setPlayerMark(player, BANS, 0)
    end
  end
end

-- 规则骨架在模块加载时创建并登记，使客户端也能按名称安装到房间状态技能。
-- 效果顺序（触发技先于状态技）使主技能成为触发器，禁用规则作为关联状态技随
-- room:addSkill 一起广播。
local ruleSkeleton = fk.CreateSkill { name = RULE_SKILL }

ruleSkeleton:addEffect(fk.CardUseFinished, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and data ~= nil and data.extra_data ~= nil
      and data.extra_data.qiao_blade_use ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    local seq = data.extra_data.qiao_blade_use
    data.extra_data.qiao_blade_use = nil
    clearUse(Fk:currentRoom(), seq)
  end,
})

ruleSkeleton:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player
  end,
  on_refresh = function(self, event, target, player, data)
    clearAll(Fk:currentRoom())
  end,
})

ruleSkeleton:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return prohibitedFromHand(player, card)
  end,
})

local ruleSkill = ruleSkeleton:createSkill()
local function registerRuleSkill(target)
  if target == nil then return end
  Fk.skills[target.name] = Fk.skills[target.name] or target
  for _, related in ipairs(target.related_skills or {}) do
    registerRuleSkill(related)
  end
end
registerRuleSkill(ruleSkill)

local function ensureRuleSkill(room)
  if room == nil then return end
  if not room:hasSkill(ruleSkill.name) then
    room:addSkill(ruleSkill.name)
  end
end

skill:addEffect(fk.TargetSpecifying, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and not data.to.dead and not data.to:isRemoved()
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureRuleSkill(room)
    local use = data.use
    use.extra_data = use.extra_data or {}
    local seq = use.extra_data.qiao_blade_use
    if seq == nil then
      seq = (room:getTag(USE_SEQ_TAG) or 0) + 1
      room:setTag(USE_SEQ_TAG, seq)
      use.extra_data.qiao_blade_use = seq
    end
    local to = data.to
    -- 不能明置：只写本来源（本次使用）的标记，撤销时也只清这一条。
    local key = revealKey(seq)
    local places = to:getMark(key)
    local merged = type(places) == "table" and table.simpleClone(places) or {}
    for _, place in ipairs(PLACES) do table.insertIfNeed(merged, place) end
    room:setPlayerMark(to, key, merged)
    -- 不能使用此【杀】花色的手牌；无标准花色时不建立限制。
    local suit = data.card.suit
    if J.validSuit(suit) then
      local records = to:getTableMark(BANS)
      local exists = table.find(records, function(record)
        return record.suit == suit and record.use == seq
      end)
      if exists == nil then
        table.insert(records, { suit = suit, use = seq })
        room:setPlayerMark(to, BANS, records)
      end
    end
  end,
})

return skill
