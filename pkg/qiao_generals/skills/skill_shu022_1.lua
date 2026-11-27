-- SHU022 马谡 · 散谣
-- 出牌阶段限一次，你可以弃置一张牌，对一名体力值或手牌数最大的角色造成1点伤害。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu022_1",
}
skill.qiaoImplemented = true

local function isMaxHpOrHand(room, target)
  if room == nil or target == nil or target.dead or target:isRemoved() then return false end
  local players = room:getPresentPlayers()
  if #players == 0 then return false end
  local maxHp, maxHand
  for _, p in ipairs(players) do
    if maxHp == nil or p.hp > maxHp then maxHp = p.hp end
    local hand = p:getHandcardNum()
    if maxHand == nil or hand > maxHand then maxHand = hand end
  end
  return target.hp == maxHp or target:getHandcardNum() == maxHand
end

local function hasDiscardableCard(player)
  return table.find(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end) ~= nil
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_shu022_1-prompt",
  max_phase_use_time = 1,
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and hasDiscardableCard(player)
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    return isMaxHpOrHand(Fk:currentRoom(), to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or target == nil or not isMaxHpOrHand(room, target) then return end
    if #(effect.cards or {}) ~= 1 then return end
    -- 按通用消耗裁定：执行弃置即支付消耗。
    room:throwCard(effect.cards, skill.name, player, player)
    if RemovedTargets.isPresent(target) then
      room:damage {
        from = player,
        to = target,
        damage = 1,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "散谣",
  [":" .. skill.name] = "出牌阶段限一次，你可以弃置一张牌，对一名体力值或手牌数最大的角色造成1点伤害。",
  ["#qiao__skill_shu022_1-prompt"] = "散谣：弃置一张牌，对一名体力值或手牌数最大的角色造成1点伤害",
}

return skill
