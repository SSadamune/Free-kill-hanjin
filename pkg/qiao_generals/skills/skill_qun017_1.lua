-- QUN017 潘凤 · 狂斧
--
-- 规则基线：docs/rules/standard-generals.md 群区 QUN017、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 出牌阶段限一次：弃置场上一张装备牌，视为使用一张无距离限制的【杀】。
-- 记录被弃装备的原所有者，由模式级 qun_cards_rule 在整次用牌结束后按本次
-- 【杀】的实际 damageDealt 结算：
--   * 不是自己的牌且未造成伤害：弃置两张手牌；
--   * 是自己的牌且造成伤害：摸两张牌。
-- 不以本回合其他【杀】的伤害代替，也不在声明用牌时提前终止。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun017_1",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"
local MARK = "qiao_qun017"

local function slashPolicy()
  return C.bypassDistance({ names = { SLASH } })
end

local function equipmentOwners(room)
  if room == nil then return {} end
  return table.filter(room:getPresentPlayers(), function(p)
    return not p:isRemoved() and #p:getCardIds("e") > 0
  end)
end

local function slashTargets(room, player)
  return C.effectCandidates(room, player, Fk:cloneCard(SLASH), slashPolicy())
end

--- 客户端与服务端共用「存在合法【杀】目标」判断。card_use_targets 的策略栈只在
--- 服务端可用（该模块的 isServer 断言），客户端改用公开接口：
--- 公共效果用牌查询包含禁止使用／禁止指定目标与【杀】的目标条件，
--- 与服务端显式策略的禁止语义一致，不再用「有存活角色」的近似分支。
local function hasSlashTarget(room, player)
  if room == nil then return false end
  if player.class ~= nil and player.class.name == "ServerPlayer" then
    return #slashTargets(room, player) > 0
  end
  local slash = Fk:cloneCard(SLASH)
  slash.skillName = skill.name
  return table.find(room:getPresentPlayers(), function(p)
    return p ~= player and not p.dead and not p:isRemoved()
      and C.canEffectUseTo(player, slash, p, { bypass_distances = true })
  end) ~= nil
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_qun017_1",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = Util.FalseFunc,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    return player.phase == Player.Play
      and player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and #equipmentOwners(room) > 0
      and hasSlashTarget(room, player)
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
        prompt = "#qiao__skill_qun017_1-owner",
        cancelable = true,
      })
      owner = chosen and chosen[1]
    end
    if owner == nil or owner.dead or owner:isRemoved() then return end

    local cardId = room:askToChooseCard(player, {
      target = owner,
      flag = "e",
      skill_name = skill.name,
      prompt = "#qiao__skill_qun017_1-card",
    })
    if cardId == nil or not table.contains(owner:getCardIds("e"), cardId) then return end
    local fromSelf = owner == player
    room:throwCard({ cardId }, skill.name, owner, player)

    -- 弃置后重新计算目标与最大目标数（可能失去方天画戟等来源）。
    local targets = slashTargets(room, player)
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
      prompt = "#qiao__skill_qun017_1-target",
      cancelable = true,
    })
    if tos == nil or #tos == 0 then return end

    C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, nil, {
      [MARK] = { user = player.id, self = fromSelf },
    }, slashPolicy())
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_qun017_1"] = "狂斧：弃置场上一张装备牌，视为使用一张无距离限制的【杀】",
  ["#qiao__skill_qun017_1-owner"] = "狂斧：选择一名装备区有牌的角色",
  ["#qiao__skill_qun017_1-card"] = "狂斧：弃置其一张装备牌",
  ["#qiao__skill_qun017_1-target"] = "狂斧：选择【杀】的目标（无距离限制）",
  ["#qiao__skill_qun017_1-discard"] = "狂斧：此【杀】未造成伤害，弃置两张手牌",
}

return skill
