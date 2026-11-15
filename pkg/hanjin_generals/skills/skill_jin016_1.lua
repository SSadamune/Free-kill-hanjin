-- JIN016 张华 · 复礼
--
-- 同势力角色摸牌阶段，其可以多摸一张；摸牌完成后展示一张自己的手牌，令其本回合
-- 不能使用或打出该花色的牌（不限手牌），并将该牌交给张华。每份承诺按“本次摸牌
-- + 来源张华”保存到房间列表，由独立房间规则在 AfterDrawNCards 逐份兑现；即使
-- 多摸后张华失去复礼，已承诺的后续仍执行。无手牌时明确清理，不漏到以后。
local RULE_SKILL = "hanjin__jin_sources_rule"
local B = require "packages.hanjin.pkg.hanjin_generals.util.jin_basic"

local skill = fk.CreateSkill {
  name = "hanjin__skill_jin016_1",
}
skill.hanjinImplemented = true

local function ensureRule(room)
  if room == nil or room:hasSkill(RULE_SKILL) then return end
  local rule = Fk.skills[RULE_SKILL]
  if rule ~= nil then room:addSkill(rule) end
end

skill:addEffect(fk.DrawNCards, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and not target.dead and not player.dead
      and player:hasSkill(skill.name)
      and target.kingdom ~= "unknown"
      and B.sameKingdom(target, player)
      and data ~= nil and data.n ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(target, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin016_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.n = data.n + 1
    ensureRule(room)
    local list = room:getTag("hanjin_jin016_1_promises") or {}
    table.insert(list, { target = target.id, source = player.id })
    room:setTag("hanjin_jin016_1_promises", list)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_jin016_1"] = "复礼",
  ["#hanjin__skill_jin016_1-invoke"] = "复礼：你可以多摸一张，然后展示一张手牌并交给张华",
  ["#hanjin__skill_jin016_1-card"] = "复礼：选择展示并交给张华的一张手牌",
}

return skill
