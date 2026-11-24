-- JIN004 贾充 · 通法
--
-- 规则基线：docs/rules/generals/jin004-jiachong.md、docs/rules/adaptation.md。
-- 同势力角色实际使用应变牌时，由使用者选择交给你一张自己的牌（使用者即你时
-- 改为弃置），随后本次使用获得一个无视条件令牌。令牌属于本次使用，只让一个
-- 尚未满足的条目成立，不把整张牌的所有条目视为成功，也不等待某个条目触发。
--
-- 由实际用牌并支付的角色发动。贾充自己发动可按原生流程明置，其他角色只能
-- 为已经公开的技能来源支付。
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local B = require "packages.qiao.pkg.qiao_generals.util.jin_basic"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin004_1",
}
skill.qiaoImplemented = true

local PAID = "qiao_jin004_paid"

local function canPay(user, owner)
  return user ~= nil and not user.dead and table.find(user:getCardIds("he"), function(id)
    return user ~= owner or not user:prohibitDiscard(id)
  end) ~= nil
end

local function tongfaOwner(user)
  if user:hasSkill(skill.name) and canPay(user, user) then return user end
  local candidates = user.room:getPresentPlayers()
  user.room:sortByAction(candidates)
  return table.find(candidates, function(owner)
    return owner ~= user and owner:hasShownSkill(skill.name)
      and B.sameKingdom(user, owner) and canPay(user, owner)
  end)
end

--- 由实际使用者支付一张自己的牌：自己是贾充时弃置，否则交给贾充。
---@return boolean paid
local function pay(room, user, jiaChong)
  if not canPay(user, jiaChong) then return false end

  if user == jiaChong then
    local ids = room:askToDiscard(user, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin004_1-discard-invoke",
      cancelable = true,
    })
    return #ids == 1 and not table.contains(user:getCardIds("he"), ids[1]) or false
  end

  local id = room:askToCards(user, {
    include_equip = true, min_num = 1, max_num = 1, cancelable = true,
    skill_name = skill.name,
    prompt = "#qiao__skill_jin004_1-give-invoke",
  })[1]
  if id == nil or not table.contains(user:getCardIds("he"), id) then return false end
  room:obtainCard(jiaChong, id, true, fk.ReasonGive, user, skill.name)
  -- 牌在移动事件中仍可能被其他效果移走；只要已离开支付者，交给即已完成。
  return not table.contains(user:getCardIds("he"), id)
end

skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and target == data.from
      and not player.dead and not player:isRemoved()
      and A.isAdaptationCard(data.card, data)
      and not (data.extra_data or {})[PAID]
      and tongfaOwner(player) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local owner = tongfaOwner(player)
    return owner ~= nil and pay(player.room, player, owner)
  end,
  on_use = function(self, event, target, player, data)
    data.extra_data = data.extra_data or {}
    data.extra_data[PAID] = true
    A.grantIgnore(data, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin004_1"] = "通法",
  ["#qiao__skill_jin004_1-give-invoke"] = "通法：你可以交给贾充一张牌，令此牌无视一项应变条件",
  ["#qiao__skill_jin004_1-discard-invoke"] = "通法：你可以弃置一张牌，令此牌无视一项应变条件",
}

return skill
