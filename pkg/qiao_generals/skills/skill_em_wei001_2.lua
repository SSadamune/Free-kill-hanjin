-- EM(WEI001) 曹操 · 挥鞭
-- 出牌阶段限一次：对一名魏势力角色造成1点伤害，令其摸两张牌，然后令另一名
-- 魏势力角色回复1点体力。受伤与回复者不同，均可为曹操本人。
--
-- “然后”的后段不能倒推前段：首段只要求一名魏势力角色，伤害与摸牌结算后
-- 才检查另一名可回复的魏势力角色；没有合法回复者时只完成首段。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"

local skill = fk.CreateSkill { name = W.HUIBIAN }
skill.qiaoImplemented = true

local function isWei(player)
  return player ~= nil and not player.dead and not player:isRemoved()
    and player.kingdom == "wei"
end

--- 首段结算后可回复的对象：另一名已受伤的魏势力角色。
local function recoverTargets(room, first)
  local result = {}
  for _, p in ipairs(room:getPresentPlayers()) do
    if p ~= first and isWei(p) and p:isWounded() then
      result[#result + 1] = p
    end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__em_wei001_huibian-prompt",
  target_num = 1,
  card_num = 0,
  max_phase_use_time = 1,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    -- 首段只按魏势力判定；受伤与“另一名”属于后段，不参与首段目标资格。
    if #selected > 0 then return false end
    return isWei(to_select)
  end,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    local room = Fk:currentRoom()
    return table.find(room:getPresentPlayers(), isWei) ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local first = effect.tos and effect.tos[1]
    if player == nil or player.dead or not isWei(first) then return end
    room:damage {
      from = player,
      to = first,
      damage = 1,
      skillName = skill.name,
    }
    if not first.dead then first:drawCards(2, skill.name) end
    if player.dead then return end

    local targets = recoverTargets(room, first)
    if #targets == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#qiao__em_wei001_huibian-recover",
      cancelable = false,
    })
    local second = chosen and chosen[1]
    if second == first or not isWei(second) or not second:isWounded() then return end
    room:recover {
      who = second,
      num = 1,
      recoverBy = player,
      skillName = skill.name,
    }
  end,
})

Fk:loadTranslationTable {
  [W.HUIBIAN] = "挥鞭",
  [":" .. W.HUIBIAN] = "出牌阶段限一次，你可以对一名魏势力角色造成1点伤害，令其摸两张牌，然后令另一名魏势力角色回复1点体力。",
  ["#qiao__em_wei001_huibian-prompt"] = "挥鞭：选择一名魏势力角色承受伤害并摸两张牌",
  ["#qiao__em_wei001_huibian-recover"] = "挥鞭：选择另一名已受伤的魏势力角色回复1点体力",
}

return skill
