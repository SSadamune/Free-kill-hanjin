-- 观星、空城与放权已经建立的持续结算，不依赖原技能是否仍在。
local skill = fk.CreateSkill { name = "qiao__shu_state_rule" }

local KONG = "@@qiao__skill_shu004_2_kong"
local GUANX = "qiao__skill_shu004_1_finish-turn"
local FQ = "qiao__skill_shu013_2_turn-turn"

-- 空城：不是禁止成为目标，而是令【杀】/【决斗】对其无效。
skill:addEffect(fk.TargetConfirmed, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(KONG) > 0 and data.card ~= nil
      and (data.card.trueName == "slash" or data.card.trueName == "duel")
  end,
  on_refresh = function(self, event, target, player, data)
    data:setNullified(player)
  end,
})

-- 空城：到下一次真实摸牌结束（普通获得牌不结束）。
skill:addEffect(fk.BeforeDrawCard, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(KONG) > 0 and (data.num or 0) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, KONG, 0)
  end,
})

-- 观星：本次卜算全底后，结束阶段再执行一次；不依赖观星是否仍在。
skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and data.phase == Player.Finish and player:getMark(GUANX) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, GUANX, 0)
    local n = #room:getPresentPlayers() < 4 and 3 or 5
    room:askToGuanxing(player, {
      cards = room:getNCards(n),
      skill_name = "qiao__skill_shu004_1",
      prompt = "#qiao__skill_shu004_1-finish",
    })
  end,
})

-- 观星结束阶段若被跳过，在本回合结束清理待结算的标记。
skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(GUANX) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, GUANX, 0)
  end,
})


-- 延后结算需要玩家输入，使用模式级延时触发，不在全体刷新遍历中发起请求。
skill:addEffect(fk.TurnEnd, {
  global = true,
  priority = -10,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:getMark(FQ) > 0
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, FQ, 0)
    if not table.find(player:getCardIds("h"), function(id)
      return not player:prohibitDiscard(id)
    end) then return end
    local candidates = table.filter(room:getPresentPlayers(), function(p)
      return p ~= player and not p:isRemoved()
    end)
    if #candidates == 0 then return end

    local skillName = "qiao__skill_shu013_2"
    local targets, cards = room:askToChooseCardsAndPlayers(player, {
      min_num = 1,
      max_num = 1,
      min_card_num = 1,
      max_card_num = 1,
      targets = candidates,
      pattern = ".|.|.|hand",
      will_throw = true,
      prompt = "#qiao__skill_shu013_2-pay",
      skill_name = skillName,
      cancelable = true,
    })
    if #targets ~= 1 or #cards ~= 1 then return end
    local to, id = targets[1], cards[1]
    if not table.contains(candidates, to) or to.dead or to:isRemoved()
      or not table.contains(player:getCardIds("h"), id) or player:prohibitDiscard(id) then return end
    room:throwCard(cards, skillName, player, player)
    -- 此回合结束后才执行，必须排队而不是立刻嵌套。
    to:gainAnExtraTurn(true, skillName)
  end,
})

return skill
