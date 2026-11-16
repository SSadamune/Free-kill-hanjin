-- HAN008 伏皇后 · 惴恐
--
-- 其他角色的准备阶段，若伏皇后已受伤，可以与其实施拼点：
--   赢：防止该角色本回合造成的所有伤害；
--   没赢（含平局）：该角色可以视为对伏皇后使用一张【杀】。
-- 目标由效果明确指定，使用显式目标策略，不计算普通距离。
-- 防止伤害是挂在“造成伤害者”身上的本回合延迟记录，由房间级监听器执行，
-- 不依赖伏皇后之后是否仍有惴恐。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han008_1",
}

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local NO_DAMAGE = "hanjin__skill_han008_1_no_damage-turn"
local DAMAGE_DELAY_NAME = "#hanjin_skill_han008_1_damage_delay"
local OPTION_YES = "#hanjin__skill_han008_1-yes"
local OPTION_NO = "#hanjin__skill_han008_1-no"

local damage_delay

local function ensureDamageDelay(room)
  if room == nil then return end
  if damage_delay == nil then damage_delay = Fk.skills[DAMAGE_DELAY_NAME] end
  if damage_delay == nil then
    local skel = fk.CreateSkill { name = DAMAGE_DELAY_NAME }
    skel:addEffect(fk.DamageCaused, {
      global = true,
      is_delay_effect = true,
      can_refresh = function(self, event, target, player, data)
        return data ~= nil and data.from ~= nil and data.damage > 0
          and data.from:getMark(NO_DAMAGE) > 0
      end,
      on_refresh = function(self, event, target, player, data)
        data:preventDamage()
      end,
    })
    damage_delay = skel:createSkill()
    Fk.skills[DAMAGE_DELAY_NAME] = damage_delay
  end
  if not room:hasSkill(DAMAGE_DELAY_NAME) then
    room:addSkill(damage_delay)
  end
end

-- EventPhaseStart 的 target 是当前回合角色。TriggerSkill 的基类门槛不适用
-- 于带 can_trigger 的 global 效果：createTriggerSkill 会用 can_trigger 覆盖
-- triggerable，因此这里可以直接走正规 can_trigger/on_cost/on_use，正常明置
-- 与记录技能发动，不另做 refresh/room:useSkill 代理。
skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and player ~= nil and target ~= player
      and player:hasSkill(skill.name)
      and target.phase == Player.Start
      and player:isWounded() and player:canPindian(target)
      and not ((data.__hanjin_han008_1_done_by or {})[player.id] == true)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han008_1-invoke::" .. target.id,
    }) then
      return false
    end
    data.__hanjin_han008_1_done_by = data.__hanjin_han008_1_done_by or {}
    data.__hanjin_han008_1_done_by[player.id] = true
    ensureDamageDelay(room)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pindian = player:pindian({ target }, skill.name)
    local result = pindian.results and pindian.results[target]
    local winner = result and result.winner
    if winner == player then
      room:addPlayerMark(target, NO_DAMAGE, 1)
    elseif player:isAlive() and target:isAlive() then
      local choice = room:askToChoice(target, {
        choices = { OPTION_YES, OPTION_NO },
        skill_name = skill.name,
        prompt = "#hanjin__skill_han008_1-slash",
        cancelable = false,
      })
      if choice == OPTION_YES then
        C.useVirtualCard(room, target, "hanjin__slash", nil, { player }, skill.name, true,
          nil, C.explicit({ other_roles = true }, { names = { "hanjin__slash" } }))
      end
    end
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDamageDelay(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han008_1"] = "惴恐",
  [":hanjin__skill_han008_1"] = "其他角色的准备阶段，若你已受伤，你可以与其拼点。若你赢，防止其本回合造成伤害；若你没赢，其可以视为对你使用一张【杀】。",
  ["#hanjin__skill_han008_1-invoke"] = "惴恐：你可以与 %dest 拼点",
  ["#hanjin__skill_han008_1-slash"] = "惴恐：你可以视为对伏皇后使用一张【杀】",
  [OPTION_YES] = "视为使用【杀】",
  [OPTION_NO] = "不发动",
}

skill.hanjinImplemented = true

return skill
