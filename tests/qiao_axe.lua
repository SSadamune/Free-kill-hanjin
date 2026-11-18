-- 贯石斧：真实结算用例。只有【杀】被【闪】抵消后、由发动者实际弃足两张
-- 其他牌，才令【杀】继续生效；选择无效或移动被取消时不能恢复效果。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local AXE = "qiao__axe"
local AXE_SKILL = "qiao__axe_skill"
local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wu", "wu" }

Testqiao_axe = {
  setup = function()
    local room = support.initQiaoRoom()
    FkTest.runInRoom(function()
      skill_test.installBlankGenerals(room, DEFAULT_KINGDOMS)
      -- 清空发牌，固定“可弃置牌”的数量与归属。
      for _, player in ipairs(room.players) do
        local ids = player:getCardIds("he")
        if #ids > 0 then room:throwCard(ids, "test", player, player) end
      end
    end)
  end,
  tearDown = support.clearRoom,
}

local function p(n) return FkTest.room:getPlayerById(n) end
local function card(name, suit, number)
  return assert(table.find(Fk.cards, function(c)
    return c.name == name and (suit == nil or c.suit == suit)
      and (number == nil or c.number == number)
  end), "missing " .. name)
end

--- 把牌真正放进某名角色的手牌区；返回原牌对象。
local function give(room, player, c)
  if not table.contains(player:getCardIds("h"), c.id) then
    room:obtainCard(player, c.id, true, fk.ReasonJustMove, player, "test")
  end
  return c
end

local function use(room, from, tos, c)
  local data = UseCardData:new { from = from, tos = tos or {}, card = c, extra_data = {} }
  room:useCard(data)
  return data
end

--- 装备贯石斧并给出本次【杀】的费用牌；目标持有【闪】。
local function prepareDodgedSlash(room, owner, target, costs)
  local axe = give(room, owner, card(AXE))
  use(room, owner, { owner }, axe)
  assert(table.contains(owner:getEquipments(), axe.id), "axe was not equipped")
  local slash = give(room, owner, card("qiao__slash", Card.Spade, 5))
  for _, c in ipairs(costs) do give(room, owner, c) end
  local jink = give(room, target, card("qiao__jink", Card.Heart, 2))
  FkTest.setNextReplies(target, { { card = jink.id } })
  return axe, slash, jink
end

--- 本次结算中属于 ids 且已在弃牌堆的牌数。
local function discardedCount(room, ids)
  local count = 0
  for _, id in ipairs(ids) do
    if room:getCardArea(id) == Card.DiscardPile then count = count + 1 end
  end
  return count
end

function Testqiao_axe:testRestoresSlashAfterTwoRealCardsDiscarded()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local first = card("qiao__peach", Card.Heart, 7)
  local second = card("qiao__peach", Card.Heart, 9)
  local hp = target.hp
  local pattern
  FkTest.runInRoom(function()
    local axe, slash = prepareDodgedSlash(room, owner, target, { first, second })
    local original = room.askToDiscard
    room.askToDiscard = function(self, who, params)
      if params.skill_name == AXE_SKILL then pattern = params.pattern end
      return original(self, who, params)
    end
    FkTest.setNextReplies(owner, { FkTest.ReplyDiscard({ first.id, second.id }) })
    use(room, owner, { target }, slash)
    room.askToDiscard = original

    lu.assertNotNil(pattern, "real settlement did not ask for the axe cost")
    local filter = Exppattern:Parse(pattern)
    lu.assertTrue(filter:match(Fk:getCardById(first.id)))
    lu.assertTrue(filter:match(Fk:getCardById(second.id)))
    lu.assertFalse(filter:match(Fk:getCardById(axe.id)),
      "the equipped axe itself cannot be one of the two discarded cards")
  end)
  lu.assertEquals(target.hp, hp - 1, "actual discard of two owned cards must restore the Slash")
  lu.assertEquals(discardedCount(room, { first.id, second.id }), 2)
end

function Testqiao_axe:testSelectedCardsMustActuallyReachDiscardPile()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local first = card("qiao__peach", Card.Heart, 7)
  local second = card("qiao__peach", Card.Heart, 9)
  local hp = target.hp
  -- 模拟“已选择两张、但其中一张的移动被其他效果取消”的真实移动记录。
  local partial = fk.CreateSkill { name = "test_qiao_axe_partial_discard" }
  partial:addEffect(fk.BeforeCardsMove, {
    global = true,
    mute = true,
    can_trigger = function(self, event, triggerTarget, player, data)
      return table.find(data or {}, function(move)
        return move.skillName == AXE_SKILL and #move.moveInfo > 0
      end) ~= nil
    end,
    on_cost = Util.TrueFunc,
    on_use = function(self, event, triggerTarget, player, data)
      for _, move in ipairs(data or {}) do
        if move.skillName == AXE_SKILL and #move.moveInfo > 0 then
          table.remove(move.moveInfo)
          return
        end
      end
    end,
  })
  FkTest.runInRoom(function()
    local _, slash = prepareDodgedSlash(room, owner, target, { first, second })
    local partialSkill = partial:createSkill()
    Fk.skills[partialSkill.name] = partialSkill
    room:addSkill(partialSkill)
    FkTest.setNextReplies(owner, { FkTest.ReplyDiscard({ first.id, second.id }) })
    use(room, owner, { target }, slash)
  end)
  lu.assertEquals(target.hp, hp,
    "a cancelled card move must not restore the Slash")
  local discarded = discardedCount(room, { first.id, second.id })
  lu.assertTrue(discarded < 2,
    "the two selected cards must not both count as actually discarded")
  lu.assertEquals(#owner:getCardIds("h"), 2 - discarded,
    "the cancelled card(s) stay in hand")
