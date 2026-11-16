-- WU023 陈武&董袭关联翼从「庐江上甲」
--
-- 规则依据：rules/generals/wu023-chenwu-dongxi.md、rules/commander-retinue.md。
-- 出牌阶段限X次：X为实际拥有庐江上甲的角色数（含共享来源，不按实例总数），
-- 调整手牌至装备区牌数；若实际弃牌，则本阶段使用【杀】的次数+1。
-- 多份同名实例各自有X次：逐实例次数由 zhen_shi_retinues 维护；X按角色数
-- 去重。每次调整只加一次【杀】次数，不按弃牌张数累加。
--
-- 客户端可用性只读公开摘要、公开手牌/装备数与公开的已用次数，不读 room tag
-- 或其他角色私有手牌。来源可见性沿用引擎既有 hasSkill 与正式接入的生命周期。
local Z = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_retinues"

local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_lujiang_shangjia",
}
skill.hanjinImplemented = true

-- 本阶段实际弃牌后的【杀】次数加成；-phase 后缀由引擎在阶段结束清理。
local SLASH_BONUS = "hanjin_lujiang_shangjia_slash_bonus-phase"

--- 当前实际拥有庐江上甲的角色数（X）。同一角色多份同名实例只计 1。
---@param player Player
---@return integer
local function ownerCount(player)
  return Z.characterCount(Fk:currentRoom(), skill.name)
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#hanjin__retinue_skill_lujiang_shangjia-prompt",
  target_num = 0,
  card_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    if not player:hasSkill(skill.name) then return false end
    if player.room ~= nil then Z.ensureBonusRule(player.room) end
    if player:getHandcardNum() == #player:getCardIds("e") then return false end
    local x = ownerCount(player)
    return Z.canUse(player, skill.name, x)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end
    Z.ensureBonusRule(room)
    local hand, equip = player:getHandcardNum(), #player:getCardIds("e")
    if hand == equip then return end

    local x = Z.characterCount(room, skill.name)
    local instance = Z.availableInstances(player, skill.name, x)[1]
    if instance == nil then return end
    Z.spend(player, instance, skill.name)

    if hand > equip then
      local need = hand - equip
      local cards = room:askToDiscard(player, {
        min_num = need,
        max_num = need,
        include_equip = false,
        skill_name = skill.name,
        prompt = "#hanjin__retinue_skill_lujiang_shangjia-discard:" .. need,
        cancelable = false,
      })
      -- 实际弃牌后本阶段【杀】次数+1，与弃牌张数无关，每次调整至多加一次。
      if cards ~= nil and #cards > 0 then
        room:addPlayerMark(player, SLASH_BONUS, 1)
      end
    else
      player:drawCards(equip - hand, skill.name)
    end
  end,
})

-- “本阶段【杀】次数+1”不在本技能骨架里挂 targetmod：该加成是失去翼从后
-- 仍保留的阶段状态，改由 zhen_shi_retinue_bonus 静态规则读取公开 -phase 标记。

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_lujiang_shangjia"] = "庐江上甲",
  [":hanjin__retinue_skill_lujiang_shangjia"] =
    "出牌阶段限X次（X为拥有庐江上甲的角色数），你可以调整手牌至你装备区的牌数；若为弃牌，你此阶段使用【杀】的次数+1。",
  ["#hanjin__retinue_skill_lujiang_shangjia-prompt"] =
    "庐江上甲：调整手牌至装备区牌数，实际弃牌后本阶段使用【杀】次数+1",
  ["#hanjin__retinue_skill_lujiang_shangjia-discard"] =
    "庐江上甲：弃置 %arg 张手牌",
}

return skill
