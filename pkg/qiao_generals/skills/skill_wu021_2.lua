-- WU021 凌统 · 勇进
-- 限定技，出牌阶段，你可以依次移动场上至多三张各不同的装备牌。
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu021_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_wu021_2-prompt",
  max_game_use_time = 1,
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryGame) > 0 then return false end
    local froms = Bian.boardEquipParticipants(Fk:currentRoom(), nil, player)
    return #froms > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local movedIds = {}
    for step = 1, 3 do
      if player == nil or player.dead or player:isRemoved() then break end
      local froms = Bian.boardEquipParticipants(room, movedIds, player)
      if #froms == 0 then break end
      local cancelable = step > 1
      local pickedFrom = room:askToChoosePlayers(player, {
        targets = froms,
        min_num = 1,
        max_num = 1,
        skill_name = skill.name,
        prompt = "#qiao__skill_wu021_2-from:::" .. tostring(step),
        cancelable = cancelable,
      })
      local from = pickedFrom and pickedFrom[1]
      if from == nil or from.dead or from:isRemoved() then break end

      local movableIds = {}
      local present = room:getPresentPlayers()
      for _, id in ipairs(from:getCardIds(Player.Equip)) do
        if not movedIds[id] then
          local hasDest = table.find(present, function(to)
            return Bian.canMoveEquipTo(from, to, id, player)
          end) ~= nil
          if hasDest then table.insert(movableIds, id) end
        end
      end
      if #movableIds == 0 then break end

      local cardId
      if #movableIds == 1 then
        cardId = movableIds[1]
      else
        local chosen = room:askToChooseCards(player, {
          target = from,
          flag = { card_data = { { "seat#" .. tostring(from.seat), movableIds } } },
          min = 1,
          max = 1,
          skill_name = skill.name,
          prompt = "#qiao__skill_wu021_2-card::" .. from.id,
          cancelable = cancelable,
        })
        cardId = chosen and chosen[1]
      end
      if cardId == nil or movedIds[cardId] or not table.contains(from:getCardIds(Player.Equip), cardId) then
        break
      end

      local validTos = table.filter(room:getPresentPlayers(), function(to)
        return Bian.canMoveEquipTo(from, to, cardId, player)
      end)
      if #validTos == 0 then break end
      local pickedTo = room:askToChoosePlayers(player, {
        targets = validTos,
        min_num = 1,
        max_num = 1,
        skill_name = skill.name,
        prompt = "#qiao__skill_wu021_2-to:::" .. Fk:getCardById(cardId):toLogString(),
        cancelable = cancelable,
      })
      local to = pickedTo and pickedTo[1]
      if to == nil or not Bian.canMoveEquipTo(from, to, cardId, player) then break end

      local cardToMove = from:getVirtualEquip(cardId) or Fk:getCardById(cardId)
      if cardToMove == nil then break end
      movedIds[cardId] = true
      room:moveCardTo(cardToMove, Player.Equip, to, fk.ReasonPut, skill.name, nil, true, player)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "勇进",
  [":" .. skill.name] = "限定技，出牌阶段，你可以依次移动场上至多三张各不同的装备牌。",
  ["#qiao__skill_wu021_2-prompt"] = "勇进：依次移动场上至多三张各不同的装备牌",
  ["#qiao__skill_wu021_2-from"] = "勇进（第%arg/3张）：选择要移出装备牌的角色",
  ["#qiao__skill_wu021_2-card"] = "勇进：选择 %dest 装备区里要移动的装备牌",
  ["#qiao__skill_wu021_2-to"] = "勇进：选择接收 %arg 的角色",
}

return skill
