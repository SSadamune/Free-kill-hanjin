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
  name = "hanjin__skill_wu007_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local MARK = "hanjin__skill_wu007_1_used-turn"

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

skill:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if player:getMark(MARK) > 0 then return false end
    local card = data.card
    if card == nil or card.type ~= Card.TypeTrick then return false end
    -- 原文没有排除自己使用的锦囊：自己使用且自己成为目标也计入“首次”。
    return true
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, MARK)
    if hasUnspecifiedLegalTarget(player, data) then
      data:cancelCurrentTarget()
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu007_1"] = "谦逊",
}

return skill
