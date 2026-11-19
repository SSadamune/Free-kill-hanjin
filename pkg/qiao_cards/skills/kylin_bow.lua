-- 麒麟弓：当你使用【杀】对目标角色造成伤害时，你可以弃置其装备区里的一张坐骑牌。
--
-- 伤害触发与坐骑筛选沿用锁定上游的标准包实现。本牌不能继续直接复用上游技能：
-- 其选牌请求以 card_data 表给出候选，而引擎只在 flag 为区域字符串时自动生成
-- "#AskForChooseCard:..."；表形式没有 prompt，AI 的
-- SmartAI:handleAskForCardChosen 会按 prompt 的第四段取技能名，prompt 为 nil 时
-- 在 prompt:split 崩溃。这里显式给出与引擎同格式的完整 prompt，人类与 AI 都保留
-- “只列坐骑候选、由伤害来源弃置到弃牌堆”的语义。
local skill = fk.CreateSkill {
  name = "qiao__kylin_bow_skill",
  attached_equip = "qiao__kylin_bow",
}

--- 目标装备区里的坐骑候选。双副类别坐骑也是坐骑牌，按其主副类别计入。
local function rideCards(to)
  return table.filter(to:getEquipCards(), function(card)
    return card.sub_type == Card.SubtypeDefensiveRide
      or card.sub_type == Card.SubtypeOffensiveRide
  end)
end

local function rideIds(to)
  return table.map(rideCards(to), function(card) return card:getEffectiveId() end)
end

skill:addEffect(fk.DamageCaused, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.to ~= nil and data.card ~= nil
      and data.card.trueName == "slash" and data.by_user
      and #rideCards(data.to) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    local ride_tab = rideIds(to)
    if #ride_tab == 0 then return end
    -- prompt 第四段必须是技能名：AI 的 handleAskForCardChosen 用
    -- prompt:split(":")[4] 查找策略，人类界面也用它显示“麒麟弓：请选择…”。
    local id = room:askToChooseCard(player, {
      target = to,
      flag = { card_data = { { "equip_horse", ride_tab } } },
      skill_name = skill.name,
      prompt = "#AskForChooseCard:" .. to.id .. "::" .. skill.name,
    })
    if id == nil then return end
    room:throwCard(id, skill.name, to, player)
  end,
})

skill:addAI(Fk.Ltk.AI.newInvokeStrategy {
  think = function(self, ai)
    ---@type DamageData
    local data = ai.room.logic:getCurrentEvent().data
    local player = ai.player
    local ret = player.ai:askToChooseCards({
      cards = rideIds(data.to),
      skill_name = skill.name,
      data = {
        toArea = Card.DiscardPile,
        reason = fk.ReasonDiscard,
        proposer = player,
      },
    })
    return ai:getBenefitOfEvents(function(logic)
      logic:throwCard(ret, skill.name, data.to, player)
    end) >= 0
  end,
})

Fk:loadTranslationTable {
  ["qiao__kylin_bow_skill"] = "麒麟弓",
}

return skill
