-- WU020 徐盛 · 疑城
-- 同势力角色成为【杀】目标后，徐盛可令其摸1，并由该角色选择真实使用一张
-- 装备牌，或记录一次“本回合结束弃1”。每次发动独立记录，不合并弃牌量。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wu020_1",
}
skill.hanjinImplemented = true

local RULE = "hanjin__wu020_yicheng_rule"
local PENDING = "hanjin_wu020_yicheng_pending"
local USE_EQUIP = "hanjin__skill_wu020_1-use"
local DELAY = "hanjin__skill_wu020_1-delay"

local function turnId(room)
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

local function ensureRule(room)
  local rule = Fk.skills[RULE]
  if rule ~= nil and not room:hasSkill(RULE) then room:addSkill(rule) end
end

local function recordDelay(room, to)
  ensureRule(room)
  local list = room:getTag(PENDING) or {}
  table.insert(list, { target = to.id, turn = turnId(room) })
  room:setTag(PENDING, list)
end

skill:addEffect(fk.TargetConfirmed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and target ~= nil and target == data.to
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to:isAlive()
      and H.compareKingdomWith(player, data.to)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu020_1-invoke:" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if to == nil or to.dead or to:isRemoved() then return end
    to:drawCards(1, skill.name)
    if to.dead then return end
    local equipIds = table.filter(to:getCardIds("h"), function(id)
      return Fk:getCardById(id).type == Card.TypeEquip
    end)
    local choices = { DELAY }
    if #equipIds > 0 then table.insert(choices, USE_EQUIP) end
    local choice = room:askToChoice(to, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu020_1-choice",
      cancelable = false,
    })
    if choice == USE_EQUIP then
      local use = room:askToUseCard(to, {
        pattern = ".|.|.|.|.|equip",
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu020_1-equip",
        cancelable = false,
      })
      -- 必须实际使用成功；取消/无合法装备不能免费跳过，转为回合末弃牌。
      if use ~= nil and room:useCard(use) then return end
    end
    recordDelay(room, to)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu020_1"] = "疑城",
  [":hanjin__skill_wu020_1"] = "与你势力相同的角色成为【杀】的目标后，你可以令其摸一张牌，其选择一项：1.使用一张装备牌；2.于此回合结束时弃置一张牌。",
  ["#hanjin__skill_wu020_1-invoke"] = "疑城：是否令 %dest 摸一张牌？",
  ["#hanjin__skill_wu020_1-choice"] = "疑城：使用装备牌，或本回合结束弃一张牌",
  ["#hanjin__skill_wu020_1-equip"] = "疑城：使用一张装备牌",
  [USE_EQUIP] = "使用装备牌",
  [DELAY] = "回合结束弃一张牌",
}

return skill
