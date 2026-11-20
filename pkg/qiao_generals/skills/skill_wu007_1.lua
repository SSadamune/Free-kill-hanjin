-- WU007 陆逊 · 谦逊
--
-- 锁定技，你每回合首次成为锦囊牌的目标时，若此牌有未指定的合法目标，
-- 取消之。
--
-- “取消之”取消的是当前目标（不是整张牌）；“有未指定的合法目标”要求除
-- 当前目标外，仍存在按牌面条件合法、且尚未在本次目标列表中的角色。因此
-- 群体锦囊已指定所有合法目标时不会取消。每回合首次成为锦囊目标即消耗
-- 本次机会，即使条件不满足。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu007_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local MARK = "qiao__skill_wu007_1_used-turn"

local function hasUnspecifiedLegalTarget(player, data)
  local use = data.use
  if use == nil or use.from == nil or data.toCard ~= nil then return false end
  local available
  local ok, ret = pcall(function()
    return data.card:getAvailableTargets(use.from, use.extra_data)
  end)
  if ok then available = ret end
  if type(available) ~= "table" then return false end
  for _, p in ipairs(available) do
    if p ~= player and p:isAlive() and not p:isRemoved()
      and not table.contains(use.tos or {}, p) then
      return true
    end
  end
  return false
end

local function isFirstTrickTarget(target, player, data)
  return target == player and player:hasSkill(skill.name) and player:getMark(MARK) == 0
    and data.card ~= nil and data.card.type == Card.TypeTrick
end

skill:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_refresh = function(self, event, target, player, data)
    return isFirstTrickTarget(target, player, data) and not hasUnspecifiedLegalTarget(player, data)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:addPlayerMark(player, MARK)
  end,
  can_trigger = function(self, event, target, player, data)
    return isFirstTrickTarget(target, player, data) and hasUnspecifiedLegalTarget(player, data)
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, MARK)
    data:cancelCurrentTarget()
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu007_1"] = "谦逊",
}

return skill
