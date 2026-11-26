-- QUN021 袁术 · 庸肆
-- 出牌阶段限一次，你可以对本回合摸过牌的一名其他角色发起“军令”。
-- 若其不执行，你获得其所有手牌，然后交给其等量的牌。
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun021_1",
}
skill.qiaoImplemented = true

local function isEligibleTarget(player, other)
  return other ~= nil and other ~= player and not other:isRemoved()
    and other:getMark(Quan.DRAWN_TURN_MARK) > 0
end

local function hasEligibleTarget(player)
  local room = Fk:currentRoom()
  if room == nil then return false end
  return table.find(room:getPresentPlayers(), function(other)
    return isEligibleTarget(player, other)
  end) ~= nil
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_qun021_1-prompt",
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player:usedEffectTimes(self.name, Player.HistoryPhase) == 0
      and hasEligibleTarget(player)
  end,
  card_num = 0,
  card_filter = Util.FalseFunc,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and isEligibleTarget(player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos[1]
    if not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(to) then return end
    if not isEligibleTarget(player, to) then return end

    local executed = Junling.ask(player, to, skill.name)
    if executed or not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(to) then
      return
    end
    local targetHand = to:getCardIds("h")
    if #targetHand == 0 then return end

    local startId = room.logic:getCurrentEvent().id
    room:obtainCard(player, targetHand, false, fk.ReasonPrey, player, skill.name)

    -- 按本次实际获得到手牌区的张数 N 结算后续交牌。
    local gained = 0
    room.logic:getEventsByRule(GameEvent.MoveCards, 999, function(e)
      for _, move in ipairs(e.data or {}) do
        if move.to == player and move.toArea == Card.PlayerHand
          and move.moveReason == fk.ReasonPrey and move.skillName == skill.name then
          gained = gained + #(move.moveInfo or {})
        end
      end
      return false
    end, startId)

    if gained <= 0 or not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(to) then
      return
    end
    local pool = player:getCardIds("he")
    local need = math.min(gained, #pool)
    if need <= 0 then return end
    local giveCards
    if #pool <= need then
      giveCards = table.simpleClone(pool)
    else
      giveCards = room:askToCards(player, {
        min_num = need,
        max_num = need,
        include_equip = true,
        skill_name = skill.name,
        prompt = "#qiao__skill_qun021_1-give::" .. to.id .. ":" .. need,
        cancelable = false,
      })
      if type(giveCards) ~= "table" or #giveCards ~= need then
        giveCards = {}
        for i = 1, need do table.insert(giveCards, pool[i]) end
      end
    end
    room:obtainCard(to, giveCards, false, fk.ReasonGive, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "庸肆",
  [":" .. skill.name] = "出牌阶段限一次，你可以对本回合摸过牌的一名其他角色发起“军令”。若其不执行，你获得其所有手牌，然后交给其等量的牌。",
  ["#qiao__skill_qun021_1-prompt"] = "庸肆：选择一名本回合摸过牌的其他角色，对其发起“军令”",
  ["#qiao__skill_qun021_1-give"] = "庸肆：请选择 %arg 张牌交给 %dest",
}

return skill
