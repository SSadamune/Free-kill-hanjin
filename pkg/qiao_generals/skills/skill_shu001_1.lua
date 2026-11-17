-- SHU001 刘备 · 仁德
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU001。
-- 出牌阶段每名角色限一次：将至少一张手牌交给一名其他角色；此阶段以此法给出
-- 的牌累计跨过第二张时（由不足两张变为至少两张），可以视为使用任意一种基本牌。
-- 第二次给牌后只提供一次机会，之后继续给牌不再重复提供。
--
-- “任意一种基本牌”按 FAQ 泛转化范围取初始牌堆存在的基本牌（含属性杀）。
-- 技能视为使用不占通常用牌次数，沿用劲弩等既有技能视为使用的约定。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu001_1",
}
skill.qiaoImplemented = true

local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local TARGET_MARK = "qiao__skill_shu001_1-targets-phase"
local GIVEN_MARK = "qiao__skill_shu001_1-given-phase"
local OFFER_MARK = "qiao__skill_shu001_1-offer-phase"

-- 初始牌堆中的基本牌名。属性杀属于基本牌，泛转化可选用。
local BASIC_NAMES = {
  "qiao__slash",
  "qiao__fire__slash",
  "qiao__thunder__slash",
  "qiao__ice__slash",
  "qiao__jink",
  "qiao__peach",
  "qiao__analeptic",
}

local function hasHandCard(player)
  return #player:getCardIds("h") > 0
end

local function availableTargets(player)
  local used = player:getTableMark(TARGET_MARK)
  local room = player.room or Fk:currentRoom()
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
      and not table.contains(used, p.id)
  end)
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__skill_shu001_1-prompt",
  min_card_num = 1,
  target_num = 1,
  card_filter = function(self, player, to_select, selected)
    return table.contains(player:getCardIds("h"), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and not table.contains(player:getTableMark(TARGET_MARK), to_select.id)
  end,
  can_use = function(self, player)
    return player.phase == Player.Play and hasHandCard(player)
      and #availableTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then
      return
    end
    if #cards == 0 then return end
    if not table.contains(availableTargets(player), target) then return end
    for _, id in ipairs(cards) do
      if not table.contains(player:getCardIds("h"), id) then return end
    end

    -- 费用至少一张手牌；给牌不是弃置，不套用禁止弃置。
    room:addTableMarkIfNeed(player, TARGET_MARK, target.id)
    room:moveCardTo(cards, Player.Hand, target, fk.ReasonGive, skill.name, nil, false, player)

    local given = player:getMark(GIVEN_MARK)
    room:addPlayerMark(player, GIVEN_MARK, #cards)
    if given >= 2 or given + #cards < 2 then return end
    if player:getMark(OFFER_MARK) > 0 then return end
    if player.dead then return end
    room:addPlayerMark(player, OFFER_MARK, 1)

    -- 视为使用任意一种基本牌；取消窗口即放弃本次机会。
    -- 次数已满时，选择阶段的 bypass_times 必须随 use 进入目标校验；引擎
    -- askToUseVirtualCard 不会把 extra_data 带回 use，因此选择后由 C.useCard
    -- 统一挂接目标策略并复核。
    local use = room:askToUseVirtualCard(player, {
      name = BASIC_NAMES,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu001_1-basic",
      cancelable = true,
      skip = true,
      extra_data = { bypass_times = true, extraUse = true },
    })
    if use == nil or use.card == nil then return end
    use.extra_data = use.extra_data or {}
    use.extra_data.bypass_times = true
    use.extraUse = true
    C.useCard(room, player, use)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu001_1"] = "仁德",
  [":qiao__skill_shu001_1"] = "出牌阶段每名角色限一次，你可以将任意张手牌交给一名其他角色，你此阶段以此法给出第二张牌后，你可以视为使用任意一种基本牌。",
  ["#qiao__skill_shu001_1-prompt"] = "仁德：将至少一张手牌交给一名其他角色",
  ["#qiao__skill_shu001_1-basic"] = "仁德：你可以视为使用任意一种基本牌",
}

return skill
