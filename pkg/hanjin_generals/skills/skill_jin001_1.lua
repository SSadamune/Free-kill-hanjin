-- JIN001 司马炎 · 垂统
--
-- 规则基线：rules/generals/jin001-simayan.md 第 2 节，以及
-- rules/equipment-movement.md。时机是其他角色进入濒死（EnterDying），不是
-- 每次求桃；只移动该角色装备区的合法牌到司马炎空置的对应装备栏，不替换。
local skill = fk.CreateSkill {
  name = "hanjin__skill_jin001_1",
}

--- 濒死角色装备区中可移入司马炎空置对应栏的牌。
--- `canMoveCardInBoardTo` 同时检查目标栏存在、未废除且为空。
---@param source ServerPlayer
---@param to ServerPlayer
---@return integer[]
local function legalEquipments(source, to)
  return table.filter(source:getCardIds(Player.Equip), function(id)
    return source:canMoveCardInBoardTo(to, id)
  end)
end

skill:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target == player or player.dead or not player:hasSkill(skill.name) then return false end
    return #legalEquipments(target, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin001_1-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 重新计算候选：发动询问期间装备区可能已变化。
    local ids = legalEquipments(target, player)
    if #ids == 0 or target.dead or player.dead then return end
    local card = room:askToChooseCard(player, {
      target = target,
      flag = { card_data = { { "$Equip", ids } } },
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin001_1-choose",
    })
    if card == nil or not table.contains(ids, card) then return end
    -- 选择后、移动前再次复核来源归属与目标空栏，避免替换已有装备或移动已失效的牌。
    if player.dead or target.dead then return end
    if not table.contains(target:getCardIds(Player.Equip), card) then return end
    if not target:canMoveCardInBoardTo(player, card) then return end
    room:moveCardIntoEquip(player, card, skill.name, false, target)
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
  ["#hanjin__skill_jin001_1-invoke"] = "垂统：你可以将 %dest 装备区的一张牌移动给你",
  ["#hanjin__skill_jin001_1-choose"] = "垂统：选择其装备区一张可移入你空置装备栏的牌",
}

return skill
