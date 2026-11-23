-- WEI020 奇策
-- 出牌阶段限一次：将所有手牌当任意普通锦囊使用（目标数不能大于转化材料数，
-- 禁用【挟天子】），然后可以变更副将。
local Reuse = require "packages.qiao.pkg.qiao_cards.data.reuse"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"

local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local skill = fk.CreateSkill { name = "qiao__skill_wei020_1" }
skill.qiaoImplemented = true

--- 已实装、非衍生、非空壳的正式普通锦囊；不提供上游卡名或空壳势力锦囊。
local function trickNames()
  local names = {}
  for name, card in pairs(Fk.all_card_types) do
    local rec = Reuse.cards[name]
    if name:startsWith("qiao__") and rec ~= nil and rec.status == "reused"
      and not card.is_derived and not card.shell
      and card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick
      and name ~= "qiao__threaten_emperor" then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end
skill.qiaoTrickNames = trickNames

local function trick(player, name)
  if not name then return end
  local card = Fk:cloneCard(name)
  card.skillName = skill.name
  card:addSubcards(player:getCardIds("h"))
  return card
end

-- 联军盛宴、勠力同心选择的是代表角色；声明时整组都成为目标。
local function groupFits(player, card, first)
  if card.name ~= "qiao__alliance_feast" and card.name ~= "qiao__fight_together" then return true end
  local count = 1
  for _, p in ipairs(Fk:currentRoom():getPresentPlayers()) do
    if p ~= first and not player:isProhibited(p, card)
      and card.skill:modTargetFilter(player, p, { first }, card, {})
      and (card.name ~= "qiao__alliance_feast" or p == player or player:canUseTo(card, p)) then
      count = count + 1
    end
  end
  return count <= #card.subcards
end

local function canSelect(player, card, selected, nextTarget)
  return #selected < #card.subcards and not table.contains(selected, nextTarget)
    and (#selected > 0 and not card.multiple_targets or not player:isProhibited(nextTarget, card))
    and card.skill:targetFilter(player, nextTarget, selected, {}, card, {})
    and (#selected > 0 or groupFits(player, card, nextTarget))
end

-- 用与实际用牌一致的固定目标（已排除禁选角色）；手选牌只要求存在一组可行选择。
local function fixedFits(player, card)
  local targets = card:getAvailableTargets(player)
  return #targets > 0 and #targets <= #card.subcards
end

local function canFinish(player, card, selected)
  if card.skill:feasible(player, selected, {}, card) then return true end
  if #selected >= math.min(#card.subcards, card.skill:getMaxTargetNum(player, card)) then return false end
  for _, target in ipairs(Fk:currentRoom():getPresentPlayers()) do
    if canSelect(player, card, selected, target) then
      local nextSelection = table.simpleClone(selected)
      table.insert(nextSelection, target)
      if canFinish(player, card, nextSelection) then return true end
    end
  end
  return false
end

local function canAnnounce(player, card)
  if not card or #card.subcards == 0 or not player:canUse(card) then return false end
  if card:getFixedTargets(player) then return fixedFits(player, card) end
  return canFinish(player, card, {})
end

local function validSelection(player, card, selected)
  if not card or #card.subcards == 0 or not player:canUse(card) then return false end
  if card:getFixedTargets(player) then return #selected == 0 and fixedFits(player, card) end
  local prefix = {}
  for _, target in ipairs(selected) do
    if not canSelect(player, card, prefix, target) then return false end
    table.insert(prefix, target)
  end
  return card.skill:feasible(player, selected, {}, card)
end

local function changeSource(room, player)
  if Wei.isTempProvided(player, skill.name) then return Wei.BANNER end
  for _, deputy in ipairs({ false, true }) do
    local general = Exchange.actualGeneral(player, deputy)
    if Exchange.cardProvidesSkill(room, general, skill.name) then return general end
  end
  return tostring(player.id)
end

skill:addEffect("active", {
  prompt = "#qiao__wei020_active",
  card_num = 0,
  min_target_num = 0,
  interaction = function(self, player)
    local allNames = trickNames()
    local choices = table.filter(allNames, function(name) return canAnnounce(player, trick(player, name)) end)
    if #choices > 0 then return UI.CardNameBox { choices = choices, all_choices = allNames } end
  end,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    local card = trick(player, self.interaction.data)
    if not card or card:getFixedTargets(player) or not canSelect(player, card, selected, to_select) then return false end
    local nextSelection = table.simpleClone(selected)
    table.insert(nextSelection, to_select)
    return canFinish(player, card, nextSelection)
  end,
  feasible = function(self, player, selected)
    return validSelection(player, trick(player, self.interaction.data), selected or {})
  end,
  on_use = function(self, room, effect)
    local player, targets = effect.from, effect.tos or {}
    local name = self.interaction.data
    if not table.contains(trickNames(), name) then return end
    local card = trick(player, name)
    if not validSelection(player, card, targets) then return end
    local used = "qiao_qice_change_used_" .. changeSource(room, player)
    room:useCard { from = player, tos = targets, card = card }
    if player.dead or room:getTag(used) or #Change.candidates(room, player, true) == 0 then return end
    local choice = room:askToChoice(player, {
      choices = { "changeDeputy", "Cancel" },
      skill_name = skill.name,
      prompt = "#qiao__wei020_change",
    })
    if choice == "changeDeputy" and not room:getTag(used) then
      room:setTag(used, true)
      if not Change.changeDeputy(room, player, { skill_name = skill.name }) then
        room:setTag(used, nil)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei020_1"] = "奇策",
  [":qiao__skill_wei020_1"] = "出牌阶段限一次，你可以将所有手牌当任意一种普通锦囊牌使用（不能为目标数大于转化所用牌数的牌或【挟天子】），然后你可以变更副将。",
  ["#qiao__wei020_active"] = "奇策：将所有手牌当一张普通锦囊牌使用",
  ["#qiao__wei020_change"] = "奇策：是否变更副将",
}

return skill
