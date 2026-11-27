-- WU019 陆抗 · 恪守
-- 你可以将两张牌当【闪】或【无懈可击】使用且具有<孤军→获得或消耗一枚阴阳鱼标记>。
local H = require "packages.hegemony.util"
local Adaptation = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local TriggerSelection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu019_2",
}
skill.qiaoImplemented = true

local EFFECT_NAME = "qiao_keshou_yinyangfish"
local OPT_GAIN = "#qiao__skill_wu019_2-gain"
local OPT_CONSUME_DRAW = "#qiao__skill_wu019_2-consume-draw"
local OPT_CONSUME_MAX = "#qiao__skill_wu019_2-consume-maxcards"

-- 注册汉晋正式应变效果：<孤军→获得或消耗一枚阴阳鱼标记>，供铜雀等应变机制联动。
Adaptation.registerEffect(EFFECT_NAME, {
  apply = function(room, use)
    local from = use and use.from
    if not RemovedTargets.isPresent(from) then return end
    local hasFish = from:getMark("@!!yinyangfish") > 0
    if not hasFish then
      H.addHegMark(from, "yinyangfish", 1)
      return
    end
    local choices = { OPT_GAIN, OPT_CONSUME_DRAW, OPT_CONSUME_MAX }
    local pick = TriggerSelection.askOption(room, from, {
      choices = choices,
      all_choices = choices,
      cancelable = false,
      buttons = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu019_2-adapt",
    }) or OPT_GAIN
    if pick == OPT_CONSUME_DRAW and from:getMark("@!!yinyangfish") > 0 then
      H.removeHegMark(room, from, "yinyangfish", 1)
      if RemovedTargets.isPresent(from) then
        from:drawCards(1, skill.name)
      end
    elseif pick == OPT_CONSUME_MAX and from:getMark("@!!yinyangfish") > 0 then
      H.removeHegMark(room, from, "yinyangfish", 1)
      if RemovedTargets.isPresent(from) then
        room:addPlayerMark(from, MarkEnum.AddMaxCardsInTurn, 2)
      end
    else
      H.addHegMark(from, "yinyangfish", 1)
    end
  end,
})

local CARD_NAMES = { "qiao__jink", "qiao__nullification" }

local function usableNames()
  local names = {}
  local pat = Fk.currentResponsePattern
  if type(pat) ~= "string" then return names end
  for _, name in ipairs(CARD_NAMES) do
    local c = Fk:cloneCard(name)
    if c:matchVSPattern(pat) then
      table.insert(names, name)
    end
  end
  return names
end

skill:addEffect("viewas", {
  anim_type = "defensive",
  pattern = "jink,nullification",
  prompt = "#qiao__skill_wu019_2-prompt",
  handly_pile = true,
  interaction = function(self, player)
    local names = usableNames()
    if #names == 0 then return nil end
    return UI.CardNameBox {
      choices = names,
      all_choices = CARD_NAMES,
    }
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected < 2
  end,
  view_as = function(self, player, cards)
    if #cards ~= 2 then return nil end
    local name = self.interaction.data
    -- 求闪回复在服务端重建时，请求 pattern 已清除，选牌框回传了本次牌名。
    if Fk.currentResponsePattern then
      local valid = usableNames()
      if not table.contains(valid, name) then name = valid[1] end
    end
    if not table.contains(CARD_NAMES, name) then return nil end
    local card = Fk:cloneCard(name)
    card:addSubcards(cards)
    card.skillName = skill.name
    Adaptation.setCardEntries(card, {
      { condition = "gujun", effect = EFFECT_NAME },
    })
    return card
  end,
  enabled_at_play = Util.FalseFunc,
  enabled_at_response = function(self, player, response)
    -- 原文仅限“使用”，不可用于纯打出【闪】窗口。
    if response then return false end
    local materials = player:getHandlyIds()
    table.insertTableIfNeed(materials, player:getCardIds("e"))
    return #materials >= 2 and #usableNames() > 0
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "恪守",
  [":" .. skill.name] = "你可以将两张牌当【闪】或【无懈可击】使用且具有<孤军→获得或消耗一枚阴阳鱼标记>。",
  ["#qiao__skill_wu019_2-prompt"] = "恪守：选择两张牌当【闪】或【无懈可击】使用（孤军→获得或消耗一枚阴阳鱼标记）",
  ["#qiao__skill_wu019_2-adapt"] = "恪守（孤军）：选择获得或消耗一枚阴阳鱼标记",
  [OPT_GAIN] = "获得一枚阴阳鱼标记",
  [OPT_CONSUME_DRAW] = "消耗阴阳鱼：摸一张牌",
  [OPT_CONSUME_MAX] = "消耗阴阳鱼：本回合手牌上限+2",
  ["qiao_adaptation_" .. EFFECT_NAME] = "获得或消耗一枚阴阳鱼标记",
}

return skill
