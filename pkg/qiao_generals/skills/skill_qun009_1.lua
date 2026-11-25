-- QUN009 左慈 · 化形
-- 当你受到1点伤害后、其他角色脱离濒死时或出牌阶段限一次，你可以将一张（首次发动时改为三张）
-- 剩余武将牌扣置于武将牌上，称为“魂”，然后选择一项：1.移去一张“魂”；2.将副将武将牌额外变更为一张“魂”。
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

local skill = fk.CreateSkill {
  name = Bian.ZUOCI_SKILL,
}
skill.qiaoImplemented = true

local OPT_REMOVE = "#qiao__skill_qun009_1-opt-remove"
local OPT_CHANGE = "#qiao__skill_qun009_1-opt-change"

local function canExtraChangeDeputy(room, player)
  if player == nil or player.dead or player:isRemoved() then return false end
  if Exchange.isLordPosition(player, true) or Wei.isPositionRestricted(room, player, true) then
    return false
  end
  local deputy = Exchange.actualGeneral(player, true)
  return type(deputy) == "string" and deputy ~= "" and not Exchange.isSoldier(deputy)
end

local function executeHuaxing(room, player)
  if player == nil or player.dead or player:isRemoved() then return end
  local pool = Change.skillAvailablePool(room, { any_kingdom = true })
  if #pool == 0 then return end
  local isFirst = not Bian.zuociFirstUsed(room, player)
  local drawNum = math.min(isFirst and 3 or 1, #pool)
  local picked = room:tableRandomPick(pool, drawNum)
  if #picked == 0 then return end
  for _, name in ipairs(picked) do
    while table.removeOne(room.general_pile, name) do end
  end
  local souls = Bian.addZuociSouls(room, player, picked, true)
  if #souls == 0 then return end

  local choices = { OPT_REMOVE }
  if canExtraChangeDeputy(room, player) then
    table.insert(choices, OPT_CHANGE)
  end
  local action = #choices == 1 and choices[1] or Selection.askOption(room, player, {
    choices = choices,
    all_choices = { OPT_REMOVE, OPT_CHANGE },
    skill_name = skill.name,
    prompt = "#qiao__skill_qun009_1-choice",
    cancelable = false,
  })
  if action == OPT_CHANGE and canExtraChangeDeputy(room, player) then
    local chosen = Change.chooseGeneral(room, player, true, souls, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun009_1-change",
      cancelable = false,
    })
    if chosen ~= nil and Bian.removeZuociSoul(room, player, chosen) then
      local ok = Change.changeTo(room, player, true, chosen, {
        require_general_card = true,
        from_pile = false,
        skill_name = skill.name,
      })
      if not ok then
        Bian.addZuociSouls(room, player, { chosen }, false)
      end
    end
  else
    local chosen = Change.chooseGeneral(room, player, true, souls, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun009_1-remove",
      cancelable = false,
    })
    if chosen ~= nil and Bian.removeZuociSoul(room, player, chosen) then
      Discard.add(room, { chosen })
    end
  end
end

-- 入口一：出牌阶段限一次（仅按本主动效果计次，避免与受伤/濒死触发共用计数）。
skill:addEffect("active", {
  anim_type = "special",
  prompt = "#qiao__skill_qun009_1-prompt",
  max_phase_use_time = 1,
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player:usedEffectTimes(self.name, Player.HistoryPhase) == 0
      and Bian.canDrawSoul(Fk:currentRoom())
  end,
  on_use = function(self, room, effect)
    executeHuaxing(room, effect.from)
  end,
})

-- 入口二：每受到 1 点伤害后。
skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  trigger_times = function(self, event, target, player, data)
    return data.damage
  end,
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and not player:isRemoved()
      and player:hasSkill(skill.name)
      and Bian.canDrawSoul(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun009_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    executeHuaxing(player.room, player)
  end,
})

-- 入口三：其他角色脱离濒死时。
skill:addEffect(fk.AfterDying, {
  anim_type = "special",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target ~= player and not target.dead
      and not player.dead and not player:isRemoved()
      and player:hasSkill(skill.name)
      and Bian.canDrawSoul(player.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun009_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    executeHuaxing(player.room, player)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "化形",
  [":" .. skill.name] = "当你受到1点伤害后、其他角色脱离濒死时或出牌阶段限一次，你可以将一张（首次发动时改为三张）剩余武将牌扣置于武将牌上，称为“魂”，然后选择一项：1.移去一张“魂”；2.将副将武将牌额外变更为一张“魂”。",
  ["#qiao__skill_qun009_1-prompt"] = "化形：扣置剩余武将牌作为“魂”，并选择移去一张“魂”或将副将额外变更为一张“魂”",
  ["#qiao__skill_qun009_1-invoke"] = "化形：是否发动“化形”扣置“魂”并执行后续选择",
  ["#qiao__skill_qun009_1-choice"] = "化形：选择一项",
  [OPT_REMOVE] = "移去一张“魂”",
  [OPT_CHANGE] = "将副将武将牌额外变更为一张“魂”",
  ["#qiao__skill_qun009_1-remove"] = "化形：选择一张“魂”移去",
  ["#qiao__skill_qun009_1-change"] = "化形：选择一张“魂”作为新的副将",
}

return skill
