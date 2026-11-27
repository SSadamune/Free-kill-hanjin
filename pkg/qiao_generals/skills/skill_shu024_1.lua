-- SHU024 法正 · 定军
-- 摸牌阶段结束时，你可以交给一名其他角色两张手牌，
-- 其需视为对你选择的另一名角色使用任意一种【杀】，否则交给你至少两张手牌。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu024_1",
}
skill.qiaoImplemented = true

local SLASH_NAMES = { "qiao__slash", "qiao__fire__slash", "qiao__thunder__slash", "qiao__ice__slash" }
local RETURN_CHOICE = "#qiao__skill_shu024_1-return"

local function legalSlashNames(user, victim)
  local result = {}
  if not RemovedTargets.isPresent(user) or not RemovedTargets.isPresent(victim) or user == victim then
    return result
  end
  for _, name in ipairs(SLASH_NAMES) do
    local card = Fk:cloneCard(name)
    card.skillName = skill.name
    if not user:prohibitUse(card) and not user:isProhibited(victim, card)
      and user:canUseTo(card, victim, { bypass_distances = true, bypass_times = true }) then
      table.insert(result, name)
    end
  end
  return result
end

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.phase ~= Player.Draw or not RemovedTargets.isPresent(player) then
      return false
    end
    if not player:hasSkill(skill.name) or player:getHandcardNum() < 2 then return false end
    local others = table.filter(player.room:getPresentPlayers(), function(p) return p ~= player end)
    return #others > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local others = table.filter(room:getPresentPlayers(), function(p) return p ~= player end)
    if #others == 0 or player:getHandcardNum() < 2 then return false end
    local tos, cards = room:askToChooseCardsAndPlayers(player, {
      targets = others,
      min_num = 1,
      max_num = 1,
      min_card_num = 2,
      max_card_num = 2,
      pattern = ".|.|.|hand",
      skill_name = skill.name,
      prompt = "#qiao__skill_shu024_1-give",
      cancelable = true,
    })
    if not tos or #tos ~= 1 or not cards or #cards ~= 2 then return false end
    local hand = player:getCardIds("h")
    if not table.contains(hand, cards[1]) or not table.contains(hand, cards[2]) then return false end
    event:setCostData(self, { to = tos[1], cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local targetA, cards = cost.to, cost.cards
    if not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(targetA) or targetA == player then
      return
    end
    local validCards = table.filter(cards or {}, function(id)
      return table.contains(player:getCardIds("h"), id)
    end)
    if #validCards ~= 2 then return end

    room:obtainCard(targetA, validCards, false, fk.ReasonGive, player, skill.name)
    if not RemovedTargets.isPresent(player) or not RemovedTargets.isPresent(targetA) then return end

    -- 另一名角色允许选法正自己（只要不为 targetA）。
    local bCandidates = table.filter(room:getPresentPlayers(), function(p) return p ~= targetA end)
    if #bCandidates == 0 then return end
    local chosenB = room:askToChoosePlayers(player, {
      targets = bCandidates,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu024_1-victim::" .. targetA.id,
      cancelable = false,
    })
    local targetB = (chosenB and chosenB[1]) or bCandidates[1]
    if not RemovedTargets.isPresent(targetB) or targetB == targetA then return end

    local slashes = legalSlashNames(targetA, targetB)
    local canReturn = targetA:getHandcardNum() >= 2
    local choices = table.simpleClone(slashes)
    if canReturn then table.insert(choices, RETURN_CHOICE) end
    if #choices == 0 then return end

    local pick
    if #choices == 1 then
      pick = choices[1]
    else
      pick = room:askToChoice(targetA, {
        choices = choices,
        skill_name = skill.name,
        prompt = "#qiao__skill_shu024_1-choose:" .. player.id .. ":" .. targetB.id,
        cancelable = false,
      })
    end

    if pick ~= nil and table.contains(slashes, pick) then
      local slashCard = Fk:cloneCard(pick)
      slashCard.skillName = skill.name
      room:useCard {
        from = targetA,
        tos = { targetB },
        card = slashCard,
        extraUse = true,
      }
    elseif canReturn and RemovedTargets.isPresent(targetA) and RemovedTargets.isPresent(player) then
      local handCount = targetA:getHandcardNum()
      if handCount < 2 then return end
      local ret = room:askToCards(targetA, {
        min_num = 2,
        max_num = handCount,
        include_equip = false,
        skill_name = skill.name,
        prompt = "#qiao__skill_shu024_1-return-cards::" .. player.id,
        cancelable = false,
      })
      if type(ret) ~= "table" or #ret < 2 then
        local h = targetA:getCardIds("h")
        ret = { h[1], h[2] }
      end
      room:obtainCard(player, ret, false, fk.ReasonGive, targetA, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "定军",
  [":" .. skill.name] = "摸牌阶段结束时，你可以交给一名其他角色两张手牌，其需视为对你选择的另一名角色使用任意一种【杀】，否则交给你至少两张手牌。",
  ["#qiao__skill_shu024_1-give"] = "定军：选择两张手牌交给一名其他角色",
  ["#qiao__skill_shu024_1-victim"] = "定军：选择令 %dest 视为使用【杀】的目标角色（可选自己）",
  ["#qiao__skill_shu024_1-choose"] = "定军：选择视为对 %dest 使用一种【杀】，或交给 %src 至少两张手牌",
  [RETURN_CHOICE] = "交出至少两张手牌",
  ["#qiao__skill_shu024_1-return-cards"] = "定军：请选择至少两张手牌交给 %dest",
}

return skill
