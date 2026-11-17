-- QUN015 纪灵 · 双刃
--
-- 规则基线：docs/rules/generals/qun015-jiling.md（用户 2026-11-15 确认没赢后的限制
-- 持续至本回合结束）、docs/rules/only-as.md、docs/rules/card-use-targets.md。
--
-- 出牌阶段开始时，你可以与一名角色真实拼点：
--   * 赢：视为对包含拼点对手在内的至多两名角色使用一张【杀】。目标按显式
--     条件处理（效果指定“角色”，替换【杀】原距离等目标条件），数量至多 2；
--     不照搬上游的“与其势力相同”，也不在没赢后禁止其他目标。
--   * 没赢（含平局）：手牌中的【杀】只能当【借刀杀人】使用，至本回合结束。
--     限制复用公共 only-as 的来源 shuangren（不绑技能）；转换入口由独立状态
--     骨架 qun_shuangren_state 提供，失去双刃后两者都仍可用。匹配按当前手牌
--     范围，所以之后得到的【杀】同样受限；实体牌牌名不改。转换后的
--     【借刀杀人】仍按该牌自身规则真实选择主目标与副目标。
local OnlyAs = require "packages.qiao.pkg.qiao_mode.rules.only_as"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local SLASH = "qiao__slash"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun015_1",
}
skill.qiaoImplemented = true

-- “视为对……角色使用一张【杀】”只指定目标角色这一个条件：用 other_roles
-- 替换【杀】的原目标条件，不额外叠加距离；数量另由 max_targets 限制。
local CONDITION = { other_roles = true }

local function slashPolicy(maxTargets)
  return C.explicit(CONDITION, {
    names = { SLASH },
    min_targets = 1,
    max_targets = maxTargets,
  })
end

--- 可与纪灵拼点的其他存活角色。
local function pindianTargets(player)
  local ret = {}
  for _, target in ipairs(player.room:getOtherPlayers(player, false)) do
    if target:isAlive() and not target:isRemoved() and player:canPindian(target) then
      table.insert(ret, target)
    end
  end
  return ret
end

--- 赢时除拼点对手外的至多一名额外目标。候选由显式策略计算，与正式用牌
--- 校验共用同一条件；拼点对手已固定包含，不能重复选择。
local function extraCandidates(player, opponent)
  local all = C.candidates(player.room, player, Fk:cloneCard(SLASH), slashPolicy(2), {})
  return table.filter(all, function(target)
    return target ~= opponent and target:isAlive() and not target:isRemoved()
  end)
end

--- 赢：一次多目标用牌（不是分别使用两张），拼点对手必须包含在内。
local function useWinSlash(room, player, opponent)
  if player.dead or opponent == nil or opponent.dead or opponent:isRemoved() then return end
  local tos = { opponent }
  local extras = extraCandidates(player, opponent)
  if #extras > 0 then
    local chosen = room:askToChoosePlayers(player, {
      targets = extras,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun015_1-target",
      cancelable = true,
    })
    local extra = chosen and chosen[1]
    if extra ~= nil and not extra.dead and not extra:isRemoved() then
      table.insert(tos, extra)
    end
  end
  -- 使用接口只选择并校验，随后由公共 useVirtualCard 执行一次使用。
  C.useVirtualCard(room, player, SLASH, nil, tos, skill.name, true, {}, slashPolicy(2))
end

--- 已建立效果（限制 + 转换权限）的独立入口。见 qun_shuangren_state.lua：
--- 转换入口不挂在双刃本体上，失去双刃后仍可用【杀】当【借刀杀人】。
local STATE = "qiao__qun_shuangren_state"

--- 没赢：登记“手牌中的【杀】只能当【借刀杀人】使用”的来源，并挂上独立的
--- 转换状态。来源刻意不传 skill：失去双刃不撤销已建立的限制（qun015 裁定）。
local function restrictSlash(player)
  local room = player.room
  OnlyAs.addSource(room, {
    def = "shuangren",
    holder = player,
    duration = "turn",
    reason = skill.name,
  })
  room:handleAddLoseSkills(player, STATE, STATE, false, true)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player.phase == Player.Play
      and #pindianTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun015_1-invoke",
    }) then
      return false
    end
    local targets = pindianTargets(player)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun015_1-pindian",
      cancelable = false,
    })
    local opponent = chosen and chosen[1]
    if opponent == nil or player.dead or opponent.dead or opponent:isRemoved() then
      return false
    end
    if not player:canPindian(opponent) then return false end
    event:setCostData(self, { to = opponent })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local opponent = cost.to
    if opponent == nil or player.dead or opponent.dead or opponent:isRemoved() then return end
    if not player:canPindian(opponent) then return end

    local pindian = player:pindian({ opponent }, skill.name)
    local result = pindian and pindian.results and pindian.results[opponent]
    if result ~= nil and result.winner == player then
      useWinSlash(room, player, opponent)
    else
      -- 平局与失败同样“没赢”，不能只处理点数较小的分支。
      if not player.dead then restrictSlash(player) end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun015_1"] = "双刃",
  [":qiao__skill_qun015_1"] = "出牌阶段开始时，你可以与一名角色拼点：若你赢，你视为对包含其在内的至多两名角色使用一张【杀】；若你没赢，你手牌中的【杀】只能当【借刀杀人】使用。",
  ["#qiao__skill_qun015_1-invoke"] = "双刃：你可以与一名角色拼点",
  ["#qiao__skill_qun015_1-pindian"] = "双刃：选择拼点角色",
  ["#qiao__skill_qun015_1-target"] = "双刃：你可以额外选择一名角色（拼点对手已包含在内）",
}

return skill
