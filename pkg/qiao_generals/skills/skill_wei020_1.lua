-- WEI020 奇策
-- 出牌阶段限一次：将所有手牌当任意普通锦囊使用（目标数不能大于转化材料数，
-- 禁用【挟天子】），然后可以变更副将。
local Reuse = require "packages.qiao.pkg.qiao_cards.data.reuse"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"

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

skill:addEffect("active", {
  prompt = "#qiao__wei020_active",
  card_num = 0,
  min_target_num = 0,
  interaction = function(self, player)
    local handcards = player:getCardIds("h")
    local names, all_names = {}, {}
    for _, name in ipairs(trickNames()) do
      table.insert(all_names, name)
      local to_use = Fk:cloneCard(name)
      to_use:addSubcards(handcards)
      if player:canUse(to_use) then
        local maxTargets = to_use.skill:getMaxTargetNum(player, to_use)
        if maxTargets == nil or maxTargets <= #handcards then
          table.insert(names, name)
        end
      end
    end
    if #names == 0 then return end
    return UI.CardNameBox { choices = names, all_choices = all_names }
  end,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0 and not player:isKongcheng()
  end,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if self.interaction.data == nil then return false end
    local to_use = Fk:cloneCard(self.interaction.data)
    to_use.skillName = skill.name
    to_use:addSubcards(player:getCardIds("h"))
    if not to_use.skill:targetFilter(player, to_select, selected, selected_cards, to_use, Util.DummyTable) then return false end
    local handCount = #player:getCardIds("h")
    local maxTargets = to_use.skill:getMaxTargetNum(player, to_use)
    if maxTargets ~= nil and maxTargets > handCount then return false end
    if not to_use.multiple_targets and #selected + 1 > handCount then return false end
    if (#selected == 0 or to_use.multiple_targets) and player:isProhibited(to_select, to_use) then return false end
    if to_use.multiple_targets then
      if #selected >= player:getHandcardNum() then return false end
      if to_use.skill:getMaxTargetNum(player, to_use) == 1 then
        local x = 0
        for _, p in ipairs(Fk:currentRoom().alive_players) do
          if p == to_select or (not player:isProhibited(p, to_use) and to_use.skill:modTargetFilter(player, p, { to_select }, to_use, true)) then
            x = x + 1
          end
        end
        if x > player:getHandcardNum() then return false end
      end
    end
    return true
  end,
  feasible = function(self, player, selected, selected_cards)
    if self.interaction.data == nil then return false end
    local to_use = Fk:cloneCard(self.interaction.data)
    to_use.skillName = skill.name
    to_use:addSubcards(player:getCardIds("h"))
    if #(selected or {}) > #player:getCardIds("h") then return false end
    return to_use.skill:feasible(player, selected, selected_cards, to_use)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local handCount = #player:getCardIds("h")
    if #(effect.tos or {}) > handCount then return end
    local card = Fk:cloneCard(self.interaction.data)
    card:addSubcards(player:getCardIds("h"))
    card.skillName = skill.name
    room:useCard { from = player, tos = effect.tos, card = card }
    if player.dead then return end
    local choice = room:askToChoice(player, {
      choices = { "changeDeputy", "Cancel" },
      skill_name = skill.name,
      prompt = "#qiao__wei020_change",
    })
    if choice == "changeDeputy" then
      Change.changeDeputy(room, player, { num = 3, skill_name = skill.name })
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
