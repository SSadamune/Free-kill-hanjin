-- SHU021 糜夫人 · 勇决
-- 出牌阶段：移除此技能所属的真实武将牌，令一名角色获得1枚珠联璧合标记和
-- 永久技能“存嗣”。先选受益者，再移除；士兵/翼从/空位不能执行。
local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu021_2",
}
skill.qiaoImplemented = true

local CUNSI = "qiao__skill_shu021_3"

---@param player ServerPlayer
---@return string?, boolean?
local function sourceCard(player)
  for _, isDeputy in ipairs({ false, true }) do
    local name = Exchange.actualGeneral(player, isDeputy)
    local general = Fk.generals[name]
    if general ~= nil and not Exchange.isSoldier(name)
      and table.contains(general:getSkillNameList(), skill.name) then
      return name, isDeputy
    end
  end
  return nil, nil
end

skill:addEffect("active", {
  prompt = "#qiao__skill_shu021_2-prompt",
  target_num = 1,
  card_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select:isAlive() and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and player:hasSkill(skill.name) and sourceCard(player) ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead then return end
    local name, isDeputy = sourceCard(player)
    if name == nil then return end
    local before = Exchange.actualGeneral(player, isDeputy)
    H.removeGeneral(player, isDeputy)
    if player.dead then return end
    local after = Exchange.actualGeneral(player, isDeputy)
    if after == before then return end
    H.addHegMark(target, "companion")
    room:handleAddLoseSkills(target, CUNSI, skill.name, false, true)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu021_2"] = "勇决",
  [":qiao__skill_shu021_2"] = "出牌阶段，你可以移除此武将牌，令一名角色获得一枚珠联璧合标记和技能“存嗣”（每轮各限一次，当你于回合内使用【杀】后/回合外使用【桃】后，你可以获得之。）。",
  ["#qiao__skill_shu021_2-prompt"] = "勇决：移除此武将牌，令一名角色获得珠联璧合和“存嗣”",
}

return skill
