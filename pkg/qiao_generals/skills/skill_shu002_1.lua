-- SHU002 关羽 · 武圣
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU002。
-- 1. 一张红色牌当【杀】使用或打出（手牌或装备区）；
-- 2. 锁定效果：使用方片牌无距离限制（任何牌，不限【杀】）；
-- 3. 使用红桃牌对唯一目标造成伤害后，若其装备区有牌，可以视为对其使用
--    【水淹七军】。红桃牌不限于【杀】，火攻等非【杀】牌同样触发。
--
-- “唯一目标”按本次使用的目标列表判断；铁索传导伤害不属于对该牌目标的伤害，
-- 不触发。水淹七军调用正式汉晋牌技能，目标条件由该牌自身校验。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu002_1",
}
skill.qiaoImplemented = true

local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local DROWNING = "qiao__drowning"

local function currentUse(room)
  local event = room.logic:getCurrentEvent()
  local useEvent = event and event:findParent(GameEvent.UseCard)
  return useEvent and useEvent.data or nil
end

skill:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "slash|.|.|.|qiao__slash",
  mute_card = true,
  prompt = "#qiao__skill_shu002_1-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|red",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__slash")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
})

-- 方片牌无距离限制：只绕过距离，不修改牌面目标条件。
skill:addEffect("targetmod", {
  bypass_distances = function(self, player, skill_, card, to)
    if player == nil or card == nil or not player:hasSkill(skill.name) then return false end
    return card.suit == Card.Diamond
  end,
})

skill:addEffect(fk.Damage, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) then return false end
    if target ~= player or data.from ~= player then return false end
    if data.to == nil or data.to.dead or data.chain then return false end
    if data.card == nil or data.card.suit ~= Card.Heart then return false end
    if #data.to:getCardIds("e") == 0 then return false end
    local use = currentUse(player.room)
    if use == nil or use.card == nil or use.card.suit ~= Card.Heart then return false end
    return use:isOnlyTarget(data.to) and use.card.trueName == data.card.trueName
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu002_1-invoke:" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = data.to
    if player.dead or to == nil or to.dead or to:isRemoved() then return end
    if #to:getCardIds("e") == 0 then return end
    C.useVirtualCard(room, player, DROWNING, nil, { to }, skill.name, true)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu002_1"] = "武圣",
  [":qiao__skill_shu002_1"] = "你可以将一张红色牌当【杀】使用或打出；你使用方片牌无距离限制；你使用红桃牌对唯一目标造成伤害后，若其装备区有牌，你可以视为对其使用【水淹七军】。",
  ["#qiao__skill_shu002_1-prompt"] = "武圣：将一张红色牌当【杀】使用或打出",
  ["#qiao__skill_shu002_1-invoke"] = "武圣：你可以视为对其使用【水淹七军】",
}

return skill
