-- 六势力权包共用辅助：定向叠置、可暗置/可移除武将牌判定、每区弃一、玉玺状态与模式延时记账。
-- 客户端可达查询统一使用 Fk:currentRoom() 与公开状态，不读取服务端私有字段。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local M = {}

M.YUJUE_DRAW_MARK = "qiao_han003_yujue_draw-turn"
M.XUANHU_RED_MARK = "qiao_han021_red_discarded-turn"
M.ZHENGPI_TWICE_MARK = "qiao_wei021b_zhengpi_twice-turn"
M.JUEYAN_DRAW_MARK = "qiao_wu019_jueyan_draw-turn"
M.JUEYAN_SLASH_MARK = "qiao_wu019_jueyan_slash-turn"
M.JUEYAN_RANGE_MARK = "qiao_wu019_jueyan_range-turn"
M.DRAWN_TURN_MARK = "qiao_quan_drawn-turn"
M.WUDANG_PENDING_MARK = "qiao_wudang_feijun_pending-turn"
M.WEIDI_SKILL = "qiao__skill_qun021_2"
M.FEILU_SKILL = "qiao__skill_jin024_2"
M.FEILU_USED_TAG = "qiao_jin024_feilu_used_v1"

--- 汉晋定向叠置：仅平置改为叠置，已叠置不反向平置。
function M.directedStack(target)
  if target ~= nil and RemovedTargets.isPresent(target) and target.faceup then
    target:turnOver()
    return true
  end
  return false
end

--- 是否已有暗置武将牌（公开状态判断）。
function M.hasHiddenGeneral(player)
  if player == nil then return false end
  return player.general == "anjiang" or player.deputyGeneral == "anjiang"
end

--- 指定位置是否为可被暗置的明置武将牌（排除暗置、士兵/翼从/偏将、君主及专属野心家）。
function M.canHideGeneralPosition(player, isDeputy)
  if player == nil or player.dead then return false end
  local public = Exchange.publicGeneral(player, isDeputy)
  if type(public) ~= "string" or public == "" or public == "anjiang" then return false end
  if Commander.isSoldier(public) then return false end
  if Exchange.isLordPosition(player, isDeputy) then return false end
  if Exchange.isWildGeneral(public) then return false end
  return true
end

--- 指定位置是否为可被移除的普通武将牌（排除空位、士兵/翼从/偏将、君主及明置专属野心家；暗置普通武将牌允许移除）。
function M.canRemoveOrdinaryPosition(player, isDeputy)
  if player == nil or player.dead then return false end
  local actual = Exchange.actualGeneral(player, isDeputy)
  if type(actual) ~= "string" or actual == "" or actual == "anjiang" then return false end
  if Commander.isSoldier(actual) then return false end
  if Exchange.isLordPosition(player, isDeputy) then return false end
  if Exchange.isRevealed(player, isDeputy) and Exchange.isWildGeneral(actual) then return false end
  return true
end

--- 角色是否至少有一张可被弃置的牌（手牌区、装备区或判定区）。
function M.hasDiscardableInAnyArea(player)
  if player == nil or not RemovedTargets.isPresent(player) then return false end
  for _, id in ipairs(player:getCardIds("he")) do
    if not player:prohibitDiscard(id) then return true end
  end
  return #player:getCardIds("j") > 0
end

--- 令目标依次从手牌区、装备区、判定区各弃置一张牌（无合法牌的区域跳过）。
--- 供贾南风【伤败】与翼从【无当飞军】共用。
function M.discardOnePerArea(room, target, skillName)
  if room == nil or target == nil or not RemovedTargets.isPresent(target) then return end
  -- 1. 手牌区
  local handValid = table.filter(target:getCardIds("h"), function(id)
    return not target:prohibitDiscard(id)
  end)
  if #handValid > 0 then
    local chosen = room:askToDiscard(target, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skillName,
      prompt = "#qiao_quan_discard_hand:::" .. skillName,
      cancelable = false,
    })
    if not chosen or #chosen == 0 then
      local fallback = table.find(target:getCardIds("h"), function(id)
        return not target:prohibitDiscard(id)
      end)
      if fallback ~= nil then room:throwCard({ fallback }, skillName, target, target) end
    end
  end
  if not RemovedTargets.isPresent(target) then return end

  -- 2. 装备区
  local equipValid = table.filter(target:getCardIds("e"), function(id)
    return not target:prohibitDiscard(id)
  end)
  if #equipValid > 0 then
    local id = #equipValid == 1 and equipValid[1] or room:askToChooseCard(target, {
      target = target,
      flag = { card_data = { { "$Equip", equipValid } } },
      skill_name = skillName,
      prompt = "#qiao_quan_discard_equip:::" .. skillName,
    })
    if id == nil or not table.contains(equipValid, id) then id = equipValid[1] end
    if id ~= nil and table.contains(target:getCardIds("e"), id) and not target:prohibitDiscard(id) then
      room:throwCard({ id }, skillName, target, target)
    end
  end
  if not RemovedTargets.isPresent(target) then return end

  -- 3. 判定区（允许正常弃置延时锦囊牌）
  local judgeIds = target:getCardIds("j")
  if #judgeIds > 0 then
    local id = #judgeIds == 1 and judgeIds[1] or room:askToChooseCard(target, {
      target = target,
      flag = { card_data = { { "$Judge", judgeIds } } },
      skill_name = skillName,
      prompt = "#qiao_quan_discard_judge:::" .. skillName,
    })
    if id == nil or not table.contains(judgeIds, id) then id = judgeIds[1] end
    if id ~= nil and table.contains(target:getCardIds("j"), id) then
      room:throwCard({ id }, skillName, target, target)
    end
  end
end

--- 场上公开装备区是否存在实体【玉玺】（排除移出游戏角色；客户端与服务端共用）。
function M.hasPhysicalJadeSeal(room)
  room = room or Fk:currentRoom()
  if room == nil then return false end
  for _, p in ipairs(room:getPresentPlayers()) do
    for _, id in ipairs(p:getCardIds(Player.Equip)) do
      local card = p:getVirtualEquip(id) or Fk:getCardById(id)
      if card ~= nil and (card.name == "qiao__jade_seal" or card.trueName == "jade_seal") then
        return true
      end
    end
  end
  return false
end

--- 袁术【伪帝】当前是否正视为装备【玉玺】（两端共用）。
function M.virtualJadeSealActive(player, room)
  if player == nil or player.dead or player:isRemoved() then return false end
  if not player:hasShownSkill(M.WEIDI_SKILL) then return false end
  return not M.hasPhysicalJadeSeal(room or Fk:currentRoom())
end

--- 为目标登记一份【无当飞军】本回合防回血及回合末惩罚实例。
function M.addWudangEffect(room, target)
  if room == nil or target == nil or target.dead then return end
  room:addPlayerMark(target, M.WUDANG_PENDING_MARK, 1)
end

--- 为目标登记一次【鬻爵】本回合下次造成伤害后摸两张牌的延时效果。
function M.addYujueDraw(room, target)
  if room == nil or target == nil or target.dead then return end
  room:addPlayerMark(target, M.YUJUE_DRAW_MARK, 1)
end

Fk:loadTranslationTable {
  ["#qiao_quan_discard_hand"] = "%arg：请弃置一张手牌",
  ["#qiao_quan_discard_equip"] = "%arg：请弃置一张装备区里的牌",
  ["#qiao_quan_discard_judge"] = "%arg：请弃置一张判定区里的牌",
}

return M
