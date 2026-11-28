local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"
local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local Y = require "packages.qiao.pkg.qiao_bingqing.bajia"
local skill = fk.CreateSkill { name = "qiao__skill_han043_1", tags = { Skill.Compulsory } }
local function legal(p, to)
  return table.filter(to:getCardIds("e"), function(id) return Placement.canPut(p, id) end)
end
skill:addEffect(fk.GeneralRevealed, {
  can_trigger = function(self, event, target, p)
    return p == target and Y.reveal.available(p, skill.name)
      and table.find(p.room:getPresentPlayers(), function(to) return to ~= p and #legal(p, to) > 0 end)
  end,
  on_cost = function(self, event, target, p) return Y.reveal.take(p, skill.name) end,
  on_use = function(self, event, target, p)
    local room = p.room
    local sources = table.filter(room:getPresentPlayers(), function(to) return to ~= p and #legal(p, to) > 0 end)
    local owner = S.choose(p, sources, skill.name)[1]
    if not owner then return end
    local ids = legal(p, owner)
    local id = room:askToChooseCard(p, { target = owner, flag = { card_data = {{ "$Equip", ids }} }, skill_name = skill.name,
      prompt = "#qiao_bajia-equip::" .. owner.id })
    if not table.contains(ids, id) then return end
    Placement.put(room, p, id, skill.name)
    if room:getCardOwner(id) == p and room:getCardArea(id) == Card.PlayerEquip then
      room:addTableMarkIfNeed(p, Y.mark, id)
      room:setCardMark(Fk:getCardById(id, true), "@qiao_bajia_yu", 1)
      Y.updateRoom(room)
    end
  end,
})
-- 状态清除与是否发动第四段分开。把本次失去的张数留在移动事件内，
-- 亮将取新装备带来的嵌套移动不会覆盖原事件。
skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, p) return p.seat == 1 end,
  on_refresh = function(self, event, target, p, moves)
    local room, lost = p.room, {}
    for _, move in ipairs(moves) do
      local owner = move.from
      if owner and owner:getMark(Y.mark) ~= 0 and
        (move.to ~= owner or move.toArea ~= Card.PlayerEquip) then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip and table.contains(owner:getTableMark(Y.mark), info.cardId) then
            room:removeTableMark(owner, Y.mark, info.cardId)
            room:setCardMark(Fk:getCardById(info.cardId, true), "@qiao_bajia_yu", 0)
            lost[owner.id] = (lost[owner.id] or 0) + 1
          end
        end
      end
    end
    event:setSkillData(self, "lost", lost)
    Y.updateRoom(room)
  end,
  trigger_times = function(self, event, target, p)
    return (event:getSkillData(self, "lost") or {})[p.id] or 0
  end,
  can_trigger = function(self, event, target, p)
    if not S.present(p) or not p:hasSkill(skill.name) then return false end
    if p:hasShownSkill(skill.name) then return true end
    local deputy = p:getMark("__heg_deputy") == Y.general and p.deputyGeneral == "anjiang"
    local main = p:getMark("__heg_general") == Y.general and p.general == "anjiang"
    return (main or deputy) and not p:prohibitReveal(deputy)
  end,
  on_cost = Util.TrueFunc, -- 预亮的暗将走引擎的发动询问，确认后由 useSkill 明置。
  on_use = function(self, event, target, p)
    local phase = p.room.logic:getCurrentEvent():findParent(GameEvent.Phase)
    if phase then
      local pending = phase.data.qiao_bajia_lost or {}
      pending[p.id] = (pending[p.id] or 0) + 1
      phase.data.qiao_bajia_lost = pending
    end
  end,
})
for _, timing in ipairs({ fk.EventAcquireSkill, fk.EventLoseSkill }) do
  skill:addEffect(timing, { global = true,
    can_refresh = function(self, event, target, p, data)
      return target == p and data.skill.name == skill.name
    end,
    on_refresh = function(self, event, target, p) Y.updateRoom(p.room) end })
end
for _, timing in ipairs({ fk.GeneralShown, fk.GeneralHidden, fk.AfterPropertyChange, fk.Death, require("packages.hegemony.util").PlayerRemoved }) do
  skill:addEffect(timing, { global = true,
    can_refresh = function(self, event, target, p) return p.seat == 1 end,
    on_refresh = function(self, event, target, p) Y.updateRoom(p.room) end })
end
skill:addEffect(fk.EventPhaseEnd, {
  is_delay_effect = true,
  can_trigger = function(self, event, target, p, data)
    return S.present(p) and data and data.qiao_bajia_lost and data.qiao_bajia_lost[p.id] ~= nil
  end,
  on_use = function(self, event, target, p, data)
    local n = data.qiao_bajia_lost[p.id]
    data.qiao_bajia_lost[p.id] = nil
    for _ = 1, n do
      if p.dead then break end
      p.room:loseHp(p, 1, skill.name)
      if not p.dead and (p.general == Y.general or p.deputyGeneral == Y.general) then p:hideGeneral(p.deputyGeneral == Y.general) end
    end
  end,
})
skill:addEffect(fk.CardUsing, {
  mute = true,
  can_refresh = function(self, event, target, p) return p == target and p:hasShownSkill(skill.name) and #Y.lordKingdoms(p) > 0 end,
  on_refresh = function(self, event, target, p, data)
    local kingdoms = Y.lordKingdoms(p)
    data.disresponsiveList = data.disresponsiveList or {}
    for _, to in ipairs(p.room:getPresentPlayers()) do
      if table.contains(kingdoms, to.kingdom) then table.insertIfNeed(data.disresponsiveList, to) end
    end
  end,
})
skill:addEffect("atkrange", {
  virtual_weapon_func = function(self, p)
    local range = 0
    for _, card in ipairs(Y.shared(p)) do
      if card.sub_type == Card.SubtypeWeapon and card:AvailableAttackRange(p) then range = math.max(range, card:getAttackRange(p)) end
    end
    return range
  end,
})
skill:addEffect("invalidity", { recheck_invalidity = true, invalidity_func = function(self, p, sk) return Y.suppressed(p, sk) end })
Fk:loadTranslationTable { ["@qiao_bajia_yu"] = "舆", qiao_bajia_yu = "舆",
  ["#qiao_bajia-equip"] = "拔驾：选择 %dest 装备区里的一张牌置入你的装备区，称为“舆”" }
return skill
