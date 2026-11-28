-- HAN014 朱儁：摧破、虎翼定向验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local ZHUJUN = "qiao_heg__han014"
local CUICUO = "qiao__skill_han014_1"
local HUYI = "qiao__skill_han014_2"
local ZHEN_SHI = require "packages.qiao.pkg.qiao_generals.data.zhen_shi"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end
local function clearCards(player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end
local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function prepare()
  Fk.currentResponsePattern = nil
  local room = support.createRoom {
    mode = "qiao_heg_mode", realSelection = true,
    settings = {
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "han", "han", "han", "han", "han", "han", "han" })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = ZHUJUN, deputy = "qiao_test__han_2", kingdom = "han",
    })
  end)
  return room
end

Testqiao_han014_zhujun = {
  setup = prepare,
  tearDown = function() Fk.currentResponsePattern = nil; support.clearRoom() end,
}

function Testqiao_han014_zhujun:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(d) return d.id == ZHUJUN end))
  lu.assertEquals(entry.number, "HAN014")
  local g = assert(Fk.generals[ZHUJUN])
  lu.assertIs(g.package, pack)
  lu.assertEquals(g.trueName, "朱儁")
  lu.assertEquals(g.kingdom, "han")
  lu.assertEquals(g.maxHp, 4)
  lu.assertEquals(g.gender, General.Male)
  lu.assertTrue(g:isCompanionWith(Fk.generals["qiao_heg__han013"]))
  lu.assertTrue(g:isCompanionWith(Fk.generals["qiao_heg__wu009"]))
  lu.assertTrue(table.contains(g:getSkillNameList(), CUICUO))
  lu.assertTrue(table.contains(g:getSkillNameList(), HUYI))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(ZHUJUN)) end)
end

function Testqiao_han014_zhujun:testCuipuoFirstCardAddsDamageToTarget()
  local room, player, target = FkTest.room, p(1), p(2)
  local slash = give(player, "qiao__slash", Card.Spade, 2)
  inRoom(function()
    room.current = player; player.phase = Player.Play; room:setBanner("RoundCount", 1)
  end)
  inRoom(function()
    room:useCard(UseCardData:new {
      from = player, tos = { target }, card = Fk:getCardById(slash), extra_data = {},
    })
  end)
  lu.assertEquals(target.hp, target.maxHp - 2)
end

function Testqiao_han014_zhujun:testCuipoAddsDamageToTheWholeUseOnce()
  local room, owner, first, second = FkTest.room, p(1), p(2), p(8)
  local slash = give(owner, "qiao__slash", Card.Spade, 2)
  local hp1, hp2 = first.hp, second.hp
  local use = UseCardData:new { from = owner, tos = { first, second }, card = Fk:getCardById(slash) }
  inRoom(function()
    room:setCurrent(owner)
    room:useCard(use)
  end)
  lu.assertEquals(use.additionalDamage, 1)
  lu.assertEquals({ first.hp, second.hp }, { hp1 - 2, hp2 - 2 })
  lu.assertEquals(owner:usedSkillTimes(CUICUO, Player.HistoryTurn), 1)
end

function Testqiao_han014_zhujun:testCuipoDrawsOnceWhenOwnerIsAmongTargets()
  local room, owner, other = FkTest.room, p(1), p(2)
  local replies = {}
  for i = 1, 4 do
    local id = give(owner, "qiao__iron_chain", Card.Club, 12)
    local targets = i == 4 and { other, owner } or { other }
    table.insert(replies, FkTest.ReplyCard(Fk:getCardById(id), targets))
  end
  FkTest.setNextReplies(owner, replies)
  inRoom(function()
    room:setCurrent(owner)
    GameEvent.Phase:create(PhaseData:new { who = owner, phase = Player.Play }):exec()
  end)
  lu.assertTrue(owner.chained)
  lu.assertFalse(other.chained)
  lu.assertEquals(owner:getHandcardNum(), 1)
  lu.assertEquals(owner:usedSkillTimes(CUICUO, Player.HistoryTurn), 1)
