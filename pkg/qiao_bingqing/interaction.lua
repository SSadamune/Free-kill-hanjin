local Present = require("packages.qiao.pkg.qiao_mode.rules.removed_targets").isPresent
local M = {}

function M.choosePlayers(room, player, targets, name, max, optional)
  if #targets == 0 then return {} end
  return room:askToChoosePlayers(player, {
    targets = targets, min_num = 1, max_num = math.min(#targets, max or 1),
    skill_name = name, cancelable = optional == true,
  })
end

function M.give(room, from, to, cards, name)
  if #cards > 0 and from ~= to and Present(from) and Present(to) then
    room:moveCardTo(cards, Card.PlayerHand, to, fk.ReasonGive, name, nil, false, from)
  end
end

return M
