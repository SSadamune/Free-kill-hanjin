-- HAN024 灵雎 · 竭缘
-- 当你对其他角色造成伤害时，或受到其他角色造成的伤害时，若其体力值大于等于你，
-- 你可以弃置一张红色牌，然后令此伤害+1或-1。

local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_han024_1",
}
skill.qiaoImplemented = true

local OPT_PLUS = "#qiao__skill_han024_1-plus"
local OPT_MINUS = "#qiao__skill_han024_1-minus"

local function discardableRed(player)
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.color == Card.Red and not player:prohibitDiscard(id)
  end)
end

local function makeEffect(isDealing)
  return {
    anim_type = isDealing and "offensive" or "defensive",
    can_trigger = function(self, event, target, player, data)
      if target ~= player or not player:hasSkill(skill.name) then return false end
      local other = isDealing and data.to or data.from
      if other == nil or other == player then return false end
      return other.hp >= player.hp and #discardableRed(player) > 0
    end,
    on_cost = function(self, event, target, player, data)
      local room = player.room
      local other = isDealing and data.to or data.from
      local legal = discardableRed(player)
      local all = player:getCardIds("he")
      -- 使用原生选牌＋选项面板；空回复保留本次不发动的权利。
      local reply = room:askToCustomDialog(player, {
        skill_name = skill.name,
        component = {
          uri = "LunarLtk.Pages.Popups", name = "ChooseCardsAndChoiceBox",
          model = { uri = "LunarLtk.Models.Popups", name = "ChooseCardsAndChoiceModel", prop = {
            cards = all, disabledCards = table.filter(all, function(id) return not table.contains(legal, id) end),
            choices = { OPT_PLUS, OPT_MINUS }, cancelChoices = { "Cancel" },
            prompt = "#qiao__skill_han024_1-discard::" .. other.id,
          } },
        },
      })
      if type(reply) ~= "table" then return false end
      local cards, choice = reply.cards, reply.choice
      if (choice == OPT_PLUS or choice == OPT_MINUS) and type(cards) == "table"
        and #cards == 1 and table.contains(discardableRed(player), cards[1]) then
        Selection.confirm(room, player)
        event:setCostData(self, { cards = cards, choice = choice })
        return true
      end
      return false
    end,
    on_use = function(self, event, target, player, data)
      local room = player.room
      local cost = event:getCostData(self) or {}
      local cards, choice = cost.cards, cost.choice
      if type(cards) ~= "table" or #cards ~= 1 then return end
      -- 按通用消耗裁定：选定合法牌并执行弃置动作后，即视为已支付消耗。
      room:throwCard(cards, skill.name, player, player)
      if choice == OPT_PLUS then
        data:changeDamage(1)
      elseif choice == OPT_MINUS then
        if data.damage <= 1 then
          data:preventDamage()
        else
          data:changeDamage(-1)
        end
      end
    end,
  }
end

skill:addEffect(fk.DamageCaused, makeEffect(true))
skill:addEffect(fk.DamageInflicted, makeEffect(false))

Fk:loadTranslationTable {
  [skill.name] = "竭缘",
  [":" .. skill.name] = "当你对其他角色造成伤害时，或受到其他角色造成的伤害时，若其体力值大于等于你，你可以弃置一张红色牌，然后令此伤害+1或-1。",
  ["#qiao__skill_han024_1-discard"] = "竭缘：你可以弃置一张红色牌，令与 %dest 之间的此伤害+1或-1",
  [OPT_PLUS] = "伤害+1",
  [OPT_MINUS] = "伤害-1",
}

return skill
