-- QUN005 双雄 · 「本回合异色牌当【决斗】」的独立状态骨架
--
-- 这不是模式级未注册骨架：本文件位于 qiao_generals/skills，由
-- pkg/qiao_generals/init.lua 的 loadSkillSkelsByPath 随包自动加载，并在
-- 取得权限时通过 handleAddLoseSkills 以自身为来源挂到角色上。因此即使双雄
-- 本体随后失去，只要本回合的权限已经建立，本骨架仍提供转化入口；回合结束
-- 时清除标记并移除自身。牌面颜色只在权限建立时记录，之后不因弃置牌离开
-- 弃牌堆而改变。
local STATE = "qiao__qun_cards_state"
local DUEL = "qiao__duel"
local COLOR_MARK = "qiao_shuangxiong_color"

local skill = fk.CreateSkill {
  name = STATE,
}

local function colorOf(player)
  local mark = player:getMark(COLOR_MARK)
  if mark == "red" or mark == "black" then return mark end
  return nil
end

local function eligibleCards(player)
  local color = colorOf(player)
  if color == nil then return {} end
  local want = color == "red" and Card.Black or Card.Red
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.color == want
  end)
end

skill:addEffect("viewas", {
  anim_type = "offensive",
  pattern = DUEL,
  prompt = "#qiao__qun_cards_state-prompt",
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    return table.contains(eligibleCards(player), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard(DUEL)
    card.skillName = "qiao__skill_qun005_1"
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #eligibleCards(player) > 0
  end,
  -- 允许被效果要求“使用”【决斗】的请求窗口；纯“打出”窗口仍不提供。
  enabled_at_response = function(self, player, response)
    return not response and #eligibleCards(player) > 0
  end,
})

-- 权限只持续到建立它的那个回合结束；届时清除并在退出效果中移除本骨架。
skill:addEffect(fk.TurnEnd, {
  late_refresh = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name, true)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:sendLog { type = "#qiao_temporary_effect_ended", from = player.id, arg = STATE }
    local room = player.room
    room:setPlayerMark(player, COLOR_MARK, 0)
    room:handleAddLoseSkills(player, "-" .. STATE, STATE, false, true)
  end,
})

Fk:loadTranslationTable {
  [STATE] = "双雄",
  [":" .. STATE] = "你可以将一张与弃置牌颜色不同的牌当【决斗】使用（本回合）。",
  ["#qiao__qun_cards_state-prompt"] = "双雄：将一张与弃置牌颜色不同的牌当【决斗】使用",
}

skill.COLOR_MARK = COLOR_MARK

return skill
