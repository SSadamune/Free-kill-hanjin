-- “赐”的出牌阶段效果属于标记持有者，和诸王敕封册的触发技能分开。
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"

local skill = fk.CreateSkill { name = Ci.CONSUME, tags = { Skill.Permanent } }
skill.qiaoImplemented = true

skill:addEffect("active", {
  prompt = "#qiao__jin001_banner-active",
  target_num = 0,
  card_num = 0,
  interaction = function(self, player)
    local cards = Ci.cards(player)
    local actions = {}
    for _, name in ipairs(cards) do actions[name] = Ci.actionsFor(player, name) end
    return {
      type = "custom",
      qml = {
        url = "packages/qiao/pkg/qiao_mode/qml/CiSelection.qml",
        prop = { cardNames = cards, actionsByCard = actions },
      },
    }
  end,
  can_use = function(self, player)
    return Ci.canSpend(player)
  end,
  feasible = function(self, player, targets, cards)
    return #targets == 0 and #cards == 0 and Ci.validAction(player, self.interaction.data)
  end,
  on_use = function(self, room, effect)
    local player, choice = effect.from, effect.interaction_data
    if not Ci.validAction(player, choice, room) then return end
    local action = choice.action
    if action == "main" or action == "deputy" then
      if not Change.change(room, player, action == "deputy", { num = 3, skill_name = Ci.SKILL }) then return end
      room:setPlayerMark(player, Ci.CHANGED, 1)
    end
    if not Ci.consume(room, player, choice.general) then return end
    room:setPlayerMark(player, Ci.SPENT, 1)
    if action == "maxcards" then
      room:addPlayerMark(player, MarkEnum.AddMaxCardsInTurn, 3)
    elseif action == "draw" then
      local n = math.max(0, 4 - #player:getCardIds("h"))
      if n > 0 then player:drawCards(n, skill.name) end
    end
  end,
})

Fk:loadTranslationTable {
  [Ci.CONSUME] = "赐",
  [":" .. Ci.CONSUME] = "出牌阶段限一次，你可以消耗一枚〖赐〗，然后变更一张与此牌单独阴阳鱼数相同的武将牌（限一次），或根据此牌单独阴阳鱼数执行效果：≤3：本回合手牌上限+3。≥4：摸牌至四张。",
  ["qiao_ci_main"] = "变更主将",
  ["qiao_ci_deputy"] = "变更副将",
  ["qiao_ci_maxcards"] = "手牌上限+3",
  ["qiao_ci_draw"] = "摸牌至四张",
}
return skill
