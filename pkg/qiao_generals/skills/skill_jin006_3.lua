-- JIN006 杜预 · 武库
-- 副将技：可将一张宝物牌当自己本回合使用的上一张基本牌或普通锦囊牌使用。
-- 上一张由独立公开历史规则记录，包含尚未取得/暗置武库时已公开使用的牌；
-- 客户端只读公开 player mark。仅“使用”，不提供纯“打出”窗口。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin006_3",
  tags = { Skill.DeputyPlace },
}
skill.qiaoImplemented = true

skill:addEffect("viewas", {
  pattern = ".",
  prompt = "#qiao__skill_jin006_3-prompt",
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    return #selected < 1 and U.isTreasure(Fk:getCardById(to_select))
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 or not U.isTreasure(Fk:getCardById(cards[1])) then return nil end
    local last = U.lastUse(player)
    if last == nil then return nil end
    local card = Fk:cloneCard(last)
    if card == nil then return nil end
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return U.lastUse(player) ~= nil and #U.treasureIds(player) > 0
  end,
  -- ReqUseCard（包括回合外要求“使用”闪/无懈）为 false；纯打出为 true。
  enabled_at_response = function(self, player, cardResponsing)
    return not cardResponsing and U.lastUse(player) ~= nil and #U.treasureIds(player) > 0
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin006_3"] = "武库",
  ["#qiao__skill_jin006_3-prompt"] = "武库：将一张宝物牌当本回合上一张基本牌或普通锦囊牌使用",
}

return skill
