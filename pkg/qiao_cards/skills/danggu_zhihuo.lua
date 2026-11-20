-- 党锢之祸（汉势力锦囊）：普通锦囊，对所有其他合法角色使用。
--
-- 规则基线：docs/rules/card-deck.md「势力锦囊的结算审阅 · 党锢之祸」。
--   * 逐目标由用牌者选择一张可暗置的明置武将牌并暗置，走公共暗置入口
--     （qun_control 的 hideRevealedGeneral）：按公开已明置的真实位置选择，
--     排除君主（含汉晋独立君主）、专属野心家、士兵／翼从／偏将等；已暗位置
--     不可选，异常回复按服务器候选复核；最终走公共 hideGeneral 流程。
--   * 暗置与否不影响后续限制：此牌对目标生效后，对该目标建立“不能明置”，
--     持续到用牌者下回合开始或死亡；不同用牌者的限制分别到期。
--   * 汉势力条款于“成为目标后”处理：用牌时已确定为汉（快照）且该目标当前
--     为汉时，其可实际交给用牌者一张手牌或装备；成功交出后仅此目标无效。
local QunControl = require "packages.qiao.pkg.qiao_generals.util.qun_control"
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"

local skill = fk.CreateSkill {
  name = "qiao__danggu_zhihuo_skill",
}

local CARD = "qiao__danggu_zhihuo"
--- 禁明置来源标记：按用牌者分别建立；带 -noclear 后缀以免被回合末清理，
--- 由本技能在用牌者下回合开始或死亡时清除。
local REVEAL_PREFIX = "RevealProhibited-qiao_danggu-"
local REVEAL_SUFFIX = "-noclear"
--- 主将 m、副将 d 均不能明置。
local PLACES = { "m", "d" }
local SOURCES_TAG = "qiao_danggu_reveal_sources"

local function markName(userId)
  return REVEAL_PREFIX .. tostring(userId) .. REVEAL_SUFFIX
end

---@return boolean
local function isDanggu(card)
  if card == nil then return false end
  return card.name == CARD or card.skillName == skill.name
    or table.contains(card.skillNames or {}, skill.name)
end

--- 为某目标建立“不能明置”限制，来源为用牌者。
local function applyRestriction(room, user, target)
  local name = markName(user.id)
  local places = target:getMark(name)
  local merged = type(places) == "table" and table.simpleClone(places) or {}
  for _, place in ipairs(PLACES) do table.insertIfNeed(merged, place) end
  room:setPlayerMark(target, name, merged)

  local list = room:getTag(SOURCES_TAG) or {}
  local rec = list[tostring(user.id)] or { applied = {} }
  rec.applied[target.id] = true
  list[tostring(user.id)] = rec
  room:setTag(SOURCES_TAG, list)
end

--- 撤销某用牌者建立的全部禁明置限制，不触碰其他来源的标记。
local function clearRestriction(room, userId)
  local list = room:getTag(SOURCES_TAG) or {}
  local rec = list[tostring(userId)]
  if rec == nil then return end
  for pid in pairs(rec.applied or {}) do
    local target = room:getPlayerById(pid)
    if target ~= nil and target:getMark(markName(userId)) ~= 0 then
      room:setPlayerMark(target, markName(userId), 0)
    end
  end
  list[tostring(userId)] = nil
  room:setTag(SOURCES_TAG, next(list) ~= nil and list or nil)
end

local function sourcePending(room, userId)
  local list = room:getTag(SOURCES_TAG)
  return list ~= nil and list[tostring(userId)] ~= nil
end

-- 汉势力条款：成为目标后处理。交出的是“自己的牌”，成功交出才令此牌对
-- 该目标无效；未交出或未实际移动时照常结算。
skill:addEffect(fk.TargetConfirmed, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if target == nil or data == nil or data.from == nil then return false end
    if not isDanggu(data.card) then return false end
    if target == data.from or target.dead or target:isRemoved() then return false end
    if #target:getCardIds("he") == 0 then return false end
    if not FactionTricks.useConfirmed(data.extra_data) then return false end
    return FactionTricks.isConfirmedKingdom(target, "han")
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local user = data.from
    if user == nil or user.dead then return end
    local card = room:askToCards(target, {
      include_equip = true, min_num = 1, max_num = 1, cancelable = true,
      skill_name = skill.name,
      prompt = "#qiao__danggu_zhihuo-give",
    })[1]
    if card == nil or not table.contains(target:getCardIds("he"), card) then return end
    room:obtainCard(user, card, true, fk.ReasonGive, target)
    -- 只有本次实际交给用牌者，才令此牌仅对该目标无效。
    if room:getCardOwner(card) ~= user then return end
    data:setNullified(target)
  end,
})

skill:addEffect("cardskill", {
  prompt = "#qiao__danggu_zhihuo_skill",
  can_use = Util.CanUseFixedTarget,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return to_select ~= player and not to_select.dead and not to_select:isRemoved()
  end,
  on_effect = function(self, room, effect)
    local user, target = effect.from, effect.to
    if user == nil or target == nil then return end
    if target == user or target.dead or target:isRemoved() then return end
    -- 只按公开已明置的真实位置选择：排除君主（含汉晋独立君主）、专属野心家、
    -- 士兵/翼从/偏将等；无可暗位置时不暗置，但仍建立禁明置限制。
    QunControl.hideRevealedGeneral(room, user, target, skill.name)
    if user.dead or target.dead or target:isRemoved() then return end
    -- 没有可暗置将牌时仍建立禁明置限制。
    applyRestriction(room, user, target)
  end,
})

-- 限制持续到用牌者下回合开始。
skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and sourcePending(Fk:currentRoom(), target.id)
  end,
  on_refresh = function(self, event, target, player, data)
    clearRestriction(Fk:currentRoom(), target.id)
  end,
})

-- 用牌者死亡时其来源同时到期。
skill:addEffect(fk.Death, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and sourcePending(Fk:currentRoom(), target.id)
  end,
  on_refresh = function(self, event, target, player, data)
    clearRestriction(Fk:currentRoom(), target.id)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "党锢之祸",
  ["#qiao__danggu_zhihuo_skill"] = "党锢之祸：暗置每名其他角色一张武将牌",
  ["#qiao__danggu_zhihuo-give"] = "党锢之祸：你可以交给使用者一张手牌或装备，令此牌对你无效",
}

return skill
