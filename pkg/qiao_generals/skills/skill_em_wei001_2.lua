-- EM(WEI001) 曹操 · 挥鞭
-- 出牌阶段限一次：对一名魏势力角色造成1点伤害，令其摸两张牌，然后令另一名
-- 魏势力角色回复1点体力。受伤与回复者不同，均可为曹操本人。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"

local skill = fk.CreateSkill { name = W.HUIBIAN }
skill.qiaoImplemented = true

local function isWei(player)
  return player ~= nil and not player.dead and not player:isRemoved()
    and player.kingdom == "wei"
end

skill:addEffect("active", {
  prompt = "#qiao__em_wei001_huibian-prompt",
  target_num = 2,
  card_num = 0,
  max_phase_use_time = 1,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    if not isWei(to_select) then return false end
    if #selected == 0 then return true end
    if #selected == 1 then
      return to_select ~= selected[1] and to_select:isWounded()
    end
    return false
  end,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    local room = Fk:currentRoom()
    local wounded = table.find(room.alive_players, function(p)
      return isWei(p) and p:isWounded()
    end)
    return wounded ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local first, second = effect.tos[1], effect.tos[2]
    if player == nil or first == nil or second == nil then return end
    room:damage {
      from = player,
      to = first,
      damage = 1,
      skillName = skill.name,
    }
    if not first.dead then first:drawCards(2, skill.name) end
    if not player.dead and not second.dead and second:isWounded() then
      room:recover {
        who = second,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [W.HUIBIAN] = "挥鞭",
  [":" .. W.HUIBIAN] = "出牌阶段限一次，你可以对一名魏势力角色造成1点伤害，令其摸两张牌，然后令另一名魏势力角色回复1点体力。",
  ["#qiao__em_wei001_huibian-prompt"] = "挥鞭：选择一名魏势力角色造成伤害，再选择另一名已受伤的魏势力角色回复体力",
}

return skill
