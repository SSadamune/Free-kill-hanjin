-- 双副类别坐骑公共规则：六龙骖驾/临筱玉舆持有者距离-1、他人到其+1，
-- 持有期间不能使用其他坐骑。
local CARDS = { ["qiao__liulongcanjia"] = true, ["qiao__linxiao_yuyu"] = true }

local skill = fk.CreateSkill { name = "qiao__dual_mount_rule" }

local function hasDual(player)
  if player == nil then return false end
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and CARDS[card.name] then return true end
  end
  return false
end

local function isRide(card)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  for _, subtype in ipairs(card.subtypes or { card.sub_type }) do
    if subtype == Card.SubtypeOffensiveRide or subtype == Card.SubtypeDefensiveRide then return true end
  end
  return false
end

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    local n = 0
    if hasDual(from) then n = n - 1 end
    if hasDual(to) then n = n + 1 end
    return n
  end,
})

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return hasDual(player) and isRide(card)
  end,
})

-- 非使用置入也须拒绝：持有双坐骑时，其他单坐骑不能进入其装备区。
skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    for _, move in ipairs(data or {}) do
      if move.to ~= nil and move.toArea == Card.PlayerEquip and hasDual(move.to) then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = info.beforeCard or Fk:getCardById(info.cardId, true)
          if isRide(card) and not CARDS[card.name] then return true end
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    for _, move in ipairs(data or {}) do
      if move.to ~= nil and move.toArea == Card.PlayerEquip and hasDual(move.to) then
        local keep = {}
        for _, info in ipairs(move.moveInfo or {}) do
          local card = info.beforeCard or Fk:getCardById(info.cardId, true)
          if not (isRide(card) and not CARDS[card.name]) then table.insert(keep, info) end
        end
        move.moveInfo = keep
      end
    end
  end,
})

return skill
