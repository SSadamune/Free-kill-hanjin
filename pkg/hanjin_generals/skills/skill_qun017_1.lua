-- QUN017 潘凤 · 狂斧
--
-- 规则基线：rules/standard-generals.md 群区 QUN017、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 出牌阶段限一次：弃置场上一张装备牌，视为使用一张无距离限制的【杀】。
-- 记录被弃装备的原所有者，由模式级 qun_cards_rule 在整次用牌结束后按本次
-- 【杀】的实际 damageDealt 结算：
--   * 不是自己的牌且未造成伤害：弃置两张手牌；
--   * 是自己的牌且造成伤害：摸两张牌。
-- 不以本回合其他【杀】的伤害代替，也不在声明用牌时提前终止。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun017_1",
}
skill.hanjinImplemented = true

local SLASH = "hanjin__slash"
local MARK = "hanjin_qun017"

local function slashPolicy()
  return C.bypassDistance({ names = { SLASH } })
end

local function equipmentOwners(room)
  return table.filter(room.alive_players, function(p)
    return not p:isRemoved() and #p:getCardIds("e") > 0
  end)
end

local function slashTargets(player)
  return C.candidates(player.room, player, Fk:cloneCard(SLASH), slashPolicy(),
    { bypass_times = true })
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_qun017_1",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and #equipmentOwners(player.room) > 0
      and #slashTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end

    local owners = equipmentOwners(room)
    if #owners == 0 then return end
    local owner = owners[1]
    if #owners > 1 then
      local chosen = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = owners,
        skill_name = skill.name,
        prompt = "#hanjin__skill_qun017_1-owner",
        cancelable = true,
      })
      owner = chosen and chosen[1]
    end
    if owner == nil or owner.dead or owner:isRemoved() then return end

    local cardId = room:askToChooseCard(player, {
      target = owner,
      flag = "e",
      skill_name = skill.name,
      prompt = "#hanjin__skill_qun017_1-card",
    })
    if cardId == nil or not table.contains(owner:getCardIds("e"), cardId) then return end
    local fromSelf = owner == player
    room:throwCard({ cardId }, skill.name, owner, player)

    -- 弃置后重新计算目标与最大目标数（可能失去方天画戟等来源）。
    local targets = slashTargets(player)
    if #targets == 0 then return end
    local slash = Fk:cloneCard(SLASH)
    local maxNum = slash.skill:getMaxTargetNum(player, slash)
    maxNum = math.min(maxNum, #targets)
    if maxNum < 1 then return end
    local tos = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = maxNum,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_qun017_1-target",
      cancelable = true,
    })
    if tos == nil or #tos == 0 then return end

    C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, true, {
      bypass_times = true,
      [MARK] = { user = player.id, self = fromSelf },
    }, slashPolicy())
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_qun017_1"] = "狂斧：弃置场上一张装备牌，视为使用一张无距离限制的【杀】",
  ["#hanjin__skill_qun017_1-owner"] = "狂斧：选择一名装备区有牌的角色",
  ["#hanjin__skill_qun017_1-card"] = "狂斧：弃置其一张装备牌",
  ["#hanjin__skill_qun017_1-target"] = "狂斧：选择【杀】的目标（无距离限制）",
  ["#hanjin__skill_qun017_1-discard"] = "狂斧：此【杀】未造成伤害，弃置两张手牌",
}

return skill
