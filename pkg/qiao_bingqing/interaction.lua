local Present = require("packages.qiao.pkg.qiao_mode.rules.removed_targets").isPresent
local M = {}

function M.choosePlayers(room, player, targets, name, max, optional, prompt)
  if #targets == 0 then return {} end
  return room:askToChoosePlayers(player, {
    targets = targets, min_num = 1, max_num = math.min(#targets, max or 1),
    skill_name = name, cancelable = optional == true,
    prompt = prompt or "#qiao_bingqing_choose_players:::" .. name,
  })
end

function M.give(room, from, to, cards, name)
  if #cards > 0 and from ~= to and Present(from) and Present(to) then
    room:moveCardTo(cards, Card.PlayerHand, to, fk.ReasonGive, name, nil, false, from)
  end
end

Fk:loadTranslationTable { ["#qiao_bingqing_choose_players"] = "%arg：选择目标角色" }

return M
