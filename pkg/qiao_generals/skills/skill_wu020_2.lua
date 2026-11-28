-- WU020 徐盛 · 破军
-- 使用【杀】指定目标后，可扣置目标至多X张手牌/装备（X为目标势力角色数），
-- 本回合移出游戏；回合末目标存活则回手，死亡则入弃牌堆。
local H = require "packages.hegemony.util"
local Pojun = require "packages.qiao.pkg.qiao_mode.rules.pojun"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu020_2",
}
skill.qiaoImplemented = true

local RULE = "qiao__wu020_pojun_rule"

local function ensureRule(room)
  local rule = Fk.skills[RULE]
  if rule ~= nil and not room:hasSkill(RULE) then room:addSkill(rule) end
end

local function maxCards(room, target)
  return math.min(H.getSameKingdomPlayersNum(room, target), #target:getCardIds("he"))
end

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to:isAlive() and not data.to:isRemoved()
      and maxCards(player.room, data.to) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu020_2-invoke:" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if to == nil or to.dead or to:isRemoved() then return end
    local x = maxCards(room, to)
    if x <= 0 then return end
    local ids = to:getCardIds("he")
    local chosen = room:askToChooseCards(player, {
      target = to, flag = "he", min = 0, max = x,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu020_2-cards::" .. to.id .. ":" .. x,
      cancelable = true,
    }) or {}
    chosen = table.filter(chosen, function(id) return table.contains(ids, id) end)
    if #chosen == 0 then return end
    ensureRule(room)
    local turn = room.logic:getCurrentEvent():findParent(GameEvent.Turn, true)
    room:moveCards {
      ids = chosen, from = to, toArea = Card.Void,
      moveReason = fk.ReasonJustMove, moveVisible = false, proposer = player, skillName = skill.name,
    }
    local removed = table.filter(chosen, function(id) return room:getCardArea(id) == Card.Void end)
    if #removed == 0 then return end
    local list = room:getTag(Pojun.PENDING) or {}
    table.insert(list, {
      target = to.id, turn = turn and turn.id or 0, ids = removed,
    })
    room:setTag(Pojun.PENDING, list)
    Pojun.refresh(room, to)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu020_2"] = "破军",
  [":qiao__skill_wu020_2"] = "当你使用【杀】指定一个目标后，你可以扣置其至多X张牌（X为其势力角色数），这些牌本回合移出游戏。",
  ["#qiao__skill_wu020_2-invoke"] = "破军：是否扣置 %src 的牌？",
  ["#qiao__skill_wu020_2-cards"] = "破军：选择 %dest 至多 %arg 张牌扣置",
}

return skill
