-- SHU013 刘禅 · 享乐
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU013。
-- 锁定技，当你成为【杀】的目标后，你令使用者选择一项：
--   1. 弃置一张基本牌；2. 此【杀】对你无效。
-- 由使用者选择并由其支付弃牌；没有可弃置的基本牌时只能选择第 2 项。
-- 无效只作用于当前目标，不取消其他目标。
local skill = fk.CreateSkill {
  name = "hanjin__skill_shu013_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local OPT_DISCARD = "#hanjin__skill_shu013_1-discard"
local OPT_NULLIFY = "#hanjin__skill_shu013_1-nullify"

local function discardableBasics(player)
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.type == Card.TypeBasic
      and not player:prohibitDiscard(id)
  end)
end

skill:addEffect(fk.TargetConfirmed, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and data.card ~= nil and data.card.trueName == "slash"
      and data.from ~= nil and data.from ~= player and data.from:isAlive()
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local user = data.from
    if user == nil or user.dead then return end

    local basics = discardableBasics(user)
    local choice
    if #basics == 0 then
      choice = OPT_NULLIFY
    else
      choice = room:askToChoice(user, {
        choices = { OPT_DISCARD, OPT_NULLIFY },
        skill_name = skill.name,
        prompt = "#hanjin__skill_shu013_1-choice:" .. player.id,
        cancelable = false,
      })
    end

    if choice == OPT_DISCARD then
      local ids = room:askToCards(user, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        pattern = tostring(Exppattern { id = basics }),
        skill_name = skill.name,
        prompt = "#hanjin__skill_shu013_1-card",
        cancelable = false,
      })
      if ids ~= nil and #ids == 1 and table.contains(discardableBasics(user), ids[1]) then
        -- 由使用者自己选择并弃置：弃牌者与操作者（proposer）都是杀的使用者。
        room:throwCard(ids, skill.name, user, user)
        return
      end
    end

    data:setNullified(player)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_shu013_1"] = "享乐",
  [":hanjin__skill_shu013_1"] = "锁定技，当你成为【杀】的目标后，你令使用者选择一项：1.弃置一张基本牌；2.此【杀】对你无效。",
  ["#hanjin__skill_shu013_1-choice"] = "享乐：弃置一张基本牌，或令此【杀】对其无效",
  ["#hanjin__skill_shu013_1-card"] = "享乐：选择一张基本牌弃置",
  [OPT_DISCARD] = "弃置一张基本牌",
  [OPT_NULLIFY] = "此【杀】对其无效",
}

return skill
