local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"
local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_jin067_1" }
local function options(p)
  local room, list = p.room, {}
  for _, to in ipairs(room:getPresentPlayers()) do
    for _, id in ipairs(to:getCardIds("j")) do
      if to ~= p and to:canMoveCardInBoardTo(p, id) then table.insert(list, { id = id, to = p, judge = true }) end
    end
    for _, id in ipairs(p:getCardIds("he")) do
      local card = p:getVirtualEquip(id) or Fk:getCardById(id)
      if card.type == Card.TypeEquip and Placement.canPut(to, id, p) then table.insert(list, { id = id, to = to }) end
    end
  end
  return list
end
skill:addEffect(fk.EventPhaseChanging, {
  can_trigger = function(self, event, target, p, data) return target == p and data.phase == Player.Judge and not data.skipped and p:hasSkill(skill.name) and #options(p) > 0 end,
  on_cost = function(self, event, target, p)
    local opt, ids = options(p), {}
    for _, row in ipairs(opt) do table.insertIfNeed(ids, row.id) end
    if not S.invoke(p, skill.name) then return false end
    local id = p.room:askToChooseCard(p, { target = p, flag = { card_data = {{ skill.name, ids }} }, skill_name = skill.name })
    local selected = table.filter(opt, function(row) return row.id == id end)
    local tos = table.map(selected, function(row) return row.to end)
    local to = #tos == 1 and tos[1] or S.choose(p, tos, skill.name)[1]
    local row = table.find(selected, function(o) return o.to == to end)
    event:setCostData(self, row or {})
    return row ~= nil
  end,
  on_use = function(self, event, target, p, data)
    local row = event:getCostData(self)
    if not table.find(options(p), function(o) return o.id == row.id and o.to == row.to end) then return end
    if row.judge then
      local owner = p.room:getCardOwner(row.id)
      p.room:moveCards({ ids = { row.id }, from = owner, to = p, toArea = Card.PlayerJudge, moveReason = fk.ReasonPut,
        skillName = skill.name, proposer = p, virtualEquip = owner:getVirtualEquip(row.id) })
    else
      Placement.put(p.room, row.to, row.id, skill.name, p)
    end
    local destination = row.judge and Card.PlayerJudge or Card.PlayerEquip
    if p.room:getCardOwner(row.id) == row.to and p.room:getCardArea(row.id) == destination then
      data.phase = Player.Play
    end
  end,
})
return skill
