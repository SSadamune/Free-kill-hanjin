-- 号令天下（魏势力锦囊）：普通锦囊，对一名体力值高于场上最小值的合法角色使用。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 号令天下」及
-- docs/rules/card-use-targets.md。体力比较按当前存活且未移出游戏的角色计算；
-- 并列最低的角色均不合法。
--   * 结算时除目标外的角色按座次分别决定是否参与，使用者也可参与。
--   * 第一项：参与者弃一张自己的手牌，再视为对目标使用一张【杀】。此牌由效果
--     明确指向目标，按显式目标规则判定，不叠加通常距离；只向能合法用杀的参与者
--     提供此项。正常弃置并确认实际弃出后才视为使用；魏势力参与者跳过弃牌步骤
--     （用牌时已确定为魏，且该参与者当前为魏）。
--   * 第二项：参与者选择并弃置目标的一张手牌或装备；同样的魏势力条件成立时，
--     参与者取得本次实际弃置且仍在弃牌堆的牌。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"

local skill = fk.CreateSkill {
  name = "qiao__command_world_skill",
}

local SLASH = "qiao__slash"
local CHOICE_OWN = "command_world_own"
local CHOICE_TARGET = "command_world_target"

--- 存活且未移出游戏的角色中的最低体力值。
local function lowestHp(room)
  local min
  for _, player in ipairs(room:getAlivePlayers()) do
    if player:isAlive() and not player:isRemoved() then
      if min == nil or player.hp < min then min = player.hp end
    end
  end
  return min
end

--- 效果明确指向目标：仅要求目标为其他角色，不叠加通常距离。
local function slashPolicy()
  return C.explicit({ other_roles = true }, { names = { SLASH } })
end

--- 参与者此刻能否对本次目标合法使用【杀】（按显式目标规则）。
local function canSlashAt(room, participant, target)
  if participant == nil or target == nil or participant == target then return false end
  if participant.dead or participant:isRemoved() or target.dead or target:isRemoved() then
    return false
  end
  local candidates = C.candidates(room, participant, Fk:cloneCard(SLASH), slashPolicy())
  return table.contains(candidates, target)
end

--- 可以正常弃置的手牌。
local function discardableHand(player)
  local ret = {}
  local status = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  for _, id in ipairs(player:getCardIds(Player.Hand)) do
    local card = Fk:getCardById(id)
    local legal = true
    for _, statusSkill in ipairs(status) do
      if statusSkill:prohibitDiscard(player, card) then legal = false; break end
    end
    if legal then table.insert(ret, id) end
  end
  return ret
end

--- 本次用牌时已确定为魏，且该参与者当前为魏。
local function weiExempt(confirmed, participant)
  return confirmed and participant ~= nil and participant.kingdom == "wei"
end

--- 第一项：弃一张手牌（或按魏条件跳过），再视为对目标使用一张【杀】。
local function doOrderAttack(room, participant, target, exempt)
  if not exempt then
    local discarded = room:askToDiscard(participant, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__command_world-discard",
      cancelable = false,
    }) or {}
    -- 正常弃置并确认实际弃出（牌已离开其手牌），才继续用杀。
    local id = discarded[1]
    if id == nil or room:getCardArea(id) == Card.PlayerHand then return end
  end
  if participant.dead or participant:isRemoved() or target.dead or target:isRemoved() then return end
  C.useVirtualCard(room, participant, SLASH, nil, { target }, skill.name, false, nil, slashPolicy())
end

--- 第二项：弃置目标一张手牌或装备；魏条件成立时取得本次实际弃置的牌。
local function doOrderTake(room, participant, target, exempt)
  if #target:getCardIds("he") == 0 then return end
  local id = room:askToChooseCard(participant, {
    target = target,
    flag = "he",
    skill_name = skill.name,
    prompt = "#qiao__command_world-take:" .. target.id,
  })
  if id == nil or room:getCardOwner(id) ~= target then return end
  room:throwCard({ id }, skill.name, target, participant)
  if not exempt then return end
  -- 只有本次实际弃置且仍在弃牌堆的牌才可取得。
  if room:getCardArea(id) == Card.DiscardPile then
    room:obtainCard(participant, id, true, fk.ReasonPrey, participant)
  end
end

local function resolveParticipant(room, participant, target, confirmed)
  if participant == target then return end
  if not room:askToSkillInvoke(participant, {
    skill_name = skill.name,
    prompt = "#qiao__command_world-participate:" .. target.id,
  }) then
    return
  end
  local exempt = weiExempt(confirmed, participant)
  local options = {}
  if canSlashAt(room, participant, target) and (exempt or #discardableHand(participant) > 0) then
    table.insert(options, CHOICE_OWN)
  end
  if #target:getCardIds("he") > 0 then
    table.insert(options, CHOICE_TARGET)
  end
  if #options == 0 then return end
  local choice = options[1]
  if #options > 1 then
    choice = room:askToChoice(participant, {
      choices = options,
      all_choices = { CHOICE_OWN, CHOICE_TARGET },
      skill_name = skill.name,
      prompt = "#qiao__command_world-choice:" .. target.id,
    })
  end
  if choice == CHOICE_OWN then
    doOrderAttack(room, participant, target, exempt)
  elseif choice == CHOICE_TARGET then
    doOrderTake(room, participant, target, exempt)
  end
end

skill:addEffect("cardskill", {
  prompt = "#qiao__command_world_skill",
  target_num = 1,
  -- 可用目标条件集中在 mod_target_filter：引擎的可用目标查询与界面点亮
  -- 都经 Util.CardTargetFilter 走同一入口。
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    if to_select == nil then return false end
    if not to_select:isAlive() or to_select:isRemoved() then return false end
    local min = lowestHp(Fk:currentRoom())
    if min == nil or to_select.hp <= min then return false end
    return not player:isProhibited(to_select, card)
  end,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    local min = lowestHp(room)
    if min == nil then return false end
    for _, other in ipairs(room:getAlivePlayers()) do
      if other:isAlive() and not other:isRemoved() and other.hp > min then return true end
    end
    return false
  end,
  on_effect = function(self, room, effect)
    local target = effect.to
    if effect.from == nil or target == nil then return end
    if target.dead or target:isRemoved() then return end
    local confirmed = FactionTricks.useConfirmed(effect.extra_data)
    local participants = {}
    for _, player in ipairs(room:getAlivePlayers()) do
      if player ~= target and player:isAlive() and not player:isRemoved() then
        table.insert(participants, player)
      end
    end
    room:sortByAction(participants)
    for _, participant in ipairs(participants) do
      if not participant.dead and not participant:isRemoved()
        and not target.dead and not target:isRemoved() then
        resolveParticipant(room, participant, target, confirmed)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "号令天下",
  ["#qiao__command_world_skill"] = "号令天下：对一名体力值高于场上最小值的角色使用",
  ["#qiao__command_world-participate"] = "号令天下：是否参与（目标为 %dest）",
  ["#qiao__command_world-choice"] = "号令天下：选择对 %dest 执行的一项",
  ["#qiao__command_world-discard"] = "号令天下：弃置一张手牌，然后视为对目标使用【杀】",
  ["#qiao__command_world-take"] = "号令天下：选择 %dest 的一张手牌或装备",
  [CHOICE_OWN] = "弃置一张手牌，视为对目标使用【杀】",
  [CHOICE_TARGET] = "弃置目标一张手牌或装备",
}

return skill
