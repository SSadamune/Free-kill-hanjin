-- HAN019 吉平·蛊毒的回合末延时规则。
-- 来源按武将牌实际所在的主/副将位置查找，交换到他人或另一位置后仍移除该牌；
-- 若原位置已换成新将或士兵，则不操作原位置。
local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local PENDING = "qiao_han019_venom_pending"
local skill = fk.CreateSkill { name = "qiao__han019_venom_rule" }

---@param room Room
---@param source string
---@return ServerPlayer?, boolean?
local function locateSource(room, source)
  if type(source) ~= "string" or source == "" or Exchange.isSoldier(source) then return nil end
  for _, owner in ipairs(room:getPresentPlayers()) do
    for _, isDeputy in ipairs({ false, true }) do
      local current = Exchange.actualGeneral(owner, isDeputy)
      if current == source and not Exchange.isSoldier(current) then
        return owner, isDeputy
      end
    end
  end
  return nil
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and #(player.room:getTag(PENDING) or {}) > 0
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    local list = room:getTag(PENDING) or {}
    room:setTag(PENDING, {})
    for _, entry in ipairs(list) do
      local targetPlayer = room:getPlayerById(entry.target)
      if targetPlayer ~= nil and not targetPlayer.dead then
        room:loseHp(targetPlayer, 1, "qiao__skill_han019_2")
        if targetPlayer:isAlive() then
          local owner, isDeputy = locateSource(room, entry.source)
          if owner ~= nil then H.removeGeneral(owner, isDeputy) end
        end
      end
    end
  end,
})

return skill
