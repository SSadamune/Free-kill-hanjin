-- 敕令（汉晋版）
--
-- 牌面：出牌阶段，对所有未确定势力的角色使用。目标角色各选择一项：
-- 1.明置一张武将牌并摸一张牌；2.弃置一张装备牌；3.失去1点体力。
-- 此牌置入弃牌堆的回合结束时：若此牌未触发效果，未确定势力的角色执行此牌的效果；
-- 若所有角色均确定势力，此牌移出游戏，当前回合角色获得“诏书”。
--
-- 结算按实体牌逐张跟踪：本回合置入弃牌堆的【敕令】实体留下带“-turn”后缀的
-- 牌标记，回合结束时只检查仍在弃牌堆的实体。先补未触发过效果的实体，再核对
-- 全场势力；两段都在“回合结束时”结算，不在使用结算中提前处理。
local skill = fk.CreateSkill {
  name = "qiao__imperial_order_skill",
}

local H = require "packages.hegemony.util"

local CARD = "qiao__imperial_order"
-- 引擎在回合结束时统一清理带“-turn”后缀的牌标记。
local ENTERED = "qiao__imperial_order-entered-turn"
local TRIGGERED = "qiao__imperial_order-triggered-turn"

-- 回合结束时的优先级：0 对应游戏规则层，晚于默认优先级 1 的“回合结束时”技能。
-- 与【调虎离山】的明确挂点：其“角色移回／牌移回”必须排在更后（更低的优先级或
-- 回合事件退出函数），以保持规则 FAQ 的顺序：
-- 回合结束时技能 → 敕令 → 角色移回 → 牌移回 → 每轮结束时。
local TURN_END_PRIORITY = 0

--- 弃置选项的真实限制：只能弃置装备牌（手牌或装备区中的装备牌）。
local DISCARD_PATTERN = ".|.|.|.|.|equip"

local function doImperialOrder(room, target)
  local all_choices = { "imperial_order_reveal", "imperial_order_discard", "loseHp" }
  local choices = table.clone(all_choices)
  if target.hp < 1 then table.remove(choices) end
  if table.every(target:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card.type ~= Card.TypeEquip or target:prohibitDiscard(card)
  end) then
    table.remove(choices, 2) -- 没有可弃置的装备牌
  end
  if (target.general ~= "anjiang" or target:prohibitReveal())
    and (target.deputyGeneral ~= "anjiang" or target:prohibitReveal(true)) then
    table.remove(choices, 1) -- 没有暗置武将牌或不能明置
  end
  if #choices == 0 then return false end
  local choice = room:askToChoice(target, {
    choices = choices,
    skill_name = skill.name,
    all_choices = all_choices,
  })
  if choice == "imperial_order_reveal" then
    H.askToRevealGenerals(target, {
      skill_name = skill.name,
      revealAll = false,
      cancelable = false,
    })
    target:drawCards(1, skill.name)
  elseif choice == "imperial_order_discard" then
    room:askToDiscard(target, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = DISCARD_PATTERN,
      skill_name = skill.name,
      prompt = "#qiao__imperial_order-discard",
      cancelable = false,
    })
  else
    room:loseHp(target, 1, skill.name)
  end
end

--- 按实际生效记录“已触发效果”：卡牌效果开始结算（on_effect）时给实体打标记。
--- 不用移动原因（ReasonUse）推断，无懈可击抵消后不会执行到 on_effect。
local function markTriggered(room, card)
  if card == nil then return end
  for _, id in ipairs(Card:getIdList(card)) do
    local real = Fk:getCardById(id)
    if real ~= nil and real.name == CARD then
      room:setCardMark(real, TRIGGERED, 1)
    end
  end
end

