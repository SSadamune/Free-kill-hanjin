-- 固国安邦（吴势力锦囊）：仅对自己使用。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 固国安邦」。
--   * 目标先摸八张，然后从现有手牌中选择至少六张合法牌弃置；可弃手牌不足
--     六张时弃尽，为零时无牌可弃。弃牌是摸牌后的效果，不受手牌上限约束。
--   * 用牌时使用者的势力快照已确定为吴，才可把「本次实际弃置、且此刻仍在
--     弃牌堆」的牌分给其他吴势力角色，每名至多两张，允许只分配一部分。
--   * 其他势力的使用者照常摸八弃六，但不分配。
-- 分配走引擎承认的 expand_pile 入口（与博通、遗计同一公共接口）：每轮选择
-- 一名接收者与若干张牌，牌和在弃牌堆中的位置都由 expand_pile 展示；每名接收
-- 者累计至多两张，可随时取消结束分配，最后一次性 doYiji 完成正常给牌移动。
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"

local skill = fk.CreateSkill {
  name = "qiao__strengthen_state_skill",
}

local DRAW_NUM = 8
local MIN_DISCARD = 6
local PER_TARGET_MAX = 2

--- 其他仍为吴势力、可作为接收者的存活角色。
---@param room Room
---@param user ServerPlayer
---@return ServerPlayer[]
local function otherWuPlayers(room, user)
  local targets = {}
  for _, player in ipairs(room:getAlivePlayers()) do
    if player ~= user and not player:isRemoved()
      and FactionTricks.isConfirmedKingdom(player, "wu") then
      table.insert(targets, player)
    end
  end
  return targets
end

skill:addEffect("cardskill", {
  prompt = "#qiao__strengthen_state_skill",
  can_use = Util.CanUseToSelf,
  -- 仅对自己使用：固定目标为使用者本人，需允许自身通过目标筛选，
  -- 否则真实用牌请求会因没有合法固定目标而跳过结算。
  mod_target_filter = Util.TrueFunc,
  on_effect = function(self, room, effect)
    local player = effect.from
    -- 仅对自己使用：目标必须是用牌者本人。
    if player == nil or player.dead or effect.to ~= player then return end

    player:drawCards(DRAW_NUM, skill.name)
    if player.dead or player:isRemoved() then return end

    local hand = #player:getCardIds(Player.Hand)
    if hand == 0 then return end

    local minNum = math.min(MIN_DISCARD, hand)
    local discards = room:askToDiscard(player, {
      min_num = minNum,
      max_num = hand,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__strengthen_state-discard:::" .. minNum,
      cancelable = false,
    }) or {}

    -- 只分配本次实际弃置且此刻仍在弃牌堆的实体牌；此后离开弃牌堆的牌不再分配。
    local distributable = table.filter(discards, function(id)
      return room:getCardArea(id) == Card.DiscardPile
    end)
    if #distributable == 0 then return end

    -- 势力效果按用牌时的快照判定，不因此刻势力变化而改变本次用牌。
    if not FactionTricks.useConfirmed(effect.extra_data) then return end

    local targets = otherWuPlayers(room, player)
    if #targets == 0 then return end

    -- 每轮选择一名接收者和若干张牌；每人累计至多两张，可随时取消。
    local remaining = table.simpleClone(distributable)
    local given = {}
    local list = {}
    while #remaining > 0 do
      local candidates = table.filter(targets, function(target)
        return (given[target.id] or 0) < PER_TARGET_MAX
      end)
      if #candidates == 0 then break end
      local tos, chosen, ok = room:askToChooseCardsAndPlayers(player, {
        min_num = 1,
        max_num = 1,
        min_card_num = 1,
        max_card_num = math.min(#remaining, PER_TARGET_MAX),
        targets = candidates,
        pattern = ".",
        skill_name = skill.name,
        prompt = "#qiao__strengthen_state-distribute:::" .. #remaining .. ":" .. PER_TARGET_MAX,
        cancelable = true,
        expand_pile = remaining,
      })
      if not ok or tos == nil or chosen == nil or #tos == 0 or #chosen == 0 then break end

      local to = tos[1]
      local allowance = PER_TARGET_MAX - (given[to.id] or 0)
      local valid = {}
      for _, id in ipairs(chosen) do
        if #valid < allowance and table.contains(remaining, id)
          and not table.contains(valid, id) then
          table.insert(valid, id)
        end
      end
      if #valid == 0 then break end
      list[to.id] = list[to.id] or {}
      table.insertTable(list[to.id], valid)
      given[to.id] = (given[to.id] or 0) + #valid
      for _, id in ipairs(valid) do table.removeOne(remaining, id) end
    end
    if next(list) ~= nil then
      room:doYiji(list, player, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "固国安邦",
  [":" .. skill.name] = "出牌阶段，对你使用。你摸八张牌，然后弃置至少六张手牌"
    .. "（可弃手牌不足则全弃）；若你使用此牌时已确定为吴势力，你可以将本次"
    .. "实际弃置且仍在弃牌堆的牌交给其他吴势力角色，每名角色至多两张。",
  ["#qiao__strengthen_state_skill"] = "固国安邦：摸八张牌，然后弃置至少六张手牌",
  ["#qiao__strengthen_state-discard"] = "固国安邦：请弃置至少 %arg 张手牌",
  ["#qiao__strengthen_state-distribute"] =
    "固国安邦：可将这些牌交给其他吴势力角色（共 %arg 张，每名至多 %arg2 张）",
}

return skill
