-- HAN001 刘协 · 天命
--
-- 规则基线：rules/generals/han001-liuxie.md 第 2 节。
-- 时机是“成为【杀】的目标后”、响应之前；弃牌是发动消耗，先弃后摸。
-- 可弃手牌不足两张时弃尽，零张时不发生弃牌移动但仍可摸两张；装备牌
-- 不能用于补足。所有【杀】类别由 trueName == "slash" 识别。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han001_1",
}

--- 当前可以弃置的手牌。不能弃置的牌不计入 K，也不能用装备补足。
---@param player ServerPlayer
---@return integer[]
local function discardableHand(player)
  local ret = {}
  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  for _, id in ipairs(player:getCardIds(Player.Hand)) do
    local card = Fk:getCardById(id)
    local legal = true
    for _, status in ipairs(status_skills) do
      if status:prohibitDiscard(player, card) then
        legal = false
        break
      end
    end
    if legal then table.insert(ret, id) end
  end
  return ret
end

skill:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han001_1-invoke",
    }) then
      return false
    end

    local legal = discardableHand(player)
    local count = math.min(2, #legal)
    local chosen = {}
    if count > 0 then
      if #legal == count then
        chosen = legal
      else
        chosen = room:askToDiscard(player, {
          min_num = count,
          max_num = count,
          include_equip = false,
          skill_name = skill.name,
          prompt = "#hanjin__skill_han001_1-discard:::" .. count,
          cancelable = false,
          skip = true,
        })
      end

      -- Server-side normalization: only still-owned, non-prohibited hand cards
      -- are moved.  A forged/obsolete reply can neither discard equipment nor
      -- change the required count.
      local ids = {}
      for _, id in ipairs(chosen) do
        if table.contains(legal, id) and not table.contains(ids, id) then
          table.insert(ids, id)
        end
      end
      for _, id in ipairs(legal) do
        if #ids >= count then break end
        if not table.contains(ids, id) then table.insert(ids, id) end
      end
      while #ids > count do table.remove(ids) end
      chosen = ids
    end
    -- Fix the exact cards before SkillEffect reveals the source general; on_use
    -- moves them after reveal/faction determination.
    event:setCostData(self, { cards = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local cards = cost and cost.cards or {}
    if #cards > 0 then
      room:throwCard(cards, skill.name, player, player)
    end
    if player.dead then return end
    player:drawCards(2, skill.name)
  end,
})

skill:addTest(function(room, me)
  if room:getSettings("gameMode") ~= "hanjin_heg_mode" then return end
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, skill.name, nil, false, true)
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  local hand = me:getCardIds(Player.Hand)
  lu.assertTrue(#hand >= 2)
  local user = room.players[2]
  FkTest.setNextReplies(me, {
    "1",
    FkTest.ReplyDiscard({ hand[1], hand[2] }),
    "",
  })
  FkTest.runInRoom(function()
    room:useCard {
      from = user,
      tos = { me },
      card = Fk:cloneCard("hanjin__slash"),
    }
  end)
  lu.assertEquals(#me:getCardIds(Player.Hand), #hand)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han001_1"] = "天命",
  [":hanjin__skill_han001_1"] = "当你成为【杀】的目标后，你可以弃置两张手牌（不足则全弃，无牌则不弃），摸两张牌。",
  ["#hanjin__skill_han001_1-invoke"] = "天命：你可以弃置至多两张可弃手牌，然后摸两张牌",
  ["#hanjin__skill_han001_1-discard"] = "天命：请弃置 %arg 张可弃手牌",
}

return skill
