-- 洛水之誓（野心家势力锦囊）：延时锦囊，对一名合法角色使用。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 洛水之誓」（e1244ed 裁定）。
--   * 普通情况：由引擎的延时锦囊流程真实进入目标判定区，在判定阶段结算。
--   * 用牌时已确定为野心家且目标为自己：立即进入判定结算，不再进入判定区；
--     其非区间分支按“本回合下一个阶段”判断（出牌阶段自用即按后续弃牌阶段）。
--   * 判定为黑桃 2～9：只看本次生效时目标是否野心家；由该目标选择一名角色，
--     以该目标为来源造成 3 点雷电伤害。原用牌者身份及进入判定区后才转野不影响。
--   * 判定不在该区间：只有本回合确实可改写一个后续阶段时，才把原实体置回目标
--     判定区，并把该阶段替换为判定阶段（不插入额外阶段）；无后续阶段时按共用
--     规则移出游戏。
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"

local skill = fk.CreateSkill {
  name = "qiao__luoshui_zhishi_skill",
}

local JUDGE_PATTERN = ".|2~9|spade"
--- 立即结算的防重入标记（BeforeCardUseEffect 事件 id）。
local IMMEDIATE_TAG = "qiao_luoshui_immediate_use"
--- 立即结算后需要在用牌收尾时清理判定区实体的标记。
local IMMEDIATE_RESULT = "qiao_luoshui_immediate_result"
--- 非区间改写下一个阶段的待办（由 qiao__luoshui_rule 在阶段结束前处理）。
local PENDING_TAG = "qiao_luoshui_pending"

--- 处理区中的此牌实体。
local function processingIds(room, card)
  return room:getSubcardsByRule(card, { Card.Processing })
end

--- 把处理区中的此牌移动到目标区域；虚拟牌保留用具信息。
local function moveOut(room, card, toArea, to, reason)
  local ids = processingIds(room, card)
  if #ids == 0 then return end
  local move = {
    ids = ids,
    toArea = toArea,
    to = to,
    moveReason = reason or fk.ReasonPut,
    skillName = skill.name,
  }
  if card:isVirtual() then
    move.virtualEquip = card
  end
  room:moveCards(move)
end

--- 本回合当前阶段之后的阶段；返回 Turn 数据与该阶段在表内的下标。
local function nextPhaseSlot(room)
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  local data = turn and turn.data
  if data == nil or type(data.phase_table) ~= "table" then return nil end
  local index = (data.phase_index or 0) + 1
  if data.phase_table[index] == nil then return nil end
  return data, index
end

--- 非区间分支：只在处理区保留原实体并登记待办；“置回判定区”与“把下一个
--- 阶段改为判定阶段”都推迟到该阶段准备点（qiao__luoshui_rule 的
--- EventPhaseChanging）执行。返回是否登记成功。
local function beginPendingRewrite(room, card, target)
  local data, index = nextPhaseSlot(room)
  if data == nil then return false end
  local id = card:isVirtual() and card:getEffectiveId() or card.id
  -- 原实体须仍在处理区，才可能按真实移动置回判定区。
  if id == nil or room:getCardArea(id) ~= Card.Processing then return false end
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  if turn == nil then return false end
  local use = current and current:findParent(GameEvent.UseCard, true)
  room:setTag(PENDING_TAG, {
    turn = turn.id,
    index = index,
    target = target.id,
    card = id,
    use = use and use.id or nil,
  })
  return true
end

--- 一次判定结算（立即路径与判定阶段共用）。
local function settle(room, card, target)
  if card == nil or target == nil or target.dead or target:isRemoved() then return end
  local judge = { who = target, reason = skill.name, pattern = JUDGE_PATTERN }
  room:judge(judge)

  -- 命中黑桃 2～9：只有目标在本次生效时为野心家才造成伤害；
  -- 命中但目标不是野心家时，不进入“非区间”的改写阶段分支，按共用处置结束。
  if judge:matchPattern() then
    if FactionTricks.isConfirmedKingdom(target, "wild") then
      local candidates = table.filter(room:getAlivePlayers(), function(player)
        return player:isAlive() and not player:isRemoved()
      end)
      local chosen = candidates[1]
      if #candidates > 1 then
        local tos = room:askToChoosePlayers(target, {
          targets = candidates,
          min_num = 1,
          max_num = 1,
          skill_name = skill.name,
          prompt = "#qiao__luoshui_zhishi-damage",
        })
        chosen = tos and tos[1] or chosen
      end
      if chosen ~= nil then
        room:damage {
          from = target,
          to = chosen,
          card = card,
          damage = 3,
          damageType = Fk:getDamageNature(fk.ThunderDamage) and fk.ThunderDamage
            or fk.NormalDamage,
          skillName = skill.name,
        }
      end
    end
    moveOut(room, card, Card.DiscardPile, nil, fk.ReasonUse)
    return
  end

  -- 非区间：确实可改写一个后续阶段时才置回判定区；否则按共用规则移出游戏。
  if not beginPendingRewrite(room, card, target) then
    moveOut(room, card, Card.DiscardPile, nil, fk.ReasonPut)
  end
