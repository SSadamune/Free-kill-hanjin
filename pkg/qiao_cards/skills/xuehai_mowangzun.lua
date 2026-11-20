-- 血海魔王樽：装备者有合法用【酒】请求时，按座次询问公开同势力角色
-- （含装备者）是否实际打出一张黑桃牌；首次成功后由装备者视为使用【酒】。
-- 装备者脱离濒死时，将装备区里的此牌交给本次濒死的伤害来源。
local Heg = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__xuehai_mowangzun_skill",
  attached_equip = "qiao__xuehai_mowangzun",
}

local function makeWine()
  return Fk:cloneCard("analeptic", nil, nil, skill.name)
end

local function canDrink(player, wine, extra)
  return table.contains(wine:getAvailableTargets(player, extra), player)
end

local function candidates(room, player)
  local list = {}
  for _, other in ipairs(room:getPresentPlayers()) do
    if not other:isRemoved()
      and (other == player or Heg.compareKingdomWith(player, other, false, true)) then
      table.insert(list, other)
    end
  end
  room:sortByAction(list)
  return list
end

skill:addEffect("viewas", {
  pattern = "analeptic|0|nosuit|none",
  prompt = "#qiao__xuehai-invoke",
  card_filter = Util.FalseFunc,
  view_as = function(self, player, cards)
    if #cards == 0 then return makeWine() end
  end,
  enabled_at_play = function(self, player)
    return canDrink(player, makeWine())
  end,
  enabled_at_response = function(self, player, responding)
    if responding then return false end
    local handler = ClientInstance and ClientInstance.current_request_handler
    return canDrink(player, makeWine(), handler and handler.extra_data)
  end,
  on_use = function(self, room, effect, wine, params)
    local player = effect.from
    local extra = params and params.extra_data or nil
    local rejected = params and self.name or ""
    if not wine or not player:hasSkill(skill.name) then return rejected end
    if params then
      if not params.pattern or not Exppattern:Parse(params.pattern):match(wine) then return rejected end
      if extra and extra.fix_user and extra.fix_user ~= player.id then return rejected end
    elseif room.current ~= player or player.phase ~= Player.Play then
      return rejected
    end
    if not canDrink(player, wine, extra) then return rejected end
    for _, helper in ipairs(candidates(room, player)) do
      if helper:isAlive() and not helper:isRemoved() then
        local respond = room:askToResponse(helper, {
          skill_name = skill.name,
          pattern = ".|.|spade",
          prompt = "#qiao__xuehai-ask::" .. player.id,
          cancelable = true,
        })
        if respond and room:responseCard(respond) ~= false then
          return { from = player, card = wine, tos = { player }, extra_data = extra }
        end
      end
    end
    return rejected
  end,
})

-- 脱离濒死：交给造成本次濒死的伤害来源；无来源/来源死亡/来源为自己/原牌离开装备区均不执行。
skill:addEffect(fk.AfterDying, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return false end
    local damage = data.damage
    if damage == nil or damage.from == nil or damage.from == player or damage.from.dead then
      return false
    end
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      local card = Fk:getCardById(id)
      if card ~= nil and card.name == skill.attached_equip then return true end
    end
    return false
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local source = data.damage.from
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      local card = Fk:getCardById(id)
      if card ~= nil and card.name == skill.attached_equip then
        if not source:isHandAreaSealed() then
          room:obtainCard(source, id, false, fk.ReasonGive)
        end
        return
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "血海魔王樽",
  ["#qiao__xuehai-invoke"] = "血海魔王樽：请求同势力角色打出黑桃牌，令你视为使用【酒】",
  ["#qiao__xuehai-ask"] = "血海魔王樽：是否打出黑桃牌协助 %dest 使用【酒】",
  [":" .. skill.name] = "当你需要合法使用【酒】时，同势力角色可打出黑桃牌协助；"
    .. "首次成功后你视为使用【酒】。你脱离濒死时，将此牌交给伤害来源。",
}

return skill
