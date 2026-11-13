-- WEI007 甄姬 · 洛神
--
-- 规则基线：rules/standard-generals.md 魏区 WEI007、rulebook/events/judge.md。
-- 准备阶段判定；若为黑色可以重复，全部判定结束后统一获得所有黑色判定牌。
-- 一次性获得：先收集仍在可被取得区域（处理区/弃牌堆）的黑色判定牌，最后用
-- 一次 obtainCard 移动，避免逐张入手产生多次得到事件。
--
-- room:judge 的返回值不是 JudgeData：JudgeEventWrappers:judge 用 JudgeData:new
-- 包装传入的 spec，TriggerData 以原表为 _data，因此判定结果写回传入的 judge
-- 表；result 的 exec 返回值不可依赖。与上游 luoshen 一致，调用后读原表。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei007_2",
}

local BLACK = ".|.|black"

---@param room Room
---@param card Card
---@return boolean
local function obtainable(room, card)
  local area = room:getCardArea(card)
  return area == Card.DiscardPile or area == Card.Processing
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei007_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local blacks = {}
    while not player.dead do
      local judge = {
        who = player,
        reason = skill.name,
        pattern = BLACK,
      }
      room:judge(judge)
      local card = judge.card
      if card == nil then break end
      if card.color ~= Card.Black then break end
      table.insert(blacks, card)
      if player.dead then break end
      -- 黑色才可以选择重复此流程。
      if not room:askToSkillInvoke(player, {
        skill_name = skill.name,
        prompt = "#hanjin__skill_wei007_2-repeat",
      }) then
        break
      end
    end

    if player.dead or #blacks == 0 then return end
    -- 全部判定结束后，只收集当前仍在可被取得区域的黑色判定牌，一次性获得。
    local ids = {}
    for _, card in ipairs(blacks) do
      if obtainable(room, card) then
        local id = card:getEffectiveId()
        if id ~= nil then table.insert(ids, id) end
      end
    end
    if #ids == 0 then return end
    room:obtainCard(player, ids, true, fk.ReasonJustMove, nil, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei007_2"] = "洛神",
  [":hanjin__skill_wei007_2"] = "准备阶段，你可以判定，若为黑色，你可以重复此流程。然后你获得所有黑色的判定牌。",
  ["#hanjin__skill_wei007_2-invoke"] = "洛神：你可以进行判定",
  ["#hanjin__skill_wei007_2-repeat"] = "洛神：判定牌为黑色，是否重复此流程",
}

skill.hanjinImplemented = true

return skill
