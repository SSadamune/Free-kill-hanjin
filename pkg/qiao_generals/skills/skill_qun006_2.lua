-- QUN006 董卓 · 暴凌
--
-- 主将技，锁定技，出牌阶段结束时移除副将；只有实际移除了一张武将牌，才继续
-- 加3点体力上限、回复3点并获得崩坏。副将位置若已是士兵，不重复加成。
local H = require "packages.hegemony.util"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun006_2",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

local BENG = "qiao__skill_qun006_3"
local REMOVED_TAG = "qiao_qun006_2_removed"

---@param player ServerPlayer
---@return boolean
local function hasDeputyGeneral(player)
  local name = player.deputyGeneral
  if name == "anjiang" then name = player:getMark("__heg_deputy") end
  if name == nil or name == "" or Commander.isSoldier(name) then return false end
  return Fk.generals[name] ~= nil
end

-- 真实 GeneralRemoved 事件确认副将武将牌确实被移除；即使统领规则随后自动
-- 把空士兵转为翼从，也不会因 after 不是 blank_ 而漏掉后续加成。
skill:addEffect(H.GeneralRemoved, {
  global = true,
  priority = 10,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and data ~= nil and data.isDeputy == true
  end,
  on_refresh = function(self, event, target, player, data)
    target.room:setTag(REMOVED_TAG, { who = target.id, orig = data.origName })
  end,
})

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Play
      and hasDeputyGeneral(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setTag(REMOVED_TAG, nil)
    H.removeGeneral(player, true)
    local removed = room:getTag(REMOVED_TAG)
    if player.dead or removed == nil or removed.who ~= player.id then return end

    room:changeMaxHp(player, 3)
    if player.dead then return end
    room:recover {
      who = player,
      num = 3,
      recoverBy = player,
      skillName = skill.name,
    }
    if player.dead then return end
    room:handleAddLoseSkills(player, BENG, skill.name, false, true)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun006_2"] = "暴凌",
  [":qiao__skill_qun006_2"] = "主将技，锁定技，出牌阶段结束时，你移除副将，然后加3点体力上限并回复3点体力，获得“崩坏”。",
}

return skill
