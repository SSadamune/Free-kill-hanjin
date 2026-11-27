local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local tracker = require "packages.qiao.pkg.qiao_generals.util.reveal_ticket"
local VirtualEquip = require "packages.qiao.pkg.qiao_bingqing.virtual_equipment"
local M = { skill = "qiao__skill_han043_1", general = "qiao_heg__han043", mark = "qiao_bajia_yu" }
M.reveal = tracker(M.general, function() return M.skill end)

-- 配置取装备的君主归属。开局牌堆对虚妄之冕的魏／晋保留条件另行处理。
local lord = {
  qiao__chixiao_sword = "han", qiao__jade_seal = "han", qiao__sihai_liuqian = "han",
  qiao__liulongcanjia = "wei", qiao__zhoujun_lingbingyin = "wei",
  qiao__dragon_phoenix = "shu", qiao__jinxiu_zhengpao = "shu",
  qiao__luminous_pearl = "wu", qiao__feiyun_gaihai = "wu",
  qiao__peace_spell = "qun", qiao__shenshou_sizhao = "qun", qiao__xuehai_mowangzun = "qun",
  qiao__linxiao_yuyu = "jin", qiao__zouyu_fan = "jin", qiao__xuwang_zhimian = "wild",
}

function M.cards(p)
  local list = {}
  for _, id in ipairs(p:getTableMark(M.mark)) do
    if table.contains(p:getCardIds("e"), id) then table.insert(list, p:getVirtualEquip(id) or Fk:getCardById(id)) end
  end
  return list
end

function M.shared(p, raw)
  local cards = {}
  if not S.present(p) then return cards end
  for _, source in ipairs(Fk:currentRoom():getPresentPlayers()) do
    if source ~= p and source:getMark(M.mark) ~= 0 and S.allies(source, p) and source:hasShownSkill(M.skill, raw) then
      table.insertTable(cards, M.cards(source))
    end
  end
  return cards
end

function M.lordKingdoms(p)
  local result = {}
  for _, card in ipairs(M.cards(p)) do
    if lord[card.name] then table.insertIfNeed(result, lord[card.name]) end
  end
  return result
end

local GRANTS = "qiao_bajia_skill_grants"
function M.sync(p)
  local supplied = VirtualEquip.skillNames(M.shared(p, true), p)
  VirtualEquip.syncSkills(p, M.skill, GRANTS, supplied, function(player) return player:getCardIds("e") end)
end
function M.suppressed(p, sk)
  local root = sk:getSkeleton()
  if not root or not table.contains(p:getTableMark(GRANTS), root.name) then return false end
  local physical = VirtualEquip.cardsInEquipZone(p, p:getCardIds("e"))
  if table.contains(VirtualEquip.skillNames(physical, p), root.name) then return false end
  return not table.contains(VirtualEquip.skillNames(M.shared(p), p), root.name)
end
function M.updateRoom(room)
  for _, p in ipairs(room.players) do M.sync(p) end
end
return M
