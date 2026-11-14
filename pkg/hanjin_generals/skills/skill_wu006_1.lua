-- WU006 大乔 · 国色
--
-- 出牌阶段各限一次，你可以：
--   1. 将一张方片牌当【乐不思蜀】使用；
--   2. 弃置一张方片牌和场上一张延时锦囊牌。
-- 然后摸一张牌。
--
-- 两分支在界面先选分支，再按分支过滤候选牌/目标：使用分支不要求牌可弃置，
-- 但目标须符合【乐不思蜀】原目标条件；弃置分支要求方片与目标判定区牌都能
-- 被弃置。两项费用在确认后一次性批量移动，避免两次移动之间状态变化只付
-- 半边。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu006_1",
}
skill.hanjinImplemented = true

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"

local USE_MARK = "hanjin__skill_wu006_1_use-phase"
local DISCARD_MARK = "hanjin__skill_wu006_1_discard-phase"
local OPT_USE = "hanjin__skill_wu006_1-use"
local OPT_DISCARD = "hanjin__skill_wu006_1-discard"

local function diamonds(player)
  return table.filter(player:getCardIds("he"), function(id)
    return Fk:getCardById(id).suit == Card.Diamond
  end)
end

local function discardableDiamonds(player)
  return table.filter(diamonds(player), function(id)
    return not player:prohibitDiscard(id)
  end)
end

local function discardableDelayed(owner, player)
  return table.filter(owner:getCardIds(Player.Judge), function(id)
    return not player:prohibitDiscard(id)
  end)
end

local function discardTargets(room, player)
  return table.filter(room.alive_players, function(p)
    return not p:isRemoved() and #discardableDelayed(p, player) > 0
  end)
end

local function useTargets(room, player)
  local card = Fk:cloneCard("hanjin__indulgence")
  local cardSkill = card:getSkill(player)
  return table.filter(room.alive_players, function(p)
    return p ~= player and not p:isRemoved()
      and not player:isProhibited(p, card)
      and cardSkill:targetFilter(player, p, {}, {}, card, {}) == true
  end)
end

local function branchAvailable(player, branch)
  local mark = branch == OPT_USE and USE_MARK or DISCARD_MARK
  return player:getMark(mark) == 0
end

local function discardMove(room, owner, id, player)
  return {
    ids = { id },
    from = owner,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonDiscard,
    skillName = skill.name,
    proposer = player,
  }
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#hanjin__skill_wu006_1-prompt",
  interaction = UI.OptionBox { options = { OPT_USE, OPT_DISCARD }, direct_send = true },
  min_card_num = 1,
  max_card_num = 1,
  target_num = 1,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    local branch = self.interaction and self.interaction.data
    if branch ~= nil and not branchAvailable(player, branch) then return false end
    if branch == OPT_DISCARD then
      return table.contains(discardableDiamonds(player), to_select)
    end
    return table.contains(diamonds(player), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    local branch = self.interaction and self.interaction.data
    if branch ~= nil and not branchAvailable(player, branch) then return false end
    if branch == OPT_USE then
      return table.contains(useTargets(W.currentRoom(player), player), to_select)
    elseif branch == OPT_DISCARD then
      return #discardableDelayed(to_select, player) > 0
    end
    return false
  end,
  refresh_interaction = function(self, player)
    local choices = {}
    local room = W.currentRoom(player)
    if branchAvailable(player, OPT_USE) and #diamonds(player) > 0
      and #useTargets(room, player) > 0 then
      table.insert(choices, OPT_USE)
    end
    if branchAvailable(player, OPT_DISCARD) and #discardableDiamonds(player) > 0
      and #discardTargets(room, player) > 0 then
      table.insert(choices, OPT_DISCARD)
    end
    return choices
  end,
  can_use = function(self, player)
    if player.phase ~= Player.Play then return false end
    local room = W.currentRoom(player)
    local useOK = branchAvailable(player, OPT_USE)
      and #diamonds(player) > 0 and #useTargets(room, player) > 0
    local discardOK = branchAvailable(player, OPT_DISCARD)
      and #discardableDiamonds(player) > 0 and #discardTargets(room, player) > 0
    return useOK or discardOK
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local branch = self.interaction and self.interaction.data
    local cardId = effect.cards and effect.cards[1]
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or branch == nil or cardId == nil then return end
    if not branchAvailable(player, branch) then return end

    if branch == OPT_USE then
      if not table.contains(useTargets(room, player), target) then return end
      if not table.contains(diamonds(player), cardId) then return end
      local use = C.useVirtualCard(room, player, "hanjin__indulgence", { cardId }, { target }, skill.name)
      if use == nil then return end
      room:addPlayerMark(player, USE_MARK, 1)
      if player:isAlive() and not player:isRemoved() then player:drawCards(1, skill.name) end
      return
    end

    if branch ~= OPT_DISCARD then return end
    if target == nil or target.dead or target:isRemoved() then return end
    if not branchAvailable(player, OPT_DISCARD) then return end
    if not table.contains(discardableDiamonds(player), cardId) then return end
    local judgeCards = discardableDelayed(target, player)
    if #judgeCards == 0 then return end
    local trickId
    if #judgeCards == 1 then
      trickId = judgeCards[1]
    else
      local picked = room:askToChooseCards(player, {
        target = target,
        flag = { card_data = { { "$Judge", judgeCards } } },
        min = 1,
        max = 1,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu006_1-judge_card",
        cancelable = true,
      })
      trickId = picked and picked[1]
    end
    if trickId == nil or not table.contains(discardableDelayed(target, player), trickId) then return end
    if not table.contains(discardableDiamonds(player), cardId) then return end

    -- 两份费用同一次 moveCards 调用（varargs）批量移动；中间不重判。
    room:moveCards(
      discardMove(room, player, cardId, player),
      discardMove(room, target, trickId, player)
    )
    room:addPlayerMark(player, DISCARD_MARK, 1)
    if player:isAlive() and not player:isRemoved() then player:drawCards(1, skill.name) end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu006_1"] = "国色",
  ["#hanjin__skill_wu006_1-prompt"] = "国色：选择一项并选择一张方片牌",
  ["#hanjin__skill_wu006_1-use_target"] = "国色：选择【乐不思蜀】的目标",
  ["#hanjin__skill_wu006_1-discard_target"] = "国色：选择一名判定区有可弃置牌的角色",
  ["#hanjin__skill_wu006_1-judge_card"] = "国色：选择一张延时锦囊牌弃置",
  [OPT_USE] = "将一张方片牌当【乐不思蜀】使用",
  [OPT_DISCARD] = "弃置一张方片牌和场上一张延时锦囊牌",
}

return skill
