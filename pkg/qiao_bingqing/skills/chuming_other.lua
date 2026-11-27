local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local ROOT = "qiao__skill_jin037_2"
local skill = fk.CreateSkill { name = "qiao__chuming_other&" }

local function wineFor(id)
  local wine = Fk:cloneCard("qiao__analeptic")
  wine.skillName = ROOT
  wine:addSubcard(id)
  return wine
end
local function recipient(p, to, id)
  if not id or p == to or not S.present(to) or not to:hasShownSkill(ROOT) then return false end
  local wine = wineFor(id)
  return not p:prohibitUse(wine) and not p:isProhibited(to, wine)
end

skill:addEffect("active", {
  card_num = 1, target_num = 1, max_phase_use_time = 1,
  card_filter = function(self, p, id, selected)
    return #selected == 0 and table.contains(p:getCardIds("h"), id) and Fk:getCardById(id).trueName == "slash"
  end,
  target_filter = function(self, p, to, selected, cards)
    return #selected == 0 and recipient(p, to, cards[1])
  end,
  on_use = function(self, room, effect)
    local p, to, id = effect.from, effect.tos[1], effect.cards[1]
    if not table.contains(p:getCardIds("h"), id) or not recipient(p, to, id) then return end
    local wine = C.useVirtualCard(room, p, "qiao__analeptic", { id }, { to }, ROOT, true,
      { bypass_times = true, qiao_chuming_recipient = to.id }, C.explicit({}))
    if not wine or not S.present(to) or not S.present(p) then return end

    local choices = {}
    local collateral = Fk:cloneCard("qiao__collateral")
    collateral.skillName = ROOT
    if not p:prohibitUse(collateral) and not p:isProhibited(to, collateral) then table.insert(choices, collateral.name) end
    local dismantle = Fk:cloneCard("qiao__dismantlement")
    if p:canUseTo(dismantle, to) then table.insert(choices, dismantle.name) end
    if #choices == 0 then return end
    local choice = #choices == 1 and choices[1] or room:askToChoice(p, { choices = choices, skill_name = ROOT })
    if choice == dismantle.name then
      C.useVirtualCard(room, p, dismantle.name, nil, { to }, ROOT)
    else
      local eligible = ExtraTargets.subCandidates(room, { from = p, card = collateral }, to)
      local sub = S.pick(room, p, eligible, ROOT)[1]
      local tos = { to }
      if sub then table.insert(tos, sub) end
      -- 保留汉晋借刀的无懈、出杀和交一张武器，只豁免首目标的武器要求。
      room:useCard { from = p, card = collateral, tos = tos, extraUse = true }
    end
  end,
})
Fk:loadTranslationTable {
  [skill.name] = "畜鸣",
  [":" .. skill.name] = "其他角色出牌阶段限一次，其可以将一张【杀】当【酒】对你使用，然后将此【杀】交给你并视为对你使用一张无视武器限制的【借刀杀人】或【过河拆桥】。",
}
return skill
