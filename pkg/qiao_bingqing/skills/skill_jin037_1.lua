local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local VirtualEquip = require "packages.qiao.pkg.qiao_bingqing.virtual_equipment"
local H = require "packages.hegemony.util"
local skill = fk.CreateSkill { name = "qiao__skill_jin037_1", tags = { Skill.Compulsory } }
local mark = "qiao_yangdao_grants"
local function weapons(p)
  local best, weapons = 0, {}
  if not S.present(p) or #p:getEquipments(Card.SubtypeWeapon) > 0 then return best, weapons end
  for _, owner in ipairs(Fk:currentRoom():getPresentPlayers()) do
    for _, id in ipairs(owner:getEquipments(Card.SubtypeWeapon)) do
      local card = owner:getVirtualEquip(id) or Fk:getCardById(id)
      local range = card:getAttackRange(owner)
      if range > best then best, weapons = range, {} end
      if range == best then table.insert(weapons, card) end
    end
  end
  return best, weapons
end
skill:addEffect("atkrange", {
  virtual_weapon_func = function(self, p)
    if p:hasShownSkill(skill.name) then local range = weapons(p); return range end
  end,
})
local function sync(p)
  local supplied = {}
  if p:hasShownSkill(skill.name, true) then
    local _, cards = weapons(p)
    supplied = VirtualEquip.skillNames(cards, p)
  end
  VirtualEquip.syncSkills(p, skill.name, mark, supplied, function(player)
    return player:getEquipments(Card.SubtypeWeapon)
  end)
end

skill:addEffect("invalidity", {
  recheck_invalidity = true,
  invalidity_func = function(self, p, checked)
    local skel = checked:getSkeleton()
    if not skel or not table.contains(p:getTableMark(mark), skel.name) then return false end
    return not p:hasShownSkill(skill.name)
  end,
})
skill:addAcquireEffect(function(self, p) sync(p) end)
skill:addLoseEffect(function(self, p) sync(p) end)
for _, timing in ipairs({ fk.AfterCardsMove, fk.AfterPropertyChange, fk.GeneralShown, fk.GeneralHidden, fk.Death, H.PlayerRemoved }) do
  skill:addEffect(timing, {
    can_refresh = function(self, event, target, p)
      return p:hasShownSkill(skill.name, true) or p:getMark(mark) ~= 0
    end,
    on_refresh = function(self, event, target, p) sync(p) end,
  })
end
return skill
