-- SHU011 诸葛亮（卧龙） · 八阵
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU011。
-- 锁定技，若你的装备区里没有防具牌，你视为装备着【八卦阵】。
--
-- 实际效果直接调用正式汉晋【八卦阵】的装备技能（qiao__eight_diagram_skill），
-- 不复制判定与响应逻辑。该技能带 attached_equip，公共“无视防具”规则（青釭剑
-- 等）会照常把这座虚拟防具视为防具处理，因此无需在八阵内另行适配。
-- 八阵本身是锁定技，不属于铁骑“非锁定技失效”的对象；这里处理的是真正的
-- 来源变化：明置/暗置、移除技能与装备区防具变化。
--
-- 授予带八阵作为来源；同一玩家装备区真实八卦阵自带的同名技能来自装备本身，
-- 移除衍生来源时不会删掉真实来源。八阵未明置时不得单独提供虚拟八卦阵。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu011_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local ARMOR_SKILL = "qiao__eight_diagram_skill"
local SYNCING = "qiao__skill_shu011_1_syncing"

local function hasArmor(player)
  return #player:getEquipments(Card.SubtypeArmor) > 0
end

local function sync(room, player)
  if room == nil or player == nil or player.dead then return end
  if Fk.skills[ARMOR_SKILL] == nil then return end
  if player:getMark(SYNCING) > 0 then return end
  room:setPlayerMark(player, SYNCING, 1)
  if not player:hasShownSkill(skill.name) or hasArmor(player) then
    room:handleAddLoseSkills(player, "-" .. ARMOR_SKILL, skill.name, false, true)
  else
    room:handleAddLoseSkills(player, ARMOR_SKILL, skill.name, false, true)
  end
  room:setPlayerMark(player, SYNCING, 0)
end

-- 装备区防具变化。
skill:addEffect(fk.AfterCardsMove, {
  can_refresh = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player, data)
    sync(player.room, player)
  end,
})

-- 明置/暗置与换将：重新按“已明置且无防具”同步。
skill:addEffect(fk.GeneralRevealed, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player, data)
    sync(player.room, player)
  end,
})

skill:addEffect(fk.AfterPropertyChange, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player, data)
    sync(player.room, player)
  end,
})

skill:addAcquireEffect(function(self, player)
  sync(player.room or Fk:currentRoom(), player)
end)

skill:addLoseEffect(function(self, player)
  local room = player.room or Fk:currentRoom()
  if room ~= nil and not player.dead then
    room:handleAddLoseSkills(player, "-" .. ARMOR_SKILL, skill.name, false, true)
  end
end)

Fk:loadTranslationTable {
  ["qiao__skill_shu011_1"] = "八阵",
  [":qiao__skill_shu011_1"] = "锁定技，若你的装备区里没有防具牌，你视为装备着【八卦阵】。",
}

return skill
