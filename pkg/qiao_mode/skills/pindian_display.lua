local U = require "packages.utility.utility"
local skill = fk.CreateSkill { name = "#qiao_pindian_display" }

local function shownCard(player, card)
  local id = card:getEffectiveId()
  local face = id and Fk:getCardById(id, true) or card
  return {
    seat = player.seat, name = card.name, suit = card:getSuitString(),
    rank = face:getNumberStr(), number = face.number, points = card.number,
  }
end

skill:addEffect(fk.StartPindian, {
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    player.room:doBroadcastNotify("QiaoPindianStart", {})
  end,
})

skill:addEffect(fk.PindianFinished, {
  can_refresh = function(self, event, target, player, data)
    return target == player and data.from == player and data.fromCard ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local joint = data:isInstanceOf(U.JointPindianData)
    local cards = { shownCard(player, data.fromCard) }
    for _, to in ipairs(data.tos) do
      local result = data.results[to]
      if result and result.toCard then
        local row = shownCard(to, result.toCard)
        if not joint then
          row.winner = result.winner and result.winner.seat or 0
          -- 核心战报把发起者的平点和落败都写作“没赢”。共同拼点已有独立胜负战报。
          if result.winner ~= player then
            room:sendLog {
              type = result.winner and "#QiaoPindianWinner" or "#QiaoPindianTie",
              from = player.id, to = { to.id }, arg = row.winner,
            }
          end
        end
        table.insert(cards, row)
      end
    end
    if #cards > 1 then
      room:doBroadcastNotify("QiaoPindianResult", {
        cards = cards, joint = joint, winner = data.winner and data.winner.seat or 0,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["#QiaoPindianWinner"] = "%from 与 %to 的拼点结果：%arg 号位赢得拼点",
  ["#QiaoPindianTie"] = "%from 与 %to 拼点平点，双方都没赢",
}

return skill
