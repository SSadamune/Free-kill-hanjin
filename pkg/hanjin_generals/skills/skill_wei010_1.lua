-- WEI010 徐晃 · 断粮
--
-- 规则基线：rules/standard-generals.md 魏区 WEI010。
-- 一张黑色非锦囊牌当【兵粮寸断】使用；只授权手牌。
-- 其他角色跳过摸牌阶段后，可以令一名角色摸一张牌。这里监听真实的
-- fk.EventPhaseSkipped（阶段已被跳过之后），不依赖兵粮寸断这一具体来源：
-- 任何原因造成的摸牌阶段跳过都可以触发。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei010_1",
}

local SUPPLY_SHORTAGE = "hanjin__supply_shortage"

skill:addEffect("viewas", {
  pattern = SUPPLY_SHORTAGE,
  prompt = "#hanjin__skill_wei010_1-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    -- 牌名|点数|花色|区域|完整牌名|类别：黑色且为基本牌或装备牌（排除锦囊）。
    pattern = ".|.|black|||basic,equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard(SUPPLY_SHORTAGE)
    card.skillName = skill.name
    card:addSubcards(cards)
    return card
  end,
})

skill:addEffect(fk.EventPhaseSkipped, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target ~= player and player:hasSkill(skill.name) and not player.dead
      and data.phase == Player.Draw and target:isAlive() and not target:isRemoved()
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei010_1-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = room.alive_players,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei010_1-draw",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return end
    to:drawCards(1, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei010_1"] = "断粮",
  [":hanjin__skill_wei010_1"] = "你可以将一张黑色非锦囊牌当【兵粮寸断】使用。其他角色跳过摸牌阶段后，你可以令一名角色摸一张牌。",
  ["#hanjin__skill_wei010_1-prompt"] = "断粮：将一张黑色非锦囊牌当【兵粮寸断】使用",
  ["#hanjin__skill_wei010_1-invoke"] = "断粮：%dest 跳过了摸牌阶段，你可以令一名角色摸一张牌",
  ["#hanjin__skill_wei010_1-draw"] = "断粮：选择一名角色摸一张牌",
}

skill.hanjinImplemented = true

return skill