end

function Testqiao_axe:testRejectsCostCardsNotOwnedByTheAxeOwner()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local mine1 = card("qiao__peach", Card.Heart, 7)
  local mine2 = card("qiao__peach", Card.Heart, 9)
  local stolen1 = card("qiao__analeptic", Card.Diamond, 9)
  local stolen2 = card("qiao__analeptic", Card.Spade, 9)
  local hp = target.hp
  FkTest.runInRoom(function()
    local _, slash = prepareDodgedSlash(room, owner, target, { mine1, mine2 })
    give(room, target, stolen1)
    give(room, target, stolen2)
    -- 服务端不应直接把非发动者的牌交给 throwCard；否则会触发
    -- “Attempt to throw card from false owner”。
    local original = room.askToDiscard
    room.askToDiscard = function(self, who, params)
      if params.skill_name == AXE_SKILL then return { stolen1.id, stolen2.id } end
      return original(self, who, params)
    end
    use(room, owner, { target }, slash)
    room.askToDiscard = original
  end)
  lu.assertEquals(target.hp, hp, "invalid cost must not restore the Slash")
  lu.assertEquals(room:getCardArea(stolen1.id), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(stolen2.id), Card.PlayerHand)
  lu.assertEquals(room:getCardOwner(stolen1.id).id, target.id)
  lu.assertEquals(room:getCardOwner(stolen2.id).id, target.id)
  lu.assertEquals(room:getCardArea(mine1.id), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(mine2.id), Card.PlayerHand)
end

function Testqiao_axe:testStillRestoresWhenDiscardedCardsAreTakenInAfterMove()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local first = card("qiao__peach", Card.Heart, 7)
  local second = card("qiao__peach", Card.Heart, 9)
  local hp = target.hp
  local obtained = false
  -- 模拟“实际弃置完成后，同一 AfterCardsMove 中立刻被其他技能取走”。
  local sample = fk.CreateSkill { name = "test_qiao_axe_after_move_obtain" }
  sample:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, triggerTarget, player, data)
      for _, move in ipairs(data or {}) do
        if move.skillName == AXE_SKILL and move.toArea == Card.DiscardPile then
          return true
        end
      end
      return false
    end,
    on_refresh = function(self, event, triggerTarget, player, data)
      if obtained then return end
      for _, move in ipairs(data or {}) do
        if move.skillName == AXE_SKILL and move.toArea == Card.DiscardPile then
          obtained = true
          for _, info in ipairs(move.moveInfo or {}) do
            room:obtainCard(owner, info.cardId, true, fk.ReasonJustMove, owner, "test")
          end
          return
        end
      end
    end,
  })
  FkTest.runInRoom(function()
    local _, slash = prepareDodgedSlash(room, owner, target, { first, second })
    local sampleSkill = sample:createSkill()
    Fk.skills[sampleSkill.name] = sampleSkill
    room:addSkill(sampleSkill)
    FkTest.setNextReplies(owner, { FkTest.ReplyDiscard({ first.id, second.id }) })
    use(room, owner, { target }, slash)
  end)
  lu.assertTrue(obtained, "the AfterCardsMove probe did not run")
  lu.assertEquals(target.hp, hp - 1,
    "the Slash must stay effective even if the discarded cards are taken afterwards")
  lu.assertEquals(room:getCardArea(first.id), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(second.id), Card.PlayerHand)
  lu.assertEquals(room:getCardOwner(first.id).id, owner.id)
  lu.assertEquals(room:getCardOwner(second.id).id, owner.id)
  lu.assertEquals(discardedCount(room, { first.id, second.id }), 0)
end

function Testqiao_axe:testAxeItselfDoesNotCountAsOneOfTheTwoCards()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local onlyOther = card("qiao__peach", Card.Heart, 7)
  local hp = target.hp
  local asked = 0
  FkTest.runInRoom(function()
    local _, slash = prepareDodgedSlash(room, owner, target, { onlyOther })
    local original = room.askToDiscard
    room.askToDiscard = function(self, who, params)
      if params.skill_name == AXE_SKILL then asked = asked + 1 end
      return {}
    end
    use(room, owner, { target }, slash)
    room.askToDiscard = original
  end)
  lu.assertEquals(asked, 0, "axe plus one other card is not two discardable cards")
  lu.assertEquals(target.hp, hp)
  lu.assertEquals(room:getCardArea(onlyOther.id), Card.PlayerHand)
end

function Testqiao_axe:testDoesNotTriggerBeforeTheJinkCancelsTheEffect()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local hp = target.hp
  local asked = 0
  FkTest.runInRoom(function()
    local axe = give(room, owner, card(AXE))
    use(room, owner, { owner }, axe)
    local slash = give(room, owner, card("qiao__slash", Card.Spade, 5))
    give(room, owner, card("qiao__peach", Card.Heart, 7))
    give(room, owner, card("qiao__peach", Card.Heart, 9))
    FkTest.setNextReplies(target, { "" })
    local original = room.askToDiscard
    room.askToDiscard = function(self, who, params)
      if params.skill_name == AXE_SKILL then asked = asked + 1 end
      return original(self, who, params)
    end
    use(room, owner, { target }, slash)
    room.askToDiscard = original
  end)
  lu.assertEquals(asked, 0, "an uncancelled Slash must not ask for the axe cost")
  lu.assertEquals(target.hp, hp - 1, "normal Slash damage still applies")
end

return { name = "qiao_axe" }
