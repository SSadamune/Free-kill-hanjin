-- 文和乱武（群势力锦囊）：普通锦囊，对所有合法角色使用（包含使用者）。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 文和乱武」。
--   * 按目标各自结算：先展示该目标的手牌，再由使用者选择“可执行”的一项。
--   * 第一项由该目标自己弃置两张类别不同的手牌（基本/锦囊/装备区分）；
--     第二项由使用者从此次展示的手牌中选一张弃置。
--   * 目标空手牌时无牌可展示、无项可执行。
--   * 群势力条款在该目标结算后检查其手牌：用牌时已确定为群（快照）且该目标
--     当前为群时，手牌为零则补至其当时的体力值。
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"

local skill = fk.CreateSkill {
  name = "qiao__luanwu_chaos_skill",
}

local CHOICE_TARGET_DISCARD = "luanwu_target_discard"
local CHOICE_USER_DISCARD = "luanwu_user_discard"

local function handIds(player)
  return player:getCardIds(Player.Hand)
end

local function isInHand(room, target, id)
  return room:getCardArea(id) == Card.PlayerHand and room:getCardOwner(id) == target
end

local function cardType(id)
  local card = Fk:getCardById(id)
  return card and card.type or nil
end

--- 两张手牌类别互不相同。
local function distinctCategories(ids)
  if #ids < 2 then return false end
  local seen = {}
  for _, id in ipairs(ids) do
    local tp = cardType(id)
    if tp == nil or seen[tp] then return false end
    seen[tp] = true
  end
  return true
end

--- 第一项是否可执行：存在两张类别不同的手牌。
local function canDiscardTwoCategories(player)
  local first
  for _, id in ipairs(handIds(player)) do
    local tp = cardType(id)
    if tp ~= nil then
      if first == nil then
        first = tp
      elseif tp ~= first then
        return true
      end
    end
  end
  return false
end

--- 从目标当前手牌中取一对类别不同的牌。仅在客户端回复不合法时兜底。
local function legalPair(player)
  local firstByType = {}
  for _, id in ipairs(handIds(player)) do
    local tp = cardType(id)
    if tp ~= nil and firstByType[tp] == nil then firstByType[tp] = id end
  end
  local first, second
  for tp, id in pairs(firstByType) do
    if first == nil then
      first = { tp, id }
    elseif second == nil then
      second = { tp, id }
    end
  end
  if first == nil or second == nil then return {} end
  return { first[2], second[2] }
end

skill:addEffect("cardskill", {
  prompt = "#qiao__luanwu_chaos_skill",
  can_use = Util.CanUseFixedTarget,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= nil and not to_select.dead and not to_select:isRemoved()
  end,
  on_effect = function(self, room, effect)
    local user, target = effect.from, effect.to
    if target == nil or target.dead or target:isRemoved() then return end

    local shown = handIds(target)
    if #shown > 0 then
      room:showCards(shown, target)
    end
    local shownHand = table.filter(shown, function(id) return isInHand(room, target, id) end)

    local options = {}
    if canDiscardTwoCategories(target) then
      table.insert(options, CHOICE_TARGET_DISCARD)
    end
    if #shownHand > 0 then table.insert(options, CHOICE_USER_DISCARD) end

    if #options > 0 and user ~= nil and not user.dead then
      local choice = room:askToChoice(user, {
        choices = options,
        all_choices = { CHOICE_TARGET_DISCARD, CHOICE_USER_DISCARD },
        skill_name = skill.name,
        prompt = "#qiao__luanwu_chaos-choose::" .. target.id,
      })
      if choice == CHOICE_TARGET_DISCARD then
        local picked = room:askToChooseCards(target, {
          target = target,
          flag = "h",
          min = 2,
          max = 2,
          skill_name = skill.name,
          cancelable = false,
          prompt = "#qiao__luanwu_chaos-target-discard",
        }) or {}
        -- 服务器端复核：只能弃两张仍在手牌、类别不同的牌；不合规则按现状补足。
        local ids = {}
        for _, id in ipairs(picked) do
          if not table.contains(ids, id) and table.contains(handIds(target), id) then
            table.insert(ids, id)
          end
        end
        if not distinctCategories(ids) then ids = legalPair(target) end
        if distinctCategories(ids) then
          room:throwCard(ids, skill.name, target, target)
        end
      elseif choice == CHOICE_USER_DISCARD then
        local id = room:askToChooseCard(user, {
          target = target,
          -- 显式牌组让客户端继续正面显示本次展示的牌。
          flag = { card_data = { { "$Hand", shownHand } } },
          skill_name = skill.name,
          prompt = "#qiao__luanwu_chaos-user-discard::" .. target.id .. ":" .. skill.name,
        })
        if table.contains(shownHand, id) and isInHand(room, target, id) then
          room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonDiscard, skill.name, nil, true, user)
        end
      end
    end

    -- 群势力条款：该目标结算后按当前手牌检查，为零则补至其当前体力值。
    if target.dead or target:isRemoved() then return end
    if not FactionTricks.useConfirmed(effect.extra_data) then return end
    if not FactionTricks.isConfirmedKingdom(target, "qun") then return end
    if #handIds(target) == 0 and target.hp > 0 then
      target:drawCards(target.hp, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "文和乱武",
  ["#qiao__luanwu_chaos_skill"] = "文和乱武：逐目标展示手牌并弃置",
  ["#qiao__luanwu_chaos-choose"] = "文和乱武：选择对 %dest 执行的一项",
  ["#qiao__luanwu_chaos-target-discard"] = "文和乱武：弃置两张类别不同的手牌",
  ["#qiao__luanwu_chaos-user-discard"] = "文和乱武：选择弃置 %dest 展示的一张手牌",
  [CHOICE_TARGET_DISCARD] = "该目标弃置两张类别不同的手牌",
  [CHOICE_USER_DISCARD] = "你弃置其展示的一张手牌",
}

return skill