end

function Testqiao_han014_zhujun:testCuipoUnavailableAtFirstTargetSkipsWholeUse()
  local room, owner, first, second = FkTest.room, p(1), p(2), p(8)
  local slash = give(owner, "qiao__slash", Card.Spade, 2)
  local hp1, hp2 = first.hp, second.hp
  local probe = fk.CreateSkill { name = "#qiao_test_cuipo_restore" }
  probe:addEffect(fk.TargetSpecified, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == owner and player == owner and data.to == second
    end,
    on_refresh = function() room:validateSkill(owner, CUICUO) end,
  })
  inRoom(function()
    room:setCurrent(owner)
    room:addSkill(probe:createSkill())
    room:invalidateSkill(owner, CUICUO)
    lu.assertFalse(owner:hasSkill(CUICUO))
    room:useCard { from = owner, tos = { first, second }, card = Fk:getCardById(slash) }
    lu.assertTrue(owner:hasSkill(CUICUO))
  end)
  lu.assertEquals({ first.hp, second.hp }, { hp1 - 1, hp2 - 1 })
  lu.assertEquals(owner:usedSkillTimes(CUICUO, Player.HistoryTurn), 0)
end

function Testqiao_han014_zhujun:testHuyiOtherBesiegerFollowsWithRealSlash()
  local room, owner, victim, ally = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room:setPlayerProperty(ally, "kingdom", "han")
    ally.kingdom = "han"
    room:setPlayerProperty(victim, "kingdom", "wei")
    victim.kingdom = "wei"
    owner.hp, ally.hp, victim.hp = owner.maxHp, ally.maxHp, victim.maxHp
    room.current = ally
  end)
  local allySlash = give(ally, "qiao__slash", Card.Spade, 2)
  local ownerSlash = give(owner, "qiao__slash", Card.Heart, 3)

  skill_test.withSkillRequests(room, HUYI, {
    askToSkillInvoke = function() error("虎翼应在用杀请求中确认") end,
    askToUseCard = function(self, who, params, original)
      lu.assertIs(who, owner)
      local client_room = __dofile("../../../tests/support/client_room.lua")
      client_room.run(room, function(clients)
        local board = Fk:getBoardGame(room:getSettings("gameMode"))
        local client = board.client_klass:new(ClientInstance.client)
        local handler = client.request_handlers.AskForUseCard:new(clients[owner.seat], {
          params.skill_name, params.pattern, params.prompt, params.cancelable, params.extra_data,
        })
        handler:setup()
        lu.assertEquals(handler.selected_card.id, ownerSlash)
        lu.assertEquals(handler.selected_targets, { victim.id })
        lu.assertTrue(handler.scene:getAllItems("Button").OK.enabled)
        handler:_finish()
      end)
      FkTest.setNextReplies(who, { FkTest.ReplyCard(Fk:getCardById(ownerSlash), { victim }) })
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard(UseCardData:new {
        from = ally, tos = { victim }, card = Fk:getCardById(allySlash), extra_data = {},
      })
    end)
  end)

  lu.assertEquals(owner:usedSkillTimes(HUYI, Player.HistoryTurn), 1)
  lu.assertEquals(FkTest.room:getCardArea(ownerSlash), Card.DiscardPile)
end

function Testqiao_han014_zhujun:testElementalSlashCountsAsOneCharacter()
  local room, owner, victim = FkTest.room, p(1), p(2)
  local first = give(owner, "qiao__fire__slash", Card.Heart, 3)
  local second = give(owner, "qiao__thunder__slash", Card.Spade, 7)
  local hp = victim.hp
  inRoom(function()
    room.current = owner
    owner.phase = Player.Play
    room:useCard { from = owner, tos = { victim }, card = Fk:getCardById(first) }
    lu.assertEquals(victim.hp, hp - 2)
    room:useCard { from = owner, tos = { victim }, card = Fk:getCardById(second), extraUse = true }
  end)
  lu.assertEquals(victim.hp, hp - 3)
end

return { name = "qiao_han014_zhujun" }
