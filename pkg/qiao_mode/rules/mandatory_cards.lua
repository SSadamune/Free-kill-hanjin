local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local M = {}

local function ownCandidates(player, params)
  local ids = player:getCardIds(params.include_equip and "he" or "h")
  local pile = params.expand_pile
  if type(pile) == "string" then pile = player:getPile(pile) end
  if type(pile) == "table" then table.insertTableIfNeed(ids, pile) end
  local pattern = Exppattern:Parse(params.pattern or (params.include_equip and "." or ".|.|.|hand"))
  return table.filter(ids, function(id)
    return pattern:match(Fk:getCardById(id))
  end)
end

local function chosenCandidates(params)
  if type(params.flag) == "string" and params.target then
    return params.target:getCardIds(params.flag)
  elseif type(params.flag) == "table" and params.flag.card_data then
    local ids = {}
    for _, group in ipairs(params.flag.card_data) do
      table.insertTableIfNeed(ids, group[2])
    end
    return ids
  end
  return {}
end

-- 仅处理必选的标准选牌；可取消请求或另有界面选择的请求照常交给引擎。
function M.install(room)
  local askToCards = room.askToCards
  function room:askToCards(player, params)
    if params.cancelable == false and params.min_num == 1 and params.max_num >= 1
      and params.visible_pile == nil and not RemovedTargets.isRemoved(player) then
      local ids = ownCandidates(player, params)
      if #ids == 1 then return ids end
    end
    return askToCards(self, player, params)
  end

  local chooseCard = room.askToChooseCard
  function room:askToChooseCard(player, params)
    if not params.cancelable and not params.pattern and not RemovedTargets.isRemoved(player) then
      local ids = chosenCandidates(params)
      if #ids == 1 then return ids[1] end
    end
    return chooseCard(self, player, params)
  end
end

return M
