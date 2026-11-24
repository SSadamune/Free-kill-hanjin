-- WEI023 臧霸关联翼从「青州精锐」
--
-- 规则依据：docs/rules/generals/wei023-zangba.md、docs/rules/commander-retinue.md。
-- 出牌阶段限一次：令一名手牌数最小（允许并列及自己）的角色选择一项：
-- 1. 弃置一张手牌；2. 你对其造成1点伤害。
-- 同名多份实例各自有一次：逐实例计数由 zhen_shi_retinues 维护，每份实例
-- 独立计次；不使用按技能名合并的 usedSkillTimes 历史。
-- 客户端可用性只读公开摘要与公开手牌数（getCardIds("h")），不读 room tag
-- 或其他角色的私有手牌。来源的明暗/公开性沿用引擎既有 hasSkill 与正式接入
-- 的生命周期，本技能不另造可见性规则。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Z = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"

local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_qingzhou_jingrui",
}
skill.qiaoImplemented = true

local OPT_DISCARD = "#qiao__retinue_skill_qingzhou_jingrui-option-discard"
local OPT_DAMAGE = "#qiao__retinue_skill_qingzhou_jingrui-option-damage"

---@param room Room|ClientRoom|nil
---@return ServerPlayer[]|ClientPlayer[]
local function alivePlayers(room)
  return room and room:getPresentPlayers() or {}
end

--- 全场最小公开手牌数；包含自己，允许并列。
---@param room Room|ClientRoom|nil
---@return integer?
local function minHandCount(room)
  local min
  for _, p in ipairs(alivePlayers(room)) do
    if p ~= nil and not p.dead and not p:isRemoved() then
      local count = p:getHandcardNum()
      if min == nil or count < min then min = count end
    end
  end
  return min
end

---@param target ServerPlayer
---@return integer[]
local function discardableHand(target)
  return table.filter(target:getCardIds("h"), function(id)
    return not target:prohibitDiscard(id)
  end)
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__retinue_skill_qingzhou_jingrui-prompt",
  card_num = 0,
  target_num = 1,
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    local room = Fk:currentRoom()
    if room == nil or to_select == nil or to_select.dead or to_select:isRemoved() then
      return false
    end
    local minimum = minHandCount(room)
    return minimum ~= nil and to_select:getHandcardNum() == minimum
  end,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    if not player:hasSkill(skill.name) then return false end
    return Z.canUse(player, skill.name, 1)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or target == nil
      or target.dead or target:isRemoved() then
      return
    end
    local minimum = minHandCount(room)
    if minimum == nil or target:getHandcardNum() ~= minimum then return end

    local instance = Z.availableInstances(player, skill.name, 1)[1]
    if instance == nil then return end
    -- 技能已实际发动：先记录本实例本阶段一次，再询问目标。
    Z.spend(player, instance, skill.name)

    local choices = {}
    if #discardableHand(target) > 0 then table.insert(choices, OPT_DISCARD) end
    table.insert(choices, OPT_DAMAGE)

    local choice = Selection.askOption(room, target, {
      choices = choices,
      all_choices = { OPT_DISCARD, OPT_DAMAGE },
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_qingzhou_jingrui-choose:" .. player.id,
      cancelable = false,
    })

    if choice == OPT_DISCARD then
      if #discardableHand(target) == 0 then return end
      local cards = room:askToDiscard(target, {
        min_num = 1,
        max_num = 1,
        include_equip = false,
        skill_name = skill.name,
        prompt = "#qiao__retinue_skill_qingzhou_jingrui-discard",
        cancelable = false,
      })
      -- askToDiscard 已实际执行弃牌；取消或没有实际弃牌时不改判伤害。
      if cards == nil or #cards == 0 then return end
    else
      if target:isAlive() and not target:isRemoved() then
        room:damage {
          from = player,
          to = target,
          damage = 1,
          skillName = skill.name,
        }
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__retinue_skill_qingzhou_jingrui"] = "青州精锐",
  [":qiao__retinue_skill_qingzhou_jingrui"] =
    "出牌阶段限一次，你可以令一名手牌数最小的角色选择一项：1.弃置一张手牌；2.你对其造成1点伤害。",
  ["#qiao__retinue_skill_qingzhou_jingrui-prompt"] = "青州精锐：选择一名手牌数最少的角色",
  ["#qiao__retinue_skill_qingzhou_jingrui-choose"] = "青州精锐：选择一项（发动者 %src）",
  ["#qiao__retinue_skill_qingzhou_jingrui-discard"] = "青州精锐：弃置一张手牌",
  [OPT_DISCARD] = "弃置一张手牌",
  [OPT_DAMAGE] = "受到1点伤害",
}

return skill
