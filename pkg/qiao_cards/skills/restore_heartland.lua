-- 克复中原（蜀势力锦囊）：普通锦囊，可选择一名或多名合法角色。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 克复中原」及
-- docs/rules/card-use-targets.md。
--   * 每个目标依次自行选择视为使用一张【杀】或摸一张牌；用杀时由其按【杀】的
--     正常目标条件挑选合法对象（“视为”不自动放宽距离）。没有合法用杀对象时
--     只能选择摸牌。
--   * 用牌时已确定为蜀且该目标当前为蜀时，该次【杀】的伤害 +1，或改为摸两张。
--     修正只作用于该目标此次用牌，其他目标及之后的用牌不继承。
--   * 视为用杀经 askToUseVirtualCard 取得实际选择，再由 C.useCard 使用一次，
--     避免重复用牌。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"

local skill = fk.CreateSkill {
  name = "qiao__restore_heartland_skill",
}

local SLASH = "qiao__slash"
local CHOICE_SLASH = "restore_heartland_slash"
local CHOICE_DRAW = "restore_heartland_draw"

--- 目标按【杀】的正常目标条件是否有合法对象。
local function canUseSlash(target)
  local card = Fk:cloneCard(SLASH)
  local candidates = card:getAvailableTargets(target)
  return #candidates > 0
end

skill:addEffect("cardskill", {
  prompt = "#qiao__restore_heartland_skill",
  min_target_num = 1,
  max_target_num = function(self, player, card)
    local room = Fk:currentRoom()
    return #room:getPresentPlayers()
  end,
  -- cardskill 的默认 targetFilter 恒为 false；接回共用入口后，客户端按同一
  -- mod_target_filter 条件点亮目标。
  target_filter = Util.CardTargetFilter,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= nil and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    return #Fk:currentRoom():getPresentPlayers() > 0
  end,
  on_effect = function(self, room, effect)
    local target = effect.to
    if effect.from == nil or target == nil then return end
    if target.dead or target:isRemoved() then return end

    -- 用牌时已确定为蜀，且该目标当前为蜀，才强化其本人的这次结算。
    local boosted = FactionTricks.useConfirmed(effect.extra_data)
      and FactionTricks.isConfirmedKingdom(target, "shu")

    local slashUsable = canUseSlash(target)
    local options = {}
    if slashUsable then table.insert(options, CHOICE_SLASH) end
    table.insert(options, CHOICE_DRAW)

    local choice = options[1]
    if #options > 1 then
      choice = room:askToChoice(target, {
        choices = options,
        all_choices = { CHOICE_SLASH, CHOICE_DRAW },
        skill_name = skill.name,
        prompt = "#qiao__restore_heartland-choice",
      })
    end

    if choice == CHOICE_SLASH then
      -- 选择阶段先不实际使用；取得选择后施加本次伤害修正，再使用一次。
      local use = room:askToUseVirtualCard(target, {
        name = SLASH,
        skill_name = skill.name,
        prompt = "#qiao__restore_heartland-slash",
        cancelable = false,
        skip = true,
      })
      if use == nil or use.card == nil then return end
      if boosted then
        use.additionalDamage = (use.additionalDamage or 0) + 1
      end
      C.useCard(room, target, use)
    else
      if target.dead or target:isRemoved() then return end
      target:drawCards(boosted and 2 or 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "克复中原",
  ["#qiao__restore_heartland_skill"] = "克复中原：每名目标选择视为使用【杀】或摸牌",
  ["#qiao__restore_heartland-choice"] = "克复中原：选择视为使用一张【杀】或摸一张牌",
  ["#qiao__restore_heartland-slash"] = "克复中原：视为使用一张【杀】",
  [CHOICE_SLASH] = "视为使用一张【杀】",
  [CHOICE_DRAW] = "摸一张牌",
}

return skill
