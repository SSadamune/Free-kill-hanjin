-- WEI014 曹丕 · 放逐
--
-- 当你受到伤害后，你可以令一名其他角色叠置并摸两张牌，然后其可以弃置四张牌
-- 并平置，若牌名字数之和大于7，其失去1点体力。
-- 叠置/平置是定向操作：仅平置→叠置、叠置→平置；已叠置的目标再次叠置不产生
-- 变化，但后续摸牌与弃牌分支仍分别执行。手牌/装备合计不足四张时不提供弃牌
-- 分支（不能少弃）；弃牌须足额四张，牌名字数按实际弃置的牌逐张计算。
-- 国战“叠置/平置”对应引擎的 faceup：平置 faceup=true，叠置 faceup=false；
-- 使用原生 turnOver，保留翻面事件、跳回合与客户端朝向显示。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei014_2",
}
skill.hanjinImplemented = true

local function stackTo(player)
  -- 仅平置（faceup=true）改为叠置（faceup=false）。
  if player.faceup then
    player:turnOver()
  end
end

local function flatTo(player)
  -- 仅叠置（faceup=false）改为平置（faceup=true）。
  if not player.faceup then
    player:turnOver()
  end
end

--- 牌名字数：按当前实际牌面的中文牌名逐字符计数。
local function cardNameLength(card)
  local name = Fk:translate(card.name)
  local length = utf8.len(name)
  return length or #name
end

local function otherAlive(player)
  local room = player.room
  return table.filter(room:getOtherPlayers(player, false), function(p)
    return p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect(fk.Damaged, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and #otherAlive(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei014_2-invoke",
    }) then
      return false
    end
    local tos = room:askToChoosePlayers(player, {
      targets = otherAlive(player),
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei014_2-choose",
      cancelable = true,
    })
    local to = tos and tos[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = event:getCostData(self).to
    if to == nil or to.dead then return end

    -- 叠置：仅由平置改为叠置；已叠置不重复操作，但后续步骤继续。
    stackTo(to)
    to:drawCards(2, skill.name)
    if to.dead then return end

    -- 不足四张牌不能进入可选弃牌分支，也不执行平置与体力流失。
    if #to:getCardIds("he") < 4 then return end
    local cards = room:askToDiscard(to, {
      min_num = 4,
      max_num = 4,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei014_2-discard",
      cancelable = true,
    })
    if #cards ~= 4 then return end

    flatTo(to)
    local sum = 0
    for _, id in ipairs(cards) do
      sum = sum + cardNameLength(Fk:getCardById(id))
    end
    if sum > 7 and not to.dead then
      room:loseHp(to, 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei014_2-invoke"] = "放逐：你可以令一名其他角色叠置并摸两张牌",
  ["#hanjin__skill_wei014_2-choose"] = "放逐：选择一名其他角色",
  ["#hanjin__skill_wei014_2-discard"] = "放逐：你可以弃置四张牌并平置",
}

return skill
