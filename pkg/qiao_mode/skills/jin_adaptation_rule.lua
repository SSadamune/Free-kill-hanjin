-- 晋应变批次：已建立用牌属性的房间级结算。
--
-- 乘流在 PreCardUse 给本次伤害牌写入 use.extra_data.qiao_damage_type；本次使用
-- 中途即使王濬失去乘流或死亡，已经建立的“此牌造成雷电伤害”仍应生效。因此
-- 雷伤改写不能依赖技能持有者当前是否仍有乘流，而由本房间规则只按本次 use 标记
-- 执行。规则由乘流在赋条目时按需加入房间；模式也可在开局统一 addSkill，二者
-- 都以房间是否已有同名技能去重。
local J = require "packages.qiao.pkg.qiao_generals.util.jin_adaptation"

local skill = fk.CreateSkill {
  name = "qiao__jin_adaptation_rule",
  tags = { Skill.Compulsory },
}

skill:addEffect(fk.PreDamage, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return J.useDamageType(player.room, data) ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    data.damageType = J.useDamageType(player.room, data) or data.damageType
  end,
})

local MARK = "qiao_skill_jin015_1"
skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player
      and data.card ~= nil and data.card.trueName == "slash"
      and (data.extra_data or {})[MARK] == true
      and J.dealtDamage(data)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.extra_data[MARK] = nil
    local room = player.room
    local receiver = room.current
    if receiver == nil or receiver.dead then return end

    -- “获得此杀并摸一张牌”是“并”：只取得仍在处理区、本次使用仍可获得的实体
    -- 材料；完全没有材料时两个操作都不能执行。纯虚拟牌不创建实体材料。
    local ids = room:getSubcardsByRule(data.card, { Card.Processing })
    if #ids == 0 then return end
    local card = Fk:cloneCard(data.card.name, data.card.suit, data.card.number)
    card:addSubcards(ids)
    room:obtainCard(receiver, card, true, fk.ReasonJustMove, player, "qiao__skill_jin015_1")
    if receiver.dead then return end
    for _, id in ipairs(ids) do
      if room:getCardOwner(id) ~= receiver then return end
    end
    receiver:drawCards(1, "qiao__skill_jin015_1")
  end,
})

Fk:loadTranslationTable {
  ["qiao__jin_adaptation_rule"] = "晋应变结算",
}

return skill
