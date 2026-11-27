-- EM(WU001) 孙权的缘江烽火图公共入口。
-- 烽火是持旗君主私人牌堆中的公开牌；这里只提供旗牌堆、技能 ID、君主与
-- 吴势力判定。所有判定只读公开或自身可见状态，供服务端与客户端共用。
local M = {}

M.PILE = "qiao_em_wu001_fenghuo"
M.LORD = "qiao_heg__em_wu001"
M.JIAHE = "qiao__skill_em_wu001_1"
M.LIANZI = "qiao__skill_em_wu001_2"
M.JUBAO = "qiao__skill_em_wu001_3"
M.FLAG = "qiao__skill_em_wu001_flag"
M.ENTRY = "qiao__skill_em_wu001_flag_entry"
M.PEARL = "qiao__luminous_pearl"

-- 调用方区分选牌时公开的聚宝与实际移牌时发动的聚宝。
function M.isProtectedTreasure(owner, proposer, id)
  if not proposer or proposer == owner then return false end
  local card = owner:getVirtualEquip(id) or Fk:getCardById(id, true)
  return card and card.sub_type == Card.SubtypeTreasure
end

function M.isPubliclyProtectedTreasure(owner, proposer, id)
  return M.isProtectedTreasure(owner, proposer, id) and owner:hasShownSkill(M.JUBAO)
end

-- 准备阶段临时授技：来源只记本次授予，到期只撤销这一份。
M.SOURCE = "qiao__skill_em_wu001_flag_source"
M.RULE = "qiao__skill_em_wu001_rule"
M.TEMP = "qiao_em_wu001_temp_skills"

-- 受牌伤害后建立的“本回合下次受到的伤害-1”待生效计数。
M.REDUCE = "qiao_em_wu001_damage_reduce"

-- 复用项目同文技能的固有名（英姿/好施/度势），攻心为本旗独立注册。
M.YINGZI = "qiao__skill_wu005_1"
M.HAOSHI = "qiao__skill_wu014_1"
M.GONGXIN = "qiao__gongxin"
M.DUSHI = "qiao__skill_wu007_2"

--- 存活、未移除的吴势力角色。只读 kingdom，不读他人暗将私有字段。
function M.isWu(player)
  return player ~= nil and not player.dead and not player:isRemoved()
    and player.kingdom == "wu"
end

function M.flagActive(player)
  return M.isWu(player) and player:hasShownSkill(M.JIAHE) and player:hasSkill(M.FLAG)
end

--- 当前持旗君主：嘉禾已明置有效、缘江烽火图来源实际存在、且为吴势力。
function M.lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room:getPresentPlayers()) do
    if M.flagActive(p) then
      return p
    end
  end
  return nil
end

--- 旗入口的可用持旗者；使用者本人也必须是吴势力角色。
function M.lordFor(player)
  if not M.isWu(player) then return nil end
  return M.lord(Fk:currentRoom())
end

function M.count(player)
  if player == nil then return 0 end
  return #player:getPile(M.PILE)
end

--- 到期清理规则技能：只安装一次，随模式房间保留（旗消失不提前移除）。
function M.ensureRule(room)
  if room == nil then return end
  local rule = Fk.skills[M.RULE]
  if rule ~= nil and not room:hasSkill(M.RULE) then
    room:addSkill(rule)
  end
end

--- 本次授技来源；只登记实际授予的技能名，不附武将牌。
function M.addTempSkill(room, player, skillName)
  if room == nil or player == nil or Fk.skills[skillName] == nil then return end
  room:handleAddLoseSkills(player, skillName, M.SOURCE, false, true)
  local list = table.simpleClone(room:getTag(M.TEMP) or {})
  list[player.id] = list[player.id] or {}
  table.insertIfNeed(list[player.id], skillName)
  room:setTag(M.TEMP, list)
end

function M.hasTemp(room, player)
  if room == nil or player == nil then return false end
  local list = room:getTag(M.TEMP)
  return list ~= nil and list[player.id] ~= nil
end

--- 到期只撤本次授予的来源；角色原有或其他独立来源的同名技能保留。
function M.expireTemp(room, player)
  if room == nil or player == nil then return end
  local list = table.simpleClone(room:getTag(M.TEMP) or {})
  for _, skillName in ipairs(list[player.id] or {}) do
    room:handleAddLoseSkills(player, "-" .. skillName, M.SOURCE, false, true)
  end
  list[player.id] = nil
  room:setTag(M.TEMP, next(list) ~= nil and list or nil)
end

--- 从旗牌堆按正常移牌处理移去一张烽火（置入弃牌堆，非弃置）。
--- 原文未指定哪一张：多张时由持旗者从公开的旗牌堆中选择，不可取消；单张直接移去。
--- 返回是否确实移去；被取消或改投其它区域的移动不建立后续减伤。
---@param room Room
---@param player ServerPlayer 持旗者
---@return boolean
function M.removeOneFenghuo(room, player)
  if room == nil or player == nil then return false end
  local ids = player:getPile(M.PILE)
  if #ids == 0 then return false end
  local id
  if #ids == 1 then
    id = ids[1]
  else
    id = room:askToChooseCard(player, {
      target = player,
      flag = { card_data = { { M.PILE, ids } } },
      skill_name = M.FLAG,
      prompt = "#qiao__skill_em_wu001_flag-remove",
    })
  end
  -- 提交结果须仍是该角色旗牌堆中的牌。
  if id == nil or not table.contains(player:getPile(M.PILE), id) then return false end
  room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, M.FLAG, nil, true, player)
  -- 成功以实际离开该私人牌堆为准：移动可能被取消或被改投其它区域。
  return not table.contains(player:getPile(M.PILE), id)
end

--- 已建立的本回合“下次受到的伤害-1”待生效次数。
function M.pending(player)
  if player == nil then return 0 end
  return player:getMark(M.REDUCE)
end

function M.addPending(room, player)
  if room == nil or player == nil then return end
  room:addPlayerMark(player, M.REDUCE, 1)
end

--- 消耗一次待生效减伤；返回是否确实消耗。
function M.consumePending(room, player)
  if room == nil or player == nil or M.pending(player) < 1 then return false end
  room:addPlayerMark(player, M.REDUCE, -1)
  return true
end

function M.clearPending(room, player)
  if room == nil or player == nil then return end
  room:setPlayerMark(player, M.REDUCE, 0)
end

return M
