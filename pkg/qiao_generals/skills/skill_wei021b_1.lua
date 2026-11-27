-- WEI021B 毛玠 · 征辟
-- 出牌阶段限一次，你可以将一张牌交给一名角色，其展示并交给你一张非基本牌或两张基本牌，
-- 若其有暗置武将牌，本回合此技能限两次。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei021b_1",
}
skill.qiaoImplemented = true

local function phaseLimit(player)
  return player ~= nil and player:getMark(Quan.ZHENGPI_TWICE_MARK) > 0 and 2 or 1
end

local function otherPresentCount(player)
  local room = Fk:currentRoom()
  if room == nil then return 0 end
  return #table.filter(room:getPresentPlayers(), function(p) return p ~= player end)
end

local RETURN_SKILL = "#qiao__skill_wei021b_1_return"

local function validReturnSelection(to, cards)
  if type(cards) ~= "table" then return false end
  local he = to:getCardIds("he")
  for _, id in ipairs(cards) do
    if not table.contains(he, id) then return false end
  end
  if #cards == 1 then
    local c = Fk:getCardById(cards[1])
    return c ~= nil and c.type ~= Card.TypeBasic
  elseif #cards == 2 and cards[1] ~= cards[2] then
    local c1, c2 = Fk:getCardById(cards[1]), Fk:getCardById(cards[2])
    return c1 ~= nil and c2 ~= nil and c1.type == Card.TypeBasic and c2.type == Card.TypeBasic
  end
  return false
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__skill_wei021b_1-prompt",
  max_phase_use_time = function(self, player)
    return phaseLimit(player)
  end,
  can_use = function(self, player)
    return player:usedEffectTimes(self.name, Player.HistoryPhase) < phaseLimit(player)
      and #player:getCardIds("he") > 0
      and otherPresentCount(player) > 0
  end,
  card_num = 1,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0
  end,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player and not to_select:isRemoved()
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos[1]
    local cardId = effect.cards[1]
    if player.dead or to == nil or to == player or not RemovedTargets.isPresent(to) then return end
    if cardId == nil or not table.contains(player:getCardIds("he"), cardId) then return end

    if Quan.hasHiddenGeneral(to) then
      room:setPlayerMark(player, Quan.ZHENGPI_TWICE_MARK, 1)
    end
    room:obtainCard(to, cardId, false, fk.ReasonGive, player, skill.name)

    if RemovedTargets.isPresent(to) and RemovedTargets.isPresent(player) then
      local nonBasics, basics = {}, {}
      for _, id in ipairs(to:getCardIds("he")) do
        local c = Fk:getCardById(id)
        if c ~= nil then
          if c.type == Card.TypeBasic then
            table.insert(basics, id)
          else
            table.insert(nonBasics, id)
          end
        end
      end
      local canNonBasic = #nonBasics >= 1
      local canTwoBasic = #basics >= 2
      if canNonBasic or canTwoBasic then
        local retCards
        if canNonBasic and not canTwoBasic and #nonBasics == 1 then
          retCards = { nonBasics[1] }
        elseif canTwoBasic and not canNonBasic and #basics == 2 then
          retCards = { basics[1], basics[2] }
        else
          local _, ret = room:askToUseActiveSkill(to, {
            skill_name = RETURN_SKILL,
            prompt = "#qiao__skill_wei021b_1-return::" .. player.id,
            cancelable = false,
            extra_data = { skillName = skill.name },
          })
          if ret and validReturnSelection(to, ret.cards) then
            retCards = ret.cards
          elseif canNonBasic then
            retCards = { nonBasics[1] }
          else
            retCards = { basics[1], basics[2] }
          end
        end
        if retCards ~= nil and #retCards > 0 then
          to:showCards(retCards)
          if RemovedTargets.isPresent(player) and RemovedTargets.isPresent(to) then
            local stillOwned = table.filter(retCards, function(id)
              return table.contains(to:getCardIds("he"), id)
            end)
            if #stillOwned > 0 then
              room:obtainCard(player, stillOwned, true, fk.ReasonGive, to, skill.name)
            end
          end
        end
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "征辟",
  [":" .. skill.name] = "出牌阶段限一次，你可以将一张牌交给一名角色，其展示并交给你一张非基本牌或两张基本牌，若其有暗置武将牌，本回合此技能限两次。",
  ["#qiao__skill_wei021b_1-prompt"] = "征辟：选择一张牌交给一名其他角色",
  ["#qiao__skill_wei021b_1-return"] = "征辟：请展示并交给 %dest 一张非基本牌或两张基本牌",
}

return skill
