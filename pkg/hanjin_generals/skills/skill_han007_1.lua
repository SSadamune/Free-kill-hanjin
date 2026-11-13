-- HAN007 王荣 · 敏思
--
-- 规则基线：rules/generals/han007-wangrong.md、rules/general-principles.md。
-- 出牌阶段限一次：弃置任意张点数之和为 13 的牌（手牌或装备牌均可），
-- 摸两倍的牌并展示之；只有本次摸到的红桃牌本回合不计入手牌上限。
--
-- 追德给予的「发动一次敏思」使用同一份选牌与效果实现，通过辅助主动技
-- 调用，不永久授予技能，也不占用敏思在出牌阶段空闲时间点的次数。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han007_1",
}
skill.hanjinImplemented = true

local M = require "packages.hanjin.pkg.hanjin_generals.util.minsi"

--- 追德让受赠者额外发动敏思时使用的辅助主动技。名字独立，因而不与
--- 敏思本体的「出牌阶段限一次」共用历史记录。
local AUX = "#hanjin__skill_han007_1_aux"

--- 本体与辅助主动技共用的选牌条件。
local SELECT = {
  include_equip = true,
  min_card_num = 1,
  max_card_num = function(self, player) return #M.legalCards(player) end,
  card_filter = function(self, player, to_select, selected)
    return M.cardFilter(player, to_select, selected)
  end,
  feasible = function(self, player, selected_targets, selected_cards)
    return M.feasible(selected_cards)
  end,
  prompt = function(self, player, selected_cards)
    return "#hanjin__skill_han007_1-prompt:::" .. M.sumOf(selected_cards)
  end,
}

local main = table.simpleClone(SELECT)
main.anim_type = "drawcard"
main.max_phase_use_time = 1
main.can_use = function(self, player)
  -- 自定义 can_use 时须自行检查次数；额外发动使用 AUX，不经过这里。
  return self:withinTimesLimit(player, Player.HistoryPhase) and M.canForm13(player)
end
main.on_use = function(self, room, effect)
  M.perform(room, effect.from, effect.cards, skill.name)
end
skill:addEffect("active", main)

local aux = table.simpleClone(SELECT)
aux.can_use = function(self, player) return M.canForm13(player) end
skill:addAuxActiveSkill(AUX, aux)

-- 本次摸到的红桃牌不计入手牌上限。状态技是房间级的，因此受赠者通过
-- 追德额外发动敏思后，即使王荣随后死亡，标记仍按受赠者 id 生效。
skill:addEffect("maxcards", {
  exclude_from = function(self, player, card)
    return card:getMark(M.markName(player)) > 0
  end,
})

skill:addTest(function(room, me)
  if room:getSettings("gameMode") ~= "hanjin_heg_mode" then return end
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, skill.name, nil, false, true)
  end)
  lu.assertTrue(me:hasSkill(skill.name))
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han007_1"] = "敏思",
  [":hanjin__skill_han007_1"] = "出牌阶段限一次，你可以弃置任意张点数之和为13的牌，摸两倍的牌并展示之，其中的红桃牌本回合不计入手牌上限。",
  ["#hanjin__skill_han007_1-prompt"] = "敏思：请选择点数之和为13的牌（当前 %arg 点）",
}

return skill
