-- JIN015 石苞 · 前驱
--
-- 规则基线：rules/generals/jin015-shibao.md、rules/adaptation.md、
-- rulebook/terms/description-terms/and.md。
-- 与你势力相同的角色（含自己）准备阶段，你可以使用一张无距离限制的【杀】。
-- 真实发动走 TriggerSkill 的 on_cost/on_use 与 room:useSkill；取消选择不产生
-- Slash 使用事件，也不以 refresh 代替技能来源。用牌入口允许合法转化，不凭空
-- 生成杀；本次使用附加〈助战→弃置目标角色装备区里的一张牌〉。完整用牌结束后
-- 若此【杀】真实造成伤害，“当前回合角色获得此杀并摸一张牌”按“并”处理：只有
-- 仍能取得实体材料时才执行获得并摸牌，不能凭空创建材料或单方面摸牌。
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local B = require "packages.qiao.pkg.qiao_generals.util.jin_basic"
local J = require "packages.qiao.pkg.qiao_generals.util.jin_adaptation"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin015_1",
}
skill.qiaoImplemented = true

local MARK = "qiao_skill_jin015_1"
local ENTRY_ID = "qiao__skill_jin015_1_support"
local SLASH_NAMES = {
  "slash",
  "qiao__slash",
  "qiao__fire__slash",
  "qiao__thunder__slash",
  "qiao__ice__slash",
  "qiao__thunder_shell__slash",
}

local function slashPolicy()
  return C.bypassDistance({ names = SLASH_NAMES })
end

local function hasPossibleUser(player)
  if player == nil or player.dead then return false end
  if #player:getCardIds("he") == 0 then return false end
  return table.find(player.room.alive_players, function(p)
    return p ~= player and not p.dead and not p:isRemoved()
  end) ~= nil
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target.phase == Player.Start
      and not player.dead and player:hasSkill(skill.name)
      and not target.dead and B.sameKingdom(target, player)
      and hasPossibleUser(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin015_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local policy = slashPolicy()
    local use = C.askToUseCard(room, player, {
      names = SLASH_NAMES,
      pattern = "slash",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin015_1-use",
      cancelable = true,
      policy = policy,
      extra_data = { bypass_times = true, extraUse = true },
    })
    if use == nil or use.card == nil then return end
    -- askToUseCard 只构造使用数据，不执行；本次使用仍需真实进入 room:useCard。
    use.extra_data = use.extra_data or {}
    use.extra_data.bypass_times = true
    use.extra_data.extraUse = true
    use.extraUse = true
    A.addEntry(use, {
      id = ENTRY_ID,
      condition = "zhuzhan",
      effect = "discard_target_equip",
    })
    use.extra_data[MARK] = true
    C.useCard(room, player, use, policy)
  end,
})

skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
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
    room:obtainCard(receiver, card, true, fk.ReasonJustMove, player, skill.name)
    if receiver.dead then return end
    for _, id in ipairs(ids) do
      if room:getCardOwner(id) ~= receiver then return end
    end
    receiver:drawCards(1, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin015_1"] = "前驱",
  ["#qiao__skill_jin015_1-invoke"] = "前驱：你可以使用一张无距离限制的【杀】",
  ["#qiao__skill_jin015_1-use"] = "前驱：选择一张【杀】使用（无距离限制）",
}

return skill
