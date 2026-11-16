-- EM(SHU001) 刘备 · 六师率义旗
-- 其他蜀势力角色出牌阶段限一次：交给刘备两张牌，然后本回合获得场上公开
-- 没有的一项技能。临时技能使用独立来源，回合末只撤该来源。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_em_shu001_flag",
}
skill.hanjinImplemented = true

local ZHANGWU = "hanjin__skill_em_shu001_1"
local RULE = "hanjin__skill_em_shu001_flag_rule"
local GRANTED = "hanjin_em_shu001_flag_granted"
local CHOICES = {
  "hanjin__skill_shu002_1", -- 武圣
  "hanjin__skill_shu003_1", -- 咆哮
  "hanjin__skill_shu005_1", -- 龙胆
  "hanjin__skill_shu006_2", -- 铁骑
  "hanjin__skill_shu008_1", -- 烈勇
  "hanjin__skill_shu009_1", -- 狂骨
}

local function lordFor(player)
  local room = player.room or Fk:currentRoom()
  for _, p in ipairs(room.alive_players) do
    if p ~= player and not p.dead and not p:isRemoved()
      and p:hasShownSkill(ZHANGWU) and H.compareKingdomWith(p, player) then
      return p
    end
  end
  return nil
end

local function available(player)
  local result = {}
  for _, name in ipairs(CHOICES) do
    local shown = false
    for _, p in ipairs((player.room or Fk:currentRoom()).alive_players) do
      if p:hasShownSkill(name) then shown = true break end
    end
    if not shown then table.insert(result, name) end
  end
  return result
end

local function ensureRule(room)
  local rule = Fk.skills[RULE]
  if rule ~= nil and not room:hasSkill(RULE) then room:addSkill(rule) end
end

skill:addEffect("active", {
  prompt = "#hanjin__skill_em_shu001_flag-prompt",
  include_equip = true,
  card_num = 2,
  min_card_num = 2,
  max_card_num = 2,
  max_phase_use_time = 1,
  card_filter = function(self, player, to_select, selected)
    return table.contains(player:getCardIds("he"), to_select) and #selected < 2
  end,
  can_use = function(self, player)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and player:hasSkill(skill.name) and #player:getCardIds("he") >= 2
      and lordFor(player) ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local lord = lordFor(player)
    local cards = effect.cards or {}
    if player == nil or lord == nil or #cards ~= 2 then return end
    room:obtainCard(lord, cards, true, fk.ReasonGive, player, skill.name)
    if player.dead then return end
    local choices = available(player)
    if #choices == 0 then return end
    local chosen = room:askToChoice(player, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#hanjin__skill_em_shu001_flag-choose",
      cancelable = false,
    })
    ensureRule(room)
    room:handleAddLoseSkills(player, chosen, skill.name, false, true)
    local list = room:getTag(GRANTED) or {}
    table.insert(list, { player = player.id, skill = chosen })
    room:setTag(GRANTED, list)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_em_shu001_flag"] = "六师率义旗",
  [":hanjin__skill_em_shu001_flag"] = "其他蜀势力角色的出牌阶段限一次，其可以交给你两张牌，然后于本回合获得一项场上没有的技能。",
  ["#hanjin__skill_em_shu001_flag-prompt"] = "六师率义旗：交给君主刘备两张牌",
  ["#hanjin__skill_em_shu001_flag-choose"] = "六师率义旗：选择本回合获得的技能",
}

return skill
