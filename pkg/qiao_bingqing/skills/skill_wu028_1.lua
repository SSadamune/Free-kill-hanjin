local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_wu028_1" }
skill:addEffect("active", {
  card_num = 1, target_num = 0, max_phase_use_time = 1,
  card_filter = function(self, p, id, selected) return #selected == 0 and table.contains(S.discardable(p), id) end,
  on_use = function(self, room, effect)
    local p, id = effect.from, effect.cards[1]
    local equip = Fk:getCardById(id).type == Card.TypeEquip
    room:throwCard(id, skill.name, p, p)
    room:addPlayerMark(p, "@qiao_gongqi-turn", 4)
    if not equip or not S.present(p) then return end
    local targets = table.filter(room:getPresentPlayers(), function(to) return to ~= p and not to:isNude() end)
    local to = S.choose(p, targets, skill.name)[1]
    if to then room:throwCard(room:askToChooseCard(p, { target = to, flag = "he", skill_name = skill.name }), skill.name, to, p) end
  end,
})
skill:addEffect("atkrange", { correct_func = function(self, p) return p:getMark("@qiao_gongqi-turn") end })
Fk:loadTranslationTable { ["@qiao_gongqi-turn"] = "弓骑" }
return skill
