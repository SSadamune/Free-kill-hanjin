-- WEI004 张辽 · 突袭「展示后本回合只能当杀」的独立回合状态入口。
--
-- 规则依据：docs/rules/standard-generals.md 魏区 WEI004、docs/rules/only-as.md
-- 及突袭实现记录。
--
-- 展示后由突袭登记公共 only-as 来源（禁止直接使用 + 允许当【杀】使用/打出），
-- 再以 handleAddLoseSkills 把本骨架挂到角色上。转换入口不挂在突袭本体：
--   * 失去突袭时本状态仍在，不会只剩禁止而没有转换入口；
--   * 入口、提示与转换牌来源都显示为“突袭”，不创建面向玩家的“只能当”技能；
--   * 本次获得的实体牌带一张卡面提示（@ 可见标记）。提示只通知持有者，
--     并带 -turn/-inhand 后缀：回合结束或离开手牌/转移时由引擎清理，
--     不向其他客户端暴露手牌信息；
--   * 回合结束移除本骨架；限制来源由公共 only-as 规则统一到期。
local OnlyAs = require "packages.qiao.pkg.qiao_mode.rules.only_as"

local STATE = "qiao__wei_tuxi_state"
local MARK = "@qiao_tuxi_slash-turn-inhand"
local MARK_VALUE = { "·", "qiao_tuxi_slash_effect" }

local skill = fk.CreateSkill {
  name = STATE,
}

OnlyAs.addViewAsEffect(skill, "tuxi", "#qiao__wei_tuxi_state-prompt")

-- 供测试与接线核对读取；卡面标记的显示值。
skill.MARK = MARK
skill.MARK_VALUE = MARK_VALUE

local function syncMark(room, player, card, value)
  card:setMark(MARK, value)
  -- 手牌只通知持有者；隐藏信息的同步沿用应变显示的按可见范围通知方式。
  room:doBroadcastNotify("SetCardMark", { card.id, MARK, value }, { player })
end

--- 展示期间可能触发其他技能移动获得的牌；只在牌仍位于持有者的手牌/手牌般
--- 牌堆、且对应 tuxi 来源仍有效时标记，避免把提示留在已离手或失来源的牌上。
local function stillValid(player, id)
  if not OnlyAs.cardInZones(player, id, { "hand", "handly" }) then return false end
  for _, source in ipairs(OnlyAs.activeSources(player)) do
    if source.def == "tuxi" and table.contains(source.cards or {}, id) then return true end
  end
  return false
end

--- 给本次获得的实体牌加卡面提示。只有这些实体牌会带标记，其他手牌不受影响。
function skill.stampCards(room, player, ids)
  for _, id in ipairs(ids or {}) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and not card:isVirtual() and stillValid(player, id) then
      syncMark(room, player, card, MARK_VALUE)
    end
  end
end

--- 清理仍在手牌/手牌般牌堆中的提示。已经离手或转移的牌由 -inhand 清理。
local function clearMarks(room, player)
  local seen = {}
  for _, id in ipairs(player:getHandlyIds(true)) do
    if not seen[id] then
      seen[id] = true
      local card = Fk:getCardById(id, true)
      if card ~= nil and card:getMark(MARK) ~= 0 then
        syncMark(room, player, card, 0)
      end
    end
  end
end

-- 权限只持续到建立它的那个回合结束；届时清掉提示并移除本骨架。
skill:addEffect(fk.TurnEnd, {
  late_refresh = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name, true)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:sendLog { type = "#qiao_temporary_effect_ended", from = player.id, arg = STATE }
    local room = player.room
    clearMarks(room, player)
    room:handleAddLoseSkills(player, "-" .. STATE, STATE, false, true)
  end,
})

Fk:loadTranslationTable {
  [STATE] = "突袭",
  [":" .. STATE] = "摸牌阶段，你可以少摸任意张牌并获得等量名其他角色各一张手牌，然后你可以展示获得的牌，本回合这些牌只能当【杀】使用或打出。",
  ["#qiao__wei_tuxi_state-prompt"] = "突袭：将本回合获得的牌当【杀】使用或打出",
  [MARK] = "突袭",
  ["qiao_tuxi_slash_effect"] = "当【杀】使用或打出",
}

return skill
