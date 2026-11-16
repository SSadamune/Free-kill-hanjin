-- HAN005 何进 · 谋诛
--
-- 规则基线：rules/standard-generals.md 汉区 HAN005、rules/general-principles.md、
-- docs/development/implementation/card-use-targets.md。出牌阶段限一次：令一名
-- 其他角色交给你一张手牌；交牌后若其手牌数小于你，其视为使用一张【杀】或
-- 【决斗】。此牌按其正常牌面目标条件选择目标，不设技能指定的目标例外。
-- 若该牌的目标与何进势力相同，使用者弃置一张牌。
--
-- 交牌是被令角色的效果，不是何进的发动消耗；何进不因此弃牌。交牌后即使
-- 其无法使用牌，也不返还牌或追加其他代价。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han005_1",
}
skill.hanjinImplemented = true

local H = require "packages.hegemony.util"
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

--- 其他存活角色；技能只要求一名其他角色，不把“交牌能否执行”当作
--- 发动者消耗或目标限制。
---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[]
local function eligibleTargets(player)
  local room = player.room or Fk:currentRoom()
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_han005_1-prompt",
  max_phase_use_time = 1,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #eligibleTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead
      or target.dead or target:isRemoved() then
      return
    end
    if target == player then return end

    -- 由被令角色选择交给哪一张手牌；这是其效果，不是何进的消耗。
    -- 目标没有手牌时交牌不能执行，但不否定已发动的技能：继续“然后”的
    -- 手牌比较与后续能执行的效果。
    if #target:getCardIds(Player.Hand) > 0 then
      local chosen = room:askToCards(target, {
        min_num = 1,
        max_num = 1,
        include_equip = false,
        skill_name = skill.name,
        prompt = "#hanjin__skill_han005_1-give",
        cancelable = false,
      })
      local give = chosen and chosen[1]
      if give ~= nil and table.contains(target:getCardIds(Player.Hand), give) then
        room:moveCardTo({ give }, Card.PlayerHand, player, fk.ReasonGive,
          skill.name, nil, true, target)
        if player.dead then return end
      end
    end

    -- 交牌之后再比较双方当前手牌数。
    if #target:getCardIds(Player.Hand) >= #player:getCardIds(Player.Hand) then
      return
    end

    -- 其视为使用【杀】或【决斗】；目标由其按正常牌面条件选择。
    local use = C.askToUseVirtualCard(room, target, {
      name = { "hanjin__slash", "hanjin__duel" },
      skill_name = skill.name,
      prompt = "#hanjin__skill_han005_1-use",
      cancelable = false,
      extra_data = { skillName = skill.name },
    })
    if use == nil then return end

    local sameKingdomTarget = false
    for _, to in ipairs(use.tos or {}) do
      if to ~= nil and H.compareKingdomWith(player, to) then
        sameKingdomTarget = true
        break
      end
    end
    if not sameKingdomTarget then return end
    if target.dead or target:isRemoved() or #target:getCardIds("he") == 0 then return end
    room:askToDiscard(target, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han005_1-discard",
      cancelable = false,
    })
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han005_1"] = "谋诛",
  [":hanjin__skill_han005_1"] = "出牌阶段限一次，你可以令一名其他角色交给你一张手牌，然后若其手牌数小于你，其视为使用一张【杀】或【决斗】，若此牌目标与你势力相同，其弃置一张牌。",
  ["#hanjin__skill_han005_1-prompt"] = "谋诛：令一名其他角色交给你一张手牌",
  ["#hanjin__skill_han005_1-give"] = "谋诛：请交出一张手牌",
  ["#hanjin__skill_han005_1-use"] = "谋诛：视为使用一张【杀】或【决斗】",
  ["#hanjin__skill_han005_1-discard"] = "谋诛：此牌目标与何进势力相同，请弃置一张牌",
}

return skill
