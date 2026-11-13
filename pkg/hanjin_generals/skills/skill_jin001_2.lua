-- JIN001 司马炎 · 兴图
--
-- 规则基线：rules/generals/jin001-simayan.md 第 3 节、rules/adaptation.md 与
-- rules/card-use-targets.md。回合内任意角色实际使用过应变牌即满足条件；以
-- 汉晋 A.isAdaptationCard(card, use) 判断“使用级”应变事实，不把实体材料牌
-- 的应变条目或 Triggered 成功事件当作条件。条件事实由全局监听记录，因此
-- 暗置、尚未获得技能或后来才获得技能都不抹去本回合已经发生的用牌。
local skill = fk.CreateSkill {
  name = "hanjin__skill_jin001_2",
}

--- Resolve HanJin mode modules lazily. Requiring them while the generals pack is
--- being loaded would initialize the mode package before its normal turn.
local function isAdaptationCard(card, use)
  return require("packages.hanjin.pkg.hanjin_mode.rules.adaptation").isAdaptationCard(card, use)
end

local function useTargetPolicy()
  return require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
end

local AUX = "#hanjin__skill_jin001_2_active"
local TRACK_TAG = "hanjin_jin001_2_adaptation_used"
local OPTION_EQUIP = "hanjin__skill_jin001_2-option_equip"
local OPTION_DRAW = "hanjin__skill_jin001_2-option_draw"
local PEACH = "hanjin__peach"

local function inHanjin(room)
  return room ~= nil and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == "hanjin_heg_mode"
end

--- Facts are bound to the current turn's room tag; PreTurnStart clears it.
local function clearTurnFact(room)
  room:setTag(TRACK_TAG, false)
end

--- 自己手牌区或装备区中的装备牌。
---@param player ServerPlayer
---@return integer[]
local function ownEquipments(player)
  return table.filter(player:getCardIds("he"), function(id)
    return Fk:getCardById(id).type == Card.TypeEquip
  end)
end

--- 第一项在本次时点是否至少存在一个合法目标（“一名角色”包括自己）。
--- 独立禁止使用/指定仍由目标策略在真正使用时复核。
---@param room Room
---@param player ServerPlayer
---@return boolean
local function optionEquipLegal(room, player)
  if #ownEquipments(player) == 0 then return false end
  local peach = Fk:cloneCard(PEACH)
  if player:prohibitUse(peach) then return false end
  for _, target in ipairs(room.alive_players) do
    if target:isAlive() and not target:isRemoved() and not player:isProhibited(target, peach) then
      return true
    end
  end
  return false
end

-- 条件事实记录：每回合准备时清空；任意角色实际使用一张应变牌时置位。
-- 这两个效果不要求司马炎当前拥有技能，否则暗置或后来获得技能前的事实会丢失。
skill:addEffect(fk.PreTurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and inHanjin(player.room)
  end,
  on_refresh = function(self, event, target, player)
    clearTurnFact(player.room)
  end,
})

skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and inHanjin(player.room)
      and data.card ~= nil and isAdaptationCard(data.card, data)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setTag(TRACK_TAG, true)
  end,
})

-- 第一项的选牌与选目标入口。牌必须是自己手牌区/装备区的装备牌；目标按
-- “一名角色”接入公共目标策略，独立禁止在服务端真正用牌前复核。
skill:addAuxActiveSkill(AUX, {
  can_use = function(self, player)
    return #ownEquipments(player) > 0
  end,
  card_num = 1,
  include_equip = true,
  card_filter = function(self, player, to_select, selected, selected_targets)
    return #selected < 1
      and table.contains(player:getCardIds("he"), to_select)
      and Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  target_num = 1,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if #selected >= 1 or to_select == nil then return false end
    if not to_select:isAlive() or to_select:isRemoved() then return false end
    return not player:isProhibited(to_select, Fk:cloneCard(PEACH))
  end,
})

skill:addEffect(fk.TurnEnd, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead
      and player.room:getTag(TRACK_TAG) == true
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local choices = {}
    if optionEquipLegal(room, player) then table.insert(choices, OPTION_EQUIP) end
    table.insert(choices, OPTION_DRAW)
    -- Single player-facing request: options plus Cancel. Cancelling returns false
    -- before SkillEffect, so no draw/use, no reveal and no skill-use history.
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin001_2-choice",
      cancelable = true,
    })
    if choice == nil or choice == "" or choice == "Cancel" then return false end
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = (event:getCostData(self) or {}).choice

    if choice == OPTION_DRAW then
      if not player.dead then player:drawCards(1, skill.name) end
      return
    end
    if choice ~= OPTION_EQUIP or player.dead then return end

    local ok, ret = room:askToUseActiveSkill(player, {
      skill_name = AUX,
      prompt = "#hanjin__skill_jin001_2-use",
      cancelable = true,
    })
    if not ok or ret == nil then return end
    local id = ret.cards and ret.cards[1]
    local to = ret.targets and ret.targets[1]
    if id == nil or to == nil or player.dead or to.dead or to:isRemoved() then return end
    if not table.contains(player:getCardIds("he"), id) then return end
    if Fk:getCardById(id).type ~= Card.TypeEquip then return end
    if player:isProhibited(to, Fk:cloneCard(PEACH)) then return end

    -- 完整执行一次真实的【桃】使用，不直接把回复体力当作技能效果。
    -- 效果只指定“一名角色”，按公共显式目标策略替换普通【桃】的牌面目标条件；
    -- 禁止使用/禁止指定仍由策略与用牌入口复核。
    local C = useTargetPolicy()
    C.useVirtualCard(room, player, PEACH, { id }, { to }, skill.name, false, nil,
      C.explicit({}, { names = { PEACH } }))
  end,
})

skill:addTest(function(room, me)
  if room:getSettings("gameMode") ~= "hanjin_heg_mode" then return end
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, skill.name, nil, false, true)
  end)
  lu.assertTrue(me:hasSkill(skill.name))
end)

Fk:loadTranslationTable {
  ["#hanjin__skill_jin001_2-invoke"] = "兴图：本回合有应变牌被使用过，你可以选择一项",
  ["#hanjin__skill_jin001_2-choice"] = "兴图：请选择一项",
  ["#hanjin__skill_jin001_2-use"] = "兴图：将一张装备牌当【桃】对一名角色使用",
  [OPTION_EQUIP] = "将一张装备牌当【桃】对一名角色使用",
  [OPTION_DRAW] = "摸一张牌",
}

return skill
