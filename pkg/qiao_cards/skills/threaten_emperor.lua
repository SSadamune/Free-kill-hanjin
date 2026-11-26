-- 挟天子以令诸侯（汉晋版）
--
-- 牌面：出牌阶段，若你是大势力角色且此时是你额定回合，对你使用。
-- 目标角色结束其出牌阶段，然后于此回合结束时弃置一张手牌并获得一个额外的回合。
--
-- 与国战版的差异：
--   * 只在额定回合可用，额外回合内不可再次使用；
--   * 只有本次结算实际结束了本人出牌阶段时才建立后续效果；
--   * 支付时点在“回合结束时”而不是弃牌阶段结束时，且只能弃置手牌；
--   * 额外回合沿用引擎正式的 gainAnExtraTurn（延迟到本回合结束后执行）。
local skill = fk.CreateSkill {
  name = "qiao__threaten_emperor_skill",
}

local H = require "packages.hegemony.util"

-- 已实际结束出牌阶段、等待回合结束时支付的标记；引擎在回合结束时清理。
local PENDING = "qiao__threaten_emperor-turn"

--- 当前是否处于额外回合。读取公开的额外回合原因表标记，不使用只在服务端
--- 存在的 insideExtraTurn，便于客户端的可用性查询。
local function insideExtraTurn(player)
  local reasons = player:getTableMark("_extra_turn_count") or {}
  return (reasons[#reasons] or "game_rule") ~= "game_rule"
end

--- 实际结束目标自己的出牌阶段。只有阶段确实因本次结算结束才返回 true。
local function tryEndPlayPhase(room, player)
  if room.current ~= player then return false end
  if player.phase ~= Player.Play then return false end
  local current = room.logic:getCurrentEvent()
  local phase = current and current:findParent(GameEvent.Phase, true)
  if phase == nil or phase.data.who ~= player or phase.data.phase ~= Player.Play then
    return false
  end
  if phase.data.phase_end then return false end
  player:endPlayPhase()
  return phase.data.phase_end == true
end

skill:addEffect("cardskill", {
  prompt = "#qiao__threaten_emperor_skill",
  mod_target_filter = function(self, player, to_select)
    return to_select == player
  end,
  can_use = function(self, player, card)
    local room = Fk:currentRoom()
    return player ~= nil and card ~= nil and room ~= nil and room.current == player
      and player.phase == Player.Play
      and not player:isProhibited(player, card)
      and (card:getMark("qiao_ignore_big_kingdom") > 0 or H.isBigKingdomPlayer(player))
      and not insideExtraTurn(player)
  end,
  on_use = function(self, room, use)
    if use.tos == nil or #use.tos == 0 then use.tos = { use.from } end
  end,
  on_effect = function(self, room, effect)
    local target = effect.to
    if target == nil or not tryEndPlayPhase(room, target) then return end
    room:setPlayerMark(target, PENDING, 1)
  end,
})

--- 可选作“弃置一张手牌”的合法手牌。
local function discardableHand(player)
  return table.filter(player:getCardIds(Player.Hand), function(id)
    return not player:prohibitDiscard(id)
  end)
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_trigger = function(self, event, target, player)
    return target ~= nil and target == player and target:getMark(PENDING) > 0
      and #discardableHand(target) > 0
  end,
  -- 印刷牌面没有“可以”：有合法手牌时回合结束必须弃置一张。
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    local room = player.room
    if #discardableHand(player) == 0 then return end
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__threaten_emperor-pay",
      cancelable = false,
    })
    if #cards ~= 1 then return end
    local moves = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
      if e.interrupted then return false end
      return table.find(e.data, function(move)
        return move.from == player and move.toArea == Card.DiscardPile
          and move.moveReason == fk.ReasonDiscard and move.skillName == skill.name
          and table.find(move.moveInfo, function(info)
            return info.cardId == cards[1] and info.fromArea == Card.PlayerHand
          end)
      end) ~= nil
    end)
    if #moves == 0 then return end
    -- 延迟到本回合结束后执行；敕令等“回合结束时”效果先于额外回合。
    player:gainAnExtraTurn(true, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__threaten_emperor_skill"] = "挟天子以令诸侯",
  [":qiao__threaten_emperor_skill"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：为大势力角色的你（仅限你的额定回合）<br/>"
    .. "<b>效果</b>：目标角色结束其出牌阶段，然后于此回合结束时弃置一张手牌并获得一个额外的回合。",
  ["#qiao__threaten_emperor_skill"] = "对你自己使用",
  ["#qiao__threaten_emperor-pay"] = "挟天子以令诸侯：请选择一张手牌弃置",
}

return skill
