-- SHU010 庞统 · 连环
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU010。
-- 你可以将一张梅花手牌当【铁索连环】使用或重铸。
-- 使用走正式 ViewAs 入口：其他效果要求使用【铁索连环】时也能用梅花手牌转化。
-- 引擎同一技能只允许一个 active/viewas 效果，重铸由独立辅助技能
-- qiao__skill_shu010_1_recast 承担，随连环授予、随连环失去。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu010_1",
}
skill.qiaoImplemented = true

local IRON_CHAIN = "qiao__iron_chain"
local RECAST = "qiao__skill_shu010_1_recast"

skill:addEffect("viewas", {
  anim_type = "offensive",
  pattern = IRON_CHAIN,
  prompt = "#qiao__skill_shu010_1-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|club|^equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard(IRON_CHAIN)
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
})

skill:addAcquireEffect(function(self, player)
  local room = player.room or Fk:currentRoom()
  if room == nil or Fk.skills[RECAST] == nil then return end
  room:handleAddLoseSkills(player, RECAST, skill.name, false, true)
end)

skill:addLoseEffect(function(self, player)
  local room = player.room or Fk:currentRoom()
  if room ~= nil and not player.dead then
    room:handleAddLoseSkills(player, "-" .. RECAST, skill.name, false, true)
  end
end)

Fk:loadTranslationTable {
  ["qiao__skill_shu010_1"] = "连环",
  [":qiao__skill_shu010_1"] = "你可以将一张梅花手牌当【铁索连环】使用或重铸。",
  ["#qiao__skill_shu010_1-prompt"] = "连环：将一张梅花手牌当【铁索连环】使用",
}

return skill