skill:addEffect("cardskill", {
  prompt = "#qiao__imperial_order_skill",
  can_use = Util.CanUseFixedTarget,
  -- 牌面为“对所有未确定势力的角色使用”：固定目标为全场未确定势力角色，
  -- 因此使用时不进入逐个选目标，也不因牌位未标 multiple_targets 而无法使用。
  fix_targets = function(self, player, selected, card)
    local room = Fk:currentRoom()
    if room == nil then return nil end
    return table.filter(room.alive_players, function(p)
      return p.kingdom == "unknown" and not p:isRemoved()
    end)
  end,
  mod_target_filter = function(self, player, to_select)
    return to_select.kingdom == "unknown"
  end,
  on_effect = function(self, room, effect)
    markTriggered(room, effect.use and effect.use.card)
    doImperialOrder(room, effect.to)
  end,
})

--- 调虎离山「视为不存在」的挂点：该状态接入后，此查询也应排除移出期间的角色。
local function isPresent(player)
  return player ~= nil and not player.dead and not player:isRemoved()
end

local function presentUndetermined(room)
  local result = {}
  for _, player in ipairs(room.alive_players) do
    if player.kingdom == "unknown" and isPresent(player) then
      table.insert(result, player)
    end
  end
  return result
end

local function allKingdomsKnown(room)
  return #presentUndetermined(room) == 0
end

--- 令 holder 获得“诏书”（特殊标记，唯一指示物）。
--- 诏书持有者由 qiao_generals 的公共 util 维护（君刘协的初平或【敕令】均可取得）；
--- 已有诏书时不重复建立，接口缺失（其他模式未加载该包）时安全跳过。
local function grantZhaoshu(room, holder)
  if room == nil or holder == nil then return false end
  local ok, P = pcall(require, "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han")
  if not ok or type(P) ~= "table" or type(P.grant) ~= "function" then return false end
  return P.grant(room, holder) == true
end

local function trackedCards(room)
  local result = {}
  for _, id in ipairs(room.discard_pile or {}) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.name == CARD and card:getMark(ENTERED) > 0 then
      table.insert(result, card)
    end
  end
  return result
end

local function settleCard(room, card)
  -- 前段：未触发过效果（本回合不是因使用进入弃牌堆）的实体，先补效果。
  if card:getMark(TRIGGERED) == 0 then
    for _, target in ipairs(presentUndetermined(room)) do
      doImperialOrder(room, target)
    end
  end
  -- 后段：全场势力均已确定时，本实体移出游戏，当前回合角色获得诏书。
  if not allKingdomsKnown(room) then return end
  if room:getCardArea(card) ~= Card.DiscardPile then return end
  room:sendLog { type = "#ImperialOrderRemoved", card = { card.id } }
  room:moveCardTo(card, Card.Void, nil, fk.ReasonJustMove, skill.name, nil, true)
  grantZhaoshu(room, room.current)
end

local function settleTurnEnd(room)
  for _, card in ipairs(trackedCards(room)) do
    if room:getCardArea(card) == Card.DiscardPile then
      settleCard(room, card)
    end
  end
end

-- 实体跟踪：按 AfterCardsMove 的实际结果记录“本回合进入了弃牌堆”的实体。
-- “已触发过效果”由卡牌效果开始结算时（on_effect）单独记录，不按移动原因推断。
skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player.seat ~= 1 then return false end
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card ~= nil and card.name == CARD then return true end
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card ~= nil and card.name == CARD
            and room:getCardArea(info.cardId) == Card.DiscardPile then
            room:setCardMark(card, ENTERED, 1)
          end
        end
      end
    end
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  priority = TURN_END_PRIORITY,
  can_trigger = function(self, event, target, player)
    local room = player.room
    return player == room.alive_players[1] and #trackedCards(room) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    settleTurnEnd(player.room)
  end,
})

Fk:loadTranslationTable {
  ["qiao__imperial_order_skill"] = "敕令",
  ["#qiao__imperial_order_skill"] = "所有没有势力的角色选择：1.明置一张武将牌，摸一张牌；"
    .. "2.弃置一张装备牌；3.失去1点体力",
  ["#qiao__imperial_order-discard"] = "请选择一张装备牌弃置",
  ["#ImperialOrderRemoved"] = "【敕令】移出游戏",
}

return skill
