local S = require "packages.qiao.pkg.qiao_bingqing.shi"
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
-- 装备区和【养刀】可以先后提供相同的武器技。只记录【养刀】实际授予的技能。
local function physicalSkills(p)
  local names = {}
  for _, id in ipairs(p:getEquipments(Card.SubtypeWeapon)) do
    local card = p:getVirtualEquip(id) or Fk:getCardById(id)
    for _, sk in ipairs(card:getEquipSkills(p)) do table.insertIfNeed(names, sk.name) end
  end
  return names
end

local function sync(p)
  local previous, wanted = p:getTableMark(mark), {}
  if p:hasShownSkill(skill.name, true) then
    local _, cards = weapons(p)
    for _, card in ipairs(cards) do
      for _, sk in ipairs(card:getEquipSkills(p)) do
        if table.contains(previous, sk.name) or not p:hasSkill(sk, true, true) then
          table.insertIfNeed(wanted, sk.name)
        end
      end
    end
  end
  local removed, added = {}, {}
  for _, name in ipairs(previous) do
    if not table.contains(wanted, name) then table.insert(removed, "-" .. name) end
  end
  for _, name in ipairs(wanted) do
    if not p:hasSkill(name, true, true) then table.insert(added, name) end
  end
  if #removed > 0 or #added > 0 then
    p.room:setPlayerMark(p, mark, #wanted > 0 and wanted or 0)
    p.room:handleAddLoseSkills(p, removed, skill.name, false, true)
    p.room:handleAddLoseSkills(p, added, skill.name, false, true)
    -- 同名实体武器安装时，引擎会跳过已有的技能。撤销虚拟来源后补回实体来源。
    if #removed > 0 then
      local physical = table.filter(physicalSkills(p), function(name)
        return table.contains(removed, "-" .. name) and not p:hasSkill(name, true, true)
      end)
      p.room:handleAddLoseSkills(p, physical, nil, false, true)
    end
  end
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
