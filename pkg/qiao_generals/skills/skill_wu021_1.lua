-- WU021 凌统 · 旋略
-- 当你失去装备区里的牌后，你可以弃置一名其他角色的一张牌。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu021_1",
}
skill.qiaoImplemented = true

local function discardTargets(room, player)
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and not p:isNude()
  end)
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(skill.name) then return false end
    local lostEquip = false
    for _, move in ipairs(data or {}) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo or {}) do
          if info.fromArea == Card.PlayerEquip then
            lostEquip = true
            break
          end
        end
      end
      if lostEquip then break end
    end
    return lostEquip and #discardTargets(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = discardTargets(room, player)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu021_1-choose",
      cancelable = true,
    })
    if type(chosen) == "table" and #chosen == 1 then
      event:setCostData(self, { to = chosen[1] })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = (event:getCostData(self) or {}).to
    if not RemovedTargets.isPresent(to) or to:isNude() then return end
    local id = room:askToChooseCard(player, {
      target = to,
      flag = "he",
      skill_name = skill.name,
      prompt = "#qiao__skill_wu021_1-discard::" .. to.id,
    })
    if id ~= nil then
      room:throwCard({ id }, skill.name, to, player)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "旋略",
  [":" .. skill.name] = "当你失去装备区里的牌后，你可以弃置一名其他角色的一张牌。",
  ["#qiao__skill_wu021_1-choose"] = "旋略：你可以选择一名其他角色，弃置其一张牌",
  ["#qiao__skill_wu021_1-discard"] = "旋略：弃置 %dest 的一张牌",
}

return skill
