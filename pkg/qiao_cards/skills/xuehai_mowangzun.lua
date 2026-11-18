-- 血海魔王樽：装备者有合法用【酒】请求时，按座次询问公开同势力角色
-- （含装备者）是否实际打出一张黑桃牌；首次成功后由装备者视为使用【酒】。
-- 装备者脱离濒死时，将装备区里的此牌交给本次濒死的伤害来源。
local Heg = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__xuehai_mowangzun_skill",
  attached_equip = "qiao__xuehai_mowangzun",
}

local function isWineRequest(data)
  if data == nil or data.pattern == nil then return false end
  local exp = Exppattern:Parse(data.pattern)
  return exp:match(Fk:cloneCard("analeptic"))
    or exp:matchExp("analeptic|0|nosuit|none")
end

--- 按原请求的真实合法性判断酒候选；不把濒死自救酒当普通出牌酒拒绝。
local function wineLegal(player, data)
  local wine = Fk:cloneCard("analeptic")
  wine:setVSPattern(nil, nil, ".")
  if player:prohibitUse(wine) then return false end
  local extra = data.extraData or {}
  local skillCard = wine:getSkill(player)
  if skillCard == nil or not skillCard:canUse(player, wine, extra) then return false end
  local targets = wine:getAvailableTargets(player, extra)
  if #targets == 0 then return false end
  for _, to in ipairs(targets) do
    if player:isProhibited(to, wine) then return false end
  end
  return true
end

local function requestedTargets(player, extra)
  local result = {}
  local ids = extra.must_targets or extra.fix_targets
  if type(ids) ~= "table" then return result end
  for _, id in ipairs(ids) do
    local to = player.room:getPlayerById(id)
    if to ~= nil then table.insert(result, to) end
  end
  return result
end

local function candidates(player)
  local room = player.room
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

skill:addEffect(fk.AskForCardUse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and isWineRequest(data) and wineLegal(player, data)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__xuehai-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, helper in ipairs(candidates(player)) do
      if not helper.dead and not helper:isRemoved() then
        local respond = room:askToResponse(helper, {
          skill_name = skill.name,
          pattern = ".|.|spade",
          prompt = "#qiao__xuehai-ask:" .. player.id,
          cancelable = true,
        })
        if respond then
          local rr = room:responseCard(respond)
          if rr == false then
            -- 未实际完成打出：继续询问后续协助者。
          else
            local wine = Fk:cloneCard("analeptic")
            wine.skillName = skill.name
            local extra = data.extraData or {}
            data.result = {
              from = player,
              card = wine,
              tos = requestedTargets(player, extra),
              extra_data = extra,
            }
            return
          end
        end
      end
    end
    -- 无协助：不设置 data.result，保留原用酒请求的其他入口。
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
  ["#qiao__xuehai-invoke"] = "血海魔王樽：是否请求同势力角色打出黑桃牌协助",
  ["#qiao__xuehai-ask"] = "血海魔王樽：是否打出黑桃牌协助 %dest 使用【酒】",
  [":" .. skill.name] = "当你需要合法使用【酒】时，同势力角色可打出黑桃牌协助；"
    .. "首次成功后你视为使用【酒】。你脱离濒死时，将此牌交给伤害来源。",
}

return skill
