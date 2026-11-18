-- 六龙骖驾：进攻/防御双副类别坐骑。锁定技，其他角色到装备者的距离 +X，
-- 装备者到其他角色的距离 -X。X 为场上与装备者势力相同的角色装备区里的
-- 坐骑牌总张数，每张牌计一次；装备者始终计入，全暗且势力未确定时只计自身。
local skill = fk.CreateSkill {
  name = "qiao__liulongcanjia_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__liulongcanjia",
}

Fk:loadTranslationTable {
  [skill.name] = "六龙骖驾",
  ["qiao__liulongcanjia"] = "六龙骖驾",
  [":" .. skill.name] = "锁定技，其他角色到你的距离+X，你到其他角色的距离-X"
    .. "（X为场上与你势力相同的角色装备区里的坐骑牌数，每张牌计一次）。",
}

local HegUtil = require "packages.hegemony.util"

--- 势力只读公开的当前势力，不使用构逆等与实际势力无关的关系标记。
--- 野心家按 HegUtil.getKingdom 的已确定势力判断，不把所有 wild 合并。
local function kingdomOf(player)
  local kingdom = HegUtil.getKingdom(player)
  if kingdom == "wild" and (type(player.role) ~= "string" or player.role == "") then
    return "unknown"
  end
  return kingdom
end

local function sameKingdom(holder, other)
  if holder == nil or other == nil then return false end
  if holder.id == other.id then return true end
  if other.dead or other:isRemoved() then return false end
  local mine, theirs = kingdomOf(holder), kingdomOf(other)
  return mine ~= nil and mine ~= "" and mine ~= "unknown"
    and theirs ~= nil and theirs ~= "" and theirs ~= "unknown"
    and mine == theirs
end

local function rideCards(player)
  local count = 0
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = player:getVirtualEquip(id) or Fk:getCardById(id)
    if card ~= nil and card.type == Card.TypeEquip
      and (card.sub_type == Card.SubtypeOffensiveRide
        or card.sub_type == Card.SubtypeDefensiveRide) then
      count = count + 1
    end
  end
  return count
end

--- 装备者始终计入；其他角色排除死亡与移出游戏。全暗且势力未确定时只计自身。
local function xFor(holder)
  if kingdomOf(holder) == "unknown" then return 1 end
  local room = Fk:currentRoom()
  local x = rideCards(holder)
  for _, player in ipairs(room.players) do
    if player.id ~= holder.id and sameKingdom(holder, player) then
      x = x + rideCards(player)
    end
  end
  return x
end

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    local delta = 0
    if from:hasSkill(skill.name) then delta = delta - xFor(from) end
    if to:hasSkill(skill.name) then delta = delta + xFor(to) end
    return delta
  end,
})

return skill
