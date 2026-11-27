-- WU022 吕范 · 典财
-- 其他角色的出牌阶段结束时，若你此阶段失去过的牌数达到X（X为你的体力值），
-- 你可以摸牌至体力上限，然后你可以变更副将。
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu022_2",
}
skill.qiaoImplemented = true

--- 仅统计本出牌阶段从手牌区或装备区移至这两区以外的牌（判定区移走、手牌↔装备互移不计）。
local function lostCardsThisPhase(room, player)
  local lost = 0
  room.logic:getEventsOfScope(GameEvent.MoveCards, 1, function(e)
    for _, move in ipairs(e.data or {}) do
      if move.from == player and (move.to ~= player
        or (move.toArea ~= Card.PlayerHand and move.toArea ~= Card.PlayerEquip)) then
        for _, info in ipairs(move.moveInfo or {}) do
          if info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip then
            lost = lost + 1
          end
        end
      end
    end
    return false
  end, Player.HistoryPhase)
  return lost
end

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target == nil or target == player or target.phase ~= Player.Play then return false end
    if player.dead or player:isRemoved() or not player:hasSkill(skill.name) then return false end
    return lostCardsThisPhase(player.room, player) >= player.hp
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu022_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local need = player.maxHp - player:getHandcardNum()
    if need > 0 then
      player:drawCards(need, skill.name)
    end
    if RemovedTargets.isPresent(player)
      and Change.canUseSkillChange(room, player, skill.name)
      and #Change.candidates(room, player, true) > 0 then
      local choice = room:askToChoice(player, {
        choices = { "changeDeputy", "Cancel" },
        skill_name = skill.name,
        prompt = "#qiao__skill_wu022_2-change",
      })
      if choice == "changeDeputy" then
        Change.performSkillChangeDeputy(room, player, player, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "典财",
  [":" .. skill.name] = "其他角色的出牌阶段结束时，若你此阶段失去过的牌数达到X（X为你的体力值），你可以摸牌至体力上限，然后你可以变更副将。",
  ["#qiao__skill_wu022_2-invoke"] = "典财：是否摸牌至体力上限，然后你可以变更副将",
  ["#qiao__skill_wu022_2-change"] = "典财：是否变更副将",
}

return skill
