-- JIN021 卫瓘 · 乘隙
-- 准备阶段，你可以令一名角色视为使用【以逸待劳】，然后使用者对以此法弃置了非基本牌的目标角色各造成1点伤害。
local H = require "packages.hegemony.util"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin021_1",
}
skill.qiaoImplemented = true

local function legalTargetsFor(room, user, card)
  local targets = table.filter(room:getPresentPlayers(), function(p)
    return H.compareKingdomWith(p, user, false) and not user:isProhibited(p, card)
  end)
  room:sortByAction(targets)
  return targets
end

local function legalUsers(room)
  local probe = Fk:cloneCard("qiao__await_exhausted")
  probe.skillName = skill.name
  return table.filter(room:getPresentPlayers(), function(u)
    return not u:prohibitUse(probe) and #legalTargetsFor(room, u, probe) > 0
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player.phase == Player.Start
      and RemovedTargets.isPresent(player) and player:hasSkill(skill.name)
      and #legalUsers(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local users = legalUsers(room)
    if #users == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      targets = users,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin021_1-choose",
      cancelable = true,
    })
    if chosen and chosen[1] then
      event:setCostData(self, { user = chosen[1] })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local user = cost.user
    if not RemovedTargets.isPresent(user) then return end

    local card = Fk:cloneCard("qiao__await_exhausted")
    card.skillName = skill.name
    if user:prohibitUse(card) then return end
    local targets = legalTargetsFor(room, user, card)
    if #targets == 0 then return end

    local currentEvent = room.logic:getCurrentEvent()
    local startId = currentEvent and currentEvent.id or 0
    local use = {
      from = user,
      tos = targets,
      card = card,
    }
    room:useCard(use)

    -- 汇总本次【以逸待劳】实际生效并弃置了至少一张非基本牌的目标角色（含使用者自身）。
    local penalized = {}
    room.logic:getEventsByRule(GameEvent.MoveCards, 999, function(e)
      local effectEvent = e:findParent(GameEvent.CardEffect)
      if effectEvent == nil or effectEvent.data.card ~= card then return false end
      for _, move in ipairs(e.data or {}) do
        if move.from ~= nil and move.moveReason == fk.ReasonDiscard
          and move.skillName == "await_exhausted_skill" then
          for _, info in ipairs(move.moveInfo or {}) do
            local c = Fk:getCardById(info.cardId, true)
            if c ~= nil and c.type ~= Card.TypeBasic then
              table.insertIfNeed(penalized, move.from)
              break
            end
          end
        end
      end
      return false
    end, startId)

    if #penalized == 0 then return end
    room:sortByAction(penalized)
    for _, dest in ipairs(penalized) do
      if RemovedTargets.isPresent(dest) then
        room:damage {
          from = user,
          to = dest,
          damage = 1,
          damageType = fk.NormalDamage,
          skillName = skill.name,
        }
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "乘隙",
  [":" .. skill.name] = "准备阶段，你可以令一名角色视为使用【以逸待劳】，然后使用者对以此法弃置了非基本牌的目标角色各造成1点伤害。",
  ["#qiao__skill_jin021_1-choose"] = "乘隙：选择一名角色视为使用【以逸待劳】",
}

return skill
