local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local H = require "packages.hegemony.util"
local skill = fk.CreateSkill { name = "qiao__skill_han047_2" }
local function candidates(player)
  return table.filter(player.room:getPresentPlayers(), function(p) return p ~= player and not p.dying and p.hp > 0 end)
end
skill:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player)
    return target == player and player.room.current == player and player:hasSkill(skill.name) and #candidates(player) > 0
  end,
  on_cost = function(self, event, target, player)
    local to = S.pick(player.room, player, candidates(player), skill.name, true, nil,
      "#qiao__skill_han047_2-remove")[1]
    event:setCostData(self, { to = to })
    return to ~= nil
  end,
  on_use = function(self, event, target, player)
    local room, to = player.room, event:getCostData(self).to
    if not table.contains(candidates(player), to) then return end
    room:setPlayerMark(to, MarkEnum.PlayerRemoved .. "-turn", 1)
    room:setPlayerMark(to, "@@lure_tiger-turn", 1)
    room.logic:trigger(H.PlayerRemoved, to, { who = to })
    local present = room:getPresentPlayers()
    if #present ~= 2 or not S.present(player) then return end
    local other = present[1] == player and present[2] or present[1]
    player:drawCards(2, skill.name)
    if S.present(other) and S.present(player) and not player:isNude() then
      S.give(room, player, other, room:askToCards(player, {
        min_num = 1, max_num = 1, include_equip = true, skill_name = skill.name, cancelable = false,
        prompt = "#qiao__skill_han047_2-give::" .. other.id,
      }), skill.name)
    end
    S.exchange(room, other, S.pairs(room, other, player, nil, "qiao_heg__han047"), skill.name, true)
  end,
})
Fk:loadTranslationTable {
  ["#qiao__skill_han047_2-remove"] = "径出：选择一名角色，令其本回合移出游戏",
  ["#qiao__skill_han047_2-give"] = "径出：选择一张牌交给 %dest",
}
return skill
