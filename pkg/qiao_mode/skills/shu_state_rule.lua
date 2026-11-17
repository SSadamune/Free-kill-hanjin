-- 观星、空城与放权已经建立的持续结算，不依赖原技能是否仍在。
local skill = fk.CreateSkill { name = "qiao__shu_state_rule" }

local KONG = "qiao__skill_shu004_2_kong"
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
    local n = #room.alive_players < 4 and 3 or 5
    room:askToGuanxing(player, {
      cards = room:getNCards(n),
      skill_name = "qiao__skill_shu004_1",
      prompt = "#qiao__skill_shu004_1-finish",
    })
  end,
})

-- 放权/铁骑回合末收束。
skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    -- 观星结束阶段若被跳过，也要在本回合结束清理，不能带到下一回合。
    room:setPlayerMark(player, GUANX, 0)


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
      local candidates = {}
      for _, p in ipairs(room.alive_players) do
        if p ~= player and not p:isRemoved() then table.insert(candidates, p) end
      end
      -- 先选目标（可取消）；支付弃牌后不得再取消选人吞费用。
      local targets = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = candidates,
        prompt = "#qiao__skill_shu013_2-choose",
        skill_name = "qiao__skill_shu013_2",
        cancelable = true,
      })
      local to = targets and targets[1]
      if to ~= nil and not to.dead and #player:getCardIds("h") > 0 then
        local to_discard = room:askToDiscard(player, {
          min_num = 1,
          max_num = 1,
          include_equip = false,
          skill_name = "qiao__skill_shu013_2",
          prompt = "#qiao__skill_shu013_2-discard",
          cancelable = false,
        })
        if to_discard and #to_discard > 0 then
          -- 此回合结束后才执行，必须排队而不是立刻嵌套。
          to:gainAnExtraTurn(true, "qiao__skill_shu013_2")
        end
      end
  end,
})

return skill
