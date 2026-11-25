-- 铁骑：按目标所选主/副将位置动态失效该位置的非锁定技能。
-- 不写 MarkEnum.InvalidSkills；只读目标身上的位置记录，因此不误伤另一位置、
-- 不误伤不属于将牌的后天技能，失去马超技能也不撤销已建立失效。
local SkillSources = require "packages.qiao.pkg.qiao_mode.rules.skill_sources"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local skill = fk.CreateSkill { name = "qiao__shu_tieqi_invalidity" }

local POS = "qiao__skill_shu006_2_positions-turn"

local function generalOf(player, pos)
  if pos == "main" then
    if player.general == "" then return nil end
    return player.general ~= "anjiang" and player.general or player:getMark("__heg_general")
  end
  if player.deputyGeneral == "" then return nil end
  return player.deputyGeneral ~= "anjiang" and player.deputyGeneral or player:getMark("__heg_deputy")
end

skill:addEffect("invalidity", {
  invalidity_func = function(self, from, skill_obj)
    local positions = from:getTableMark(POS)
    if type(positions) ~= "table" or #positions == 0 then return false end
    if skill_obj:hasTag(Skill.Compulsory) then return false end
    for _, pos in ipairs(positions) do
      local general = generalOf(from, pos)
      local general_data = general and Fk.generals[general] or nil
      if general_data ~= nil and not Exchange.isSoldier(general)
        and table.contains(general_data:getSkillNameList(), skill_obj.name)
        and SkillSources.isGeneralSkill(skill_obj, from) then
        return true
      end
    end
    return false
  end,
})

return skill
