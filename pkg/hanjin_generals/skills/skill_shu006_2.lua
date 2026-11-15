local skill = fk.CreateSkill {
  name = "hanjin__skill_shu006_2",
}
skill.hanjinImplemented = true

local POS = "hanjin__skill_shu006_2_positions-turn"

Fk:loadTranslationTable {
  ["hanjin__skill_shu006_2"] = "铁骑",
  [":hanjin__skill_shu006_2"] = "当你使用【杀】指定一个目标后，你可以令其一张武将牌本回合非锁定技失效，然后你判定，除非其展示手牌并弃置结果花色的所有牌，否则其不能响应此【杀】。",
  ["#hanjin__skill_shu006_2-invoke"] = "铁骑：是否令目标一张武将牌的非锁定技本回合失效并判定？",
  ["#hanjin__skill_shu006_2-ask"] = "铁骑：选择目标一张武将牌（不展示身份）",
  ["#hanjin__skill_shu006_2-main"] = "主将",
  ["#hanjin__skill_shu006_2-deputy"] = "副将",
  ["#hanjin__skill_shu006_2-discard"] = "铁骑：展示并弃置判定花色的所有手牌，否则不能响应此【杀】",
}

local function positionGeneral(to, pos)
  if pos == "main" then
    return to.general ~= "" and (to.general ~= "anjiang" and to.general or to:getMark("__heg_general")) or nil
  end
  return to.deputyGeneral ~= "" and (to.deputyGeneral ~= "anjiang" and to.deputyGeneral or to:getMark("__heg_deputy")) or nil
end

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == "slash" and data.to ~= nil and data.to ~= player
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu006_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local positions = {}
    if positionGeneral(to, "main") ~= nil then table.insert(positions, "main") end
    if positionGeneral(to, "deputy") ~= nil then table.insert(positions, "deputy") end
    if #positions > 0 then
      local choices = {}
      for _, pos in ipairs(positions) do
        table.insert(choices, pos == "main" and "#hanjin__skill_shu006_2-main" or "#hanjin__skill_shu006_2-deputy")
      end
      local choice = room:askToChoice(player, {
        choices = choices,
        skill_name = skill.name,
        prompt = "#hanjin__skill_shu006_2-ask::" .. to.id,
      })
      local selected = (choice == "#hanjin__skill_shu006_2-main") and "main" or "deputy"
      local old = to:getTableMark(POS)
      if type(old) ~= "table" then old = {} end
      if not table.contains(old, selected) then table.insert(old, selected) end
      room:setPlayerMark(to, POS, old)
    end

    local judge = { who = player, reason = skill.name }
    room:judge(judge)
    if judge.card == nil or judge.card.suit == Card.NoSuit then
      data:setDisresponsive(to)
      return
    end
    local suit = judge.card:getSuitString()
    local matches = {}
    for _, id in ipairs(to:getCardIds("h")) do
      if Fk:getCardById(id).suit == judge.card.suit then table.insert(matches, id) end
    end
    if #matches == 0 then
      data:setDisresponsive(to)
      return
    end
    if not room:askToSkillInvoke(to, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu006_2-discard:::" .. suit,
    }) then
      data:setDisresponsive(to)
      return
    end
    to:showCards(to:getCardIds("h"), player)
    local discarded = room:askToDiscard(to, {
      min_num = #matches,
      max_num = #matches,
      include_equip = false,
      skill_name = skill.name,
      pattern = ".|.|" .. suit,
      prompt = "#hanjin__skill_shu006_2-discard:::" .. suit,
      cancelable = true,
    })
    if discarded == nil or #discarded < #matches then
      data:setDisresponsive(to)
    end
  end,
})

return skill
