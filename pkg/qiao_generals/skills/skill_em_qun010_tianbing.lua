-- EM(QUN010) 张角 · 黄巾天兵符（天兵当雷杀）
-- 旗的第二段：当前群势力角色（含持旗者）可将旗上一张“天兵”当雷【杀】使用或打出。
-- 入口由旗在持有期间动态授予；候选只读公开势力、有效旗技能与公开旗牌堆，
-- 客户端与服务端共用 util 的同一查询。实体子牌按正常用牌/打出流程移动，不额外弃置。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"

local THUNDER_SLASH = "qiao__thunder__slash"

local skill = fk.CreateSkill {
  name = P.ENTRY,
}
skill.qiaoImplemented = true

--- 入口是否可用：当前群势力角色、仍持有入口、旗上至少一张天兵。
---@param player Player|ClientPlayer
---@return boolean
local function usable(player)
  if player == nil or player.dead or player:isRemoved() or player.kingdom ~= "qun" then
    return false
  end
  if not player:hasSkill(P.ENTRY) then return false end
  return #P.tianbingIds(Fk:currentRoom()) > 0
end

skill:addEffect("viewas", {
  -- 请求层的牌名模式：接受一切“使用/打出【杀】”的请求；结果牌仍是正式雷杀。
  pattern = "slash",
  prompt = "#qiao__skill_em_qun010_tianbing-prompt",
  -- 旗属于持旗者；按公开 id 表展开，引擎按实际持有者显示并校验选择结果。
  expand_pile = function(self, player)
    return P.tianbingIds(Fk:currentRoom())
  end,
  card_filter = function(self, player, to_select, selected)
    if #(selected or {}) >= 1 then return false end
    return P.isTianbing(Fk:currentRoom(), to_select)
  end,
  -- 以一张真实天兵为子牌构造正式雷【杀】；非旗牌堆的牌不能参与转化。
  view_as = function(self, player, cards)
    if player == nil or player.dead or player:isRemoved()
      or player.kingdom ~= "qun" then
      return nil
    end
    if #(cards or {}) ~= 1 or not P.isTianbing(Fk:currentRoom(), cards[1]) then
      return nil
    end
    local card = Fk:cloneCard(THUNDER_SLASH)
    if card == nil then return nil end
    card:addSubcard(cards[1])
    card.skillName = skill.name
    return card
  end,
  -- 服务端用回复中的真实子牌重建结果牌后再复核来源；不合法返回技能名取消。
  before_use = function(self, player, use)
    if player == nil or player.dead or player:isRemoved()
      or player.kingdom ~= "qun" or not player:hasSkill(P.ENTRY) then
      return skill.name
    end
    if use == nil or use.card == nil or use.card.name ~= THUNDER_SLASH then
      return skill.name
    end
    local ids = Card:getIdList(use.card)
    if #ids ~= 1 or not P.isTianbing(player.room, ids[1]) then
      return skill.name
    end
  end,
  enabled_at_play = function(self, player)
    return player ~= nil and player.phase == Player.Play and usable(player)
  end,
  -- 使用与打出共用入口：被要求“使用”或“打出”杀时都可选。
  enabled_at_response = function(self, player)
    return usable(player)
  end,
})

Fk:loadTranslationTable {
  [P.ENTRY] = "天兵",
  [":" .. P.ENTRY] = "群势力角色可以将一张“天兵”当雷【杀】使用或打出。",
  ["#qiao__skill_em_qun010_tianbing-prompt"] = "天兵：将一张“天兵”当雷【杀】使用或打出",
}

return skill
