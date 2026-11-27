-- HAN023 伍琼&种辑 · 心疾
-- 锁定技，你处于鏖战状态。当你于濒死状态失救时，你减1点体力上限并回复体力至1点。
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"

local skill = fk.CreateSkill {
  name = "qiao__skill_han023_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function sync(player)
  local room = player and player.room
  if room == nil or not Modes.inRoom(room) then return end
  BattleRoyal.syncPersonal(room, player, skill.name,
    not player.dead and player:hasShownSkill(skill.name))
end

skill:addAcquireEffect(function(self, player) sync(player) end)
skill:addLoseEffect(function(self, player) sync(player) end)

-- 求桃一圈均失败后、GameRule（priority = 0）执行死亡前触发。
skill:addEffect(fk.AskForPeachesDone, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player.hp < 1 and not player.dead
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:changeMaxHp(player, -1)
    if player.dead or player.maxHp < 1 then return end
    local need = 1 - player.hp
    if need > 0 then
      room:recover {
        who = player,
        num = need,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "心疾",
  [":" .. skill.name] = "锁定技，你处于鏖战状态。当你于濒死状态失救时，你减1点体力上限并回复体力至1点。",
}

return skill
