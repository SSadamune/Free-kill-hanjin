-- QUN022A 李傕 · 挠袭
-- 每回合限一次，当你使用普通锦囊牌后，你可以减1点体力上限并视为再使用一张同牌名的牌（不能包含相同的目标）。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun022a_2",
}
skill.qiaoImplemented = true

--- 联军盛宴、勠力同心、火烧连营选择首目标后会展开整组目标，须校验展开组内不含原目标。
local function groupDisjoint(room, player, card, first, origSet)
  if origSet[first.id] then return false end
  if card.name == "qiao__alliance_feast" or card.name == "qiao__fight_together" then
    for _, p in ipairs(room:getPresentPlayers()) do
      if p ~= first and not player:isProhibited(p, card)
        and card.skill:modTargetFilter(player, p, { first }, card, {})
        and (card.name ~= "qiao__alliance_feast" or p == player or player:canUseTo(card, p)) then
        if origSet[p.id] then return false end
      end
    end
  elseif card.name == "qiao__burning_camps" then
    for _, p in ipairs(room:getPresentPlayers()) do
      if p ~= first and H.inFormationRelation(first, p) and not player:isProhibited(p, card) then
        if origSet[p.id] then return false end
      end
    end
  end
  return true
end

local function canSelectDisjoint(room, player, card, selected, nextTarget, origSet)
  if origSet[nextTarget.id] or table.contains(selected, nextTarget) then return false end
  if #selected == 0 and not groupDisjoint(room, player, card, nextTarget, origSet) then return false end
  return (#selected > 0 and not card.multiple_targets or not player:isProhibited(nextTarget, card))
    and card.skill:targetFilter(player, nextTarget, selected, {}, card, {})
end

local function canFinishDisjoint(room, player, card, selected, origSet)
  if card.skill:feasible(player, selected, {}, card) then return true end
  local maxNum = card.skill:getMaxTargetNum(player, card)
  if #selected >= maxNum then return false end
  for _, p in ipairs(room:getPresentPlayers()) do
    if canSelectDisjoint(room, player, card, selected, p, origSet) then
      local nextSel = table.simpleClone(selected)
      table.insert(nextSel, p)
      if canFinishDisjoint(room, player, card, nextSel, origSet) then return true end
    end
  end
  return false
end

local function collectOrigTargetIds(data)
  local origSet = {}
  for _, p in ipairs((data and data.tos) or {}) do
    if p ~= nil and p.id ~= nil then origSet[p.id] = true end
  end
  local ever = data and data.extra_data and data.extra_data.qiao_ever_targets
  if type(ever) == "table" then
    for pid, flag in pairs(ever) do
      if flag then origSet[pid] = true end
    end
  end
  return origSet
end

--- 返回 nil 表示禁止发动；否则返回 { fixed = boolean, targets = ServerPlayer[]|integer[] }。
local function resolvePlan(room, player, cardName, origSet)
  local card = Fk:cloneCard(cardName)
  if card == nil then return nil end
  card.skillName = skill.name
  if player:prohibitUse(card) then return nil end
  origSet = origSet or {}
  if card:getFixedTargets(player) then
    -- 固定目标牌按完整固定目标集合判定：只要其中包含任一原牌曾指定过的目标，即整张不可使用，不能拆分剔除原目标。
    local available = card:getAvailableTargets(player)
    if #available == 0 then return nil end
    for _, p in ipairs(available) do
      if origSet[p.id] then return nil end
    end
    return { fixed = true, targets = available }
  end
  if not canFinishDisjoint(room, player, card, {}, origSet) then return nil end
  local allowedIds = {}
  for _, p in ipairs(room:getPresentPlayers()) do
    if not origSet[p.id] and groupDisjoint(room, player, card, p, origSet) then
      table.insert(allowedIds, p.id)
    end
  end
  if #allowedIds == 0 then return nil end
  return { fixed = false, targets = allowedIds }
end

skill:addEffect(fk.CardUseFinished, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or player:isRemoved() or not player:hasSkill(skill.name) then
      return false
    end
    if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
    local card = data and data.card
    if card == nil or card.type ~= Card.TypeTrick or card.sub_type == Card.SubtypeDelayedTrick then
      return false
    end
    if card.trueName == "nullification" then return false end
    return resolvePlan(player.room, player, card.name, collectOrigTargetIds(data)) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun022a_2-invoke:::" .. data.card.name,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cardName = data.card.name
    local origSet = collectOrigTargetIds(data)
    if resolvePlan(room, player, cardName, origSet) == nil then return end
    room:changeMaxHp(player, -1)
    if player.dead or player:isRemoved() then return end
    local plan = resolvePlan(room, player, cardName, origSet)
    if plan == nil then return end
    if plan.fixed then
      local card = Fk:cloneCard(cardName)
      card.skillName = skill.name
      room:useCard {
        from = player,
        tos = plan.targets,
        card = card,
        extraUse = true,
      }
    else
      room:askToUseVirtualCard(player, {
        name = cardName,
        skill_name = skill.name,
        prompt = "#qiao__skill_qun022a_2-use:::" .. cardName,
        cancelable = false,
        extra_data = {
          exclusive_targets = plan.targets,
          bypass_times = true,
        },
      })
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "挠袭",
  [":" .. skill.name] = "每回合限一次，当你使用普通锦囊牌后，你可以减1点体力上限并视为再使用一张同牌名的牌（不能包含相同的目标）。",
  ["#qiao__skill_qun022a_2-invoke"] = "挠袭：是否减1点体力上限并视为再使用一张【%arg】（不能包含原目标）",
  ["#qiao__skill_qun022a_2-use"] = "挠袭：选择新目标视为使用【%arg】",
}

return skill
