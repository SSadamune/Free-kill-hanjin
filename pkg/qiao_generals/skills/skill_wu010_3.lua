-- WU010 孙策 · 魂殇
--
-- 副将技（☯️-1）。准备阶段体力恰为1时，角色获得本回合的英魂和英姿。
-- 以回合末清理技能作为授予来源，使其独立于孙策武将牌。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu010_3",
  tags = { Skill.DeputyPlace },
}
skill.qiaoImplemented = true

local YINGHUN = "qiao__skill_wu009_1"
local YINGZI = "qiao__skill_wu005_1"
local CLEANUP = "qiao__wu010_hunshang_cleanup"
local GRANTED_MARK = "qiao__skill_wu010_3-cleanup-granted"

---@param room Room
local function ensureCleanup(room)
  if room ~= nil and not room:hasSkill(CLEANUP) then room:addSkill(CLEANUP) end
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Start and player.hp == 1
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu010_3-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    ensureCleanup(room)
    for _, name in ipairs({ YINGHUN, YINGZI }) do
      if player:hasSkill(name, true, true) then
        player:addSkill(name, CLEANUP)
      else
        room:handleAddLoseSkills(player, name, CLEANUP, false, true)
      end
    end
    room:setPlayerMark(player, GRANTED_MARK, 1)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu010_3"] = "魂殇",
  [":qiao__skill_wu010_3"] = "副将技（☯️-1），准备阶段，若你的体力值为1，本回合你获得“英魂”和“英姿”。",
  ["#qiao__skill_wu010_3-invoke"] = "魂殇：本回合获得“英魂”和“英姿”",
}

return skill
