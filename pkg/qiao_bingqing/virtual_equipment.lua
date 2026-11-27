local M = {}

function M.skillNames(cards, player)
  local names = {}
  for _, card in ipairs(cards) do
    for _, skill in ipairs(card:getEquipSkills(player)) do table.insertIfNeed(names, skill.name) end
  end
  return names
end

function M.cardsInEquipZone(player, ids)
  return table.map(ids, function(id) return player:getVirtualEquip(id) or Fk:getCardById(id) end)
end

--- 同步一项「视为装备」效果授予的装备技。
--- 实体装备可能因同名技能已经存在而略过授予，虚拟来源撤回时补回该实体来源。
function M.syncSkills(player, source, mark, supplied, physicalIds)
  local previous = player:getTableMark(mark)
  local wanted = table.filter(supplied, function(name)
    return table.contains(previous, name) or not player:hasSkill(name, true, true)
  end)
  local removed, added = {}, {}
  for _, name in ipairs(previous) do
    if not table.contains(wanted, name) then table.insert(removed, "-" .. name) end
  end
  for _, name in ipairs(wanted) do
    if not player:hasSkill(name, true, true) then table.insert(added, name) end
  end
  if #removed == 0 and #added == 0 then return end

  local room = player.room
  room:setPlayerMark(player, mark, #wanted > 0 and wanted or 0)
  room:handleAddLoseSkills(player, removed, source, false, true)
  room:handleAddLoseSkills(player, added, source, false, true)
  if #removed > 0 then
    local physical = M.cardsInEquipZone(player, physicalIds(player))
    local restore = table.filter(M.skillNames(physical, player), function(name)
      return table.contains(removed, "-" .. name) and not player:hasSkill(name, true, true)
    end)
    room:handleAddLoseSkills(player, restore, nil, false, true)
  end
end

return M