end

skill:addEffect("cardskill", {
  prompt = "#qiao__luoshui_zhishi_skill",
  target_num = 1,
  -- cardskill 的默认 targetFilter 恒为 false；接回共用入口后，客户端按同一
  -- mod_target_filter 条件点亮目标。
  target_filter = Util.CardTargetFilter,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= nil and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    return #Fk:currentRoom():getPresentPlayers() > 0
  end,
  on_use = function(self, room, use)
    -- 用牌时记录本次用牌的势力快照；立即结算推迟到目标事件之后。
    FactionTricks.recordUse(use)
  end,
  on_effect = function(self, room, effect)
    -- 判定阶段结算（含被替换出的判定阶段）：真正的判定与后续处理。
    settle(room, effect.card, effect.to)
  end,
  on_nullified = function(self, room, effect)
    -- 被无懈可击抵消：此牌用尽，按共用规则移出游戏。
    moveOut(room, effect.card, Card.DiscardPile, nil, fk.ReasonPut)
  end,
})

-- 已确定为野心家且目标为自己：在目标事件之后、原生延时入判定区之前，
-- 以真实的 CardEffect 走一次完整结算，保留无懈可击与目标无效等原用牌上下文。
-- 若本次已被目标无效或无懈抵消，不进行判定、不造成伤害。
skill:addEffect(fk.BeforeCardUseEffect, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if data == nil or data.from == nil or data.card == nil then return false end
    local entry = data.extra_data and data.extra_data[FactionTricks.USE_KEY]
    if type(entry) ~= "table" or entry.kingdom ~= "wild" or entry.confirmed ~= true then
      return false
    end
    local to = data.tos and data.tos[1]
    if to == nil or to ~= data.from then return false end
    local room = Fk:currentRoom()
    return room:getTag(IMMEDIATE_TAG) ~= event.id
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    room:setTag(IMMEDIATE_TAG, event.id)
    local to = data.tos[1]
    -- 已被目标无效：不判定、不伤害，交由引擎收尾（实体离开处理区时按共用规则移出）。
    if type(data.nullifiedTargets) == "table"
      and table.contains(data.nullifiedTargets, to) then
      return
    end
    room:doCardEffect(CardEffectData:new {
      from = data.from,
      to = to,
      tos = { to },
      subTos = data.subTos,
      card = data.card,
      toCard = data.toCard,
      use = data,
      responseToEvent = data.responseToEvent,
      additionalDamage = data.additionalDamage,
      additionalRecover = data.additionalRecover,
      cardsResponded = data.cardsResponded,
      prohibitedCardNames = data.prohibitedCardNames,
      extra_data = data.extra_data,
    })
    local id = data.card:isVirtual() and data.card:getEffectiveId() or data.card.id
    local pending = room:getTag(PENDING_TAG)
    local keepInJudge = type(pending) == "table" and id ~= nil and pending.card == id
    -- 原生延时流程仍会把处理区中的实体放入判定区；非“待重判”的结果在
    -- CardUseFinished 收尾时清出判定区。
    data.extra_data = data.extra_data or {}
    data.extra_data[IMMEDIATE_RESULT] = keepInJudge
    -- 被无懈抵消等未实际结算时仍是处理区实体：按共用规则移出游戏。
    if id ~= nil and room:getCardArea(id) == Card.Processing then
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonPut, skill.name, nil, true)
    end
  end,
}, { priority = 100 })

-- 立即结算的收尾：非“保留待重判”的结果不应留在判定区（原生延时入区之后）。
skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if data == nil or data.card == nil then return false end
    local extra = data.extra_data
    return type(extra) == "table" and extra[IMMEDIATE_RESULT] ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    local keepInJudge = data.extra_data[IMMEDIATE_RESULT]
    data.extra_data[IMMEDIATE_RESULT] = nil
    if keepInJudge then return end
    local room = Fk:currentRoom()
    local id = data.card:isVirtual() and data.card:getEffectiveId() or data.card.id
    if id ~= nil and room:getCardArea(id) == Card.PlayerJudge then
      room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonPut, skill.name, nil, true)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "洛水之誓",
  ["#qiao__luoshui_zhishi_skill"] = "洛水之誓：选择一名角色。判定为黑桃 2～9 且其为野心家时，其对一名角色造成 3 点雷电伤害",
  ["#qiao__luoshui_zhishi-damage"] = "洛水之誓：选择一名角色，对其造成 3 点雷电伤害",
}

return skill
