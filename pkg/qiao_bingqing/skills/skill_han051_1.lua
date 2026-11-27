local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local skill = fk.CreateSkill { name = "qiao__skill_han051_1" }
local slash = "qiao__slash"
local function black(id) return Fk:getCardById(id).color == Card.Black end
skill:addEffect("active", {
  card_num = 1, target_num = 2, max_phase_use_time = 1,
  card_filter = function(self, player, id, selected)
    return #selected == 0 and table.contains(player:getCardIds("h"), id) and black(id)
  end,
  target_filter = function(self, player, to, selected)
    return S.present(to) and ((#selected == 0 and to ~= player) or (#selected == 1 and to ~= selected[1]))
  end,
  on_use = function(self, room, effect)
    local a, b = effect.tos[1], effect.tos[2]
    S.give(room, effect.from, a, effect.cards, skill.name)
    if not S.present(a) or not S.present(b) then return end
    local policy = C.bypassDistance()
    -- 读条只依据公开手牌数；颜色在私有选牌和服务端复核时检查。
    if a:getHandcardNum() >= 2 and table.contains(C.effectCandidates(room, a, Fk:cloneCard(slash), policy), b) then
      local ids = room:askToCards(a, { min_num = 2, max_num = 2, include_equip = false,
        pattern = ".|.|black|hand", skill_name = skill.name, cancelable = true, prompt = "#qiao_suoling-black::" .. b.id })
      local hand = a:getCardIds("h")
      if #ids == 2 and ids[1] ~= ids[2]
        and table.every(ids, function(id) return table.contains(hand, id) and black(id) end)
        and C.useVirtualCard(room, a, slash, ids, { b }, skill.name, nil, nil, policy) then return end
    end
    while S.present(a) and S.present(b) do
      local use = C.askToUseCard(room, b, { names = C.concreteNames("slash"), pattern = "slash", skill_name = skill.name,
        cancelable = true, policy = policy, extra_data = { exclusive_targets = { a.id } } })
      if not use or use.tos[1] ~= a then break end
      room:useCard(use)
    end
  end,
})
Fk:loadTranslationTable { ["#qiao_suoling-black"] = "唆令：选择两张黑色手牌当【杀】对 %dest 使用；取消则允许其对你连续用【杀】" }
return skill
