-- 四海归平（晋势力锦囊）：普通锦囊，仅对自己使用。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 四海归平」。
--   * 只结束本次出牌阶段的自由用牌入口（ServerPlayer:endPlayPhase），
--     当前锦囊及其后的阶段流程照常继续。
--   * 按本出牌阶段实例（GameEvent.Phase）追踪，从弃牌堆选择本阶段置入且此刻
--     仍在弃牌堆的实体牌，每种标准花色各一张；同花色多张时由用牌者选择，
--     无对应花色略过。处理区中的此牌、已被改至游戏外的势力锦囊都不在其中。
--   * 用牌时已确定为晋势力才继续：可将本次获得且仍持有的牌分给其他晋势力
--     角色（每名一张）；随后无论是否分出，都按座次询问当前场上每名晋势力
--     角色是否使用一张实体牌，走真实用牌入口并只使用一次，沿用牌本身的
--     目标规则，出杀次数按公共效果用牌规则处理。
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"
local FreeUse = require "packages.qiao.pkg.qiao_mode.rules.free_use"

local skill = fk.CreateSkill {
  name = "qiao__sihai_guiping_skill",
}

local SUITS = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
local SUIT_LABEL = {
  [Card.Spade] = "♠",
  [Card.Heart] = "♥",
  [Card.Club] = "♣",
  [Card.Diamond] = "♦",
}

--- 本出牌阶段实例中实际置入弃牌堆、且此刻仍在弃牌堆的实体牌。
local function phaseDiscardedCards(room)
  -- getEventsOfScope 以当前事件所属的 GameEvent.Phase 实例为范围起点，
  -- 因此只统计这一阶段（含阶段内插入结算）的移动记录。
  local events = room.logic:getEventsOfScope(GameEvent.MoveCards, math.huge,
    function() return true end, Player.HistoryPhase)
  local seen, ids = {}, {}
  for _, event in ipairs(events) do
    for _, move in ipairs(event.data or {}) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local id = info.cardId
          if not seen[id] then
            seen[id] = true
            if room:getCardArea(id) == Card.DiscardPile then
              table.insert(ids, id)
            end
          end
        end
      end
    end
  end
  return ids
end

--- 每种标准花色各取一张；同花色多张由用牌者选择。
local function chooseBySuit(room, player, candidates)
  local bySuit = {}
  for _, id in ipairs(candidates) do
    local card = Fk:getCardById(id, true)
    local suit = card and card.suit
    if suit ~= nil then
      bySuit[suit] = bySuit[suit] or {}
      if not table.contains(bySuit[suit], id) then table.insert(bySuit[suit], id) end
    end
  end
  local picks = {}
  for _, suit in ipairs(SUITS) do
    local list = bySuit[suit]
    if list ~= nil and #list > 0 then
      if #list == 1 then
        table.insert(picks, list[1])
      else
        -- 走引擎承认的 expand_pile 入口，弃牌堆中的候选可在客户端真实选取。
        local _, chosen = room:askToChooseCardsAndPlayers(player, {
          min_num = 0,
          max_num = 0,
          min_card_num = 1,
          max_card_num = 1,
          targets = {},
          pattern = ".",
          skill_name = skill.name,
          prompt = "#qiao__sihai_guiping-suit:::" .. (SUIT_LABEL[suit] or ""),
          cancelable = false,
          expand_pile = list,
        })
        local id = chosen and chosen[1]
        if id ~= nil and table.contains(list, id) and room:getCardArea(id) == Card.DiscardPile then
          table.insert(picks, id)
        end
      end
    end
  end
  return picks
end

local function isJin(player)
  return player ~= nil and FactionTricks.isConfirmedKingdom(player, "jin")
end

local function aliveJinPlayers(room, exclude)
  local ret = {}
  for _, player in ipairs(room:getAlivePlayers()) do
    if player ~= exclude and player:isAlive() and not player:isRemoved() and isJin(player) then
      table.insert(ret, player)
    end
  end
  return ret
end

skill:addEffect("cardskill", {
  prompt = "#qiao__sihai_guiping_skill",
  can_use = Util.CanUseToSelf,
  -- 仅对自己使用：固定目标为使用者本人，需允许自身通过目标筛选，
  -- 否则真实用牌请求会因没有合法目标而跳过结算。
  mod_target_filter = Util.TrueFunc,
  on_effect = function(self, room, effect)
    local player, target = effect.from, effect.to
    -- 仅对自己使用。
    if player == nil or player.dead or target ~= player then return end

    -- 只结束本阶段的自由用牌入口；当前牌继续结算。
    player:endPlayPhase()

    -- 本阶段实际进过弃牌堆、且仍在弃牌堆的牌，每标准花色各取一张。
    local picks = chooseBySuit(room, player, phaseDiscardedCards(room))
    if #picks > 0 and not player.dead then
      room:moveCardTo(picks, Card.PlayerHand, player, fk.ReasonPrey, skill.name,
        nil, true, player)
    end

    -- 用牌时已确定为晋，才执行后续两项。
    if not FactionTricks.useConfirmed(effect.extra_data) then return end
    if player.dead or player:isRemoved() then return end

    local held = table.filter(picks, function(id)
      return room:getCardArea(id) == Card.PlayerHand
        and room:getCardOwner(id) == player
    end)
    local others = aliveJinPlayers(room, player)
    if #held > 0 and #others > 0 then
      room:askToYiji(player, {
        targets = others,
        cards = held,
        single_max = 1,
        min_num = 0,
        skill_name = skill.name,
        prompt = "#qiao__sihai_guiping-give",
        cancelable = true,
      })
    end

    -- 即使一张也没分出，仍按座次询问所有当前晋势力角色（含仍为晋的使用者）。
    local jin = table.filter(room:getAlivePlayers(), function(other)
      return other:isAlive() and not other:isRemoved() and isJin(other)
    end)
    room:sortByAction(jin)
    for _, other in ipairs(jin) do
      if not other.dead and not other:isRemoved() then
        -- 普通可选用牌请求（含已确认合法的转化牌）；请求声明 not_passive，
        -- 不提供【闪】【无懈可击】等被动牌。服务端公共入口按本次请求复核
        -- 后返回待执行数据，选择后只执行一次。
        local use = FreeUse.askToUseCard(other, {
          pattern = ".",
          skill_name = skill.name,
          prompt = "#qiao__sihai_guiping-use",
          cancelable = true,
          extra_data = { bypass_times = false, extraUse = false },
        })
        if use ~= nil then room:useCard(use) end
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "四海归平",
  ["#qiao__sihai_guiping_skill"] = "四海归平：结束自由出牌入口并按花色回收本阶段弃牌",
  ["#qiao__sihai_guiping-suit"] = "四海归平：选择一张%arg花色的牌",
  ["#qiao__sihai_guiping-give"] = "四海归平：可将本次获得的牌交给其他晋势力角色",
  ["#qiao__sihai_guiping-use"] = "四海归平：你可以使用一张牌",
}

return skill
