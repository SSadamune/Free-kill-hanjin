-- QUN021 袁术 · 伪帝
-- 锁定技，若场上没有【玉玺】，你视为装备着【玉玺】；
-- 当你成为【知己知彼】的目标后，你展示所有手牌。
local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun021_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

-- 1. 视为装备【玉玺】：场上公开装备区无【玉玺】时，视为唯一大势力（不产生实体牌、不占宝物栏）。
skill:addEffect("bigkingdom", {
  fixed_func = function(self, player)
    local kingdom = H.getKingdom(player)
    return Quan.virtualJadeSealActive(player)
      and kingdom ~= nil and kingdom ~= "" and kingdom ~= "unknown"
  end,
})

-- 2. 视为装备【玉玺】：摸牌阶段摸牌数 +1。
skill:addEffect(fk.DrawNCards, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player)
    return target == player and Quan.virtualJadeSealActive(player, player.room)
      and H.isBigKingdomPlayer(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

-- 3. 视为装备【玉玺】：出牌阶段开始时视为使用【知己知彼】。
skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player)
    return target == player and player.phase == Player.Play
      and Quan.virtualJadeSealActive(player, player.room)
      and H.isBigKingdomPlayer(player)
  end,
  on_cost = function(self, event, target, player)
    local room = player.room
    local card = Fk:cloneCard("qiao__known_both")
    local policy = C.default()
    local targets = C.candidates(room, player, card, policy)
    local maxNum = card.skill:getMaxTargetNum(player, card)
    local minNum = card.skill:getMinTargetNum(player)
    if #targets == 0 or maxNum == 0 then return false end
    local to = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = math.min(minNum, #targets),
      max_num = math.min(maxNum, #targets),
      prompt = "#jade_seal-ask",
      skill_name = skill.name,
      cancelable = false,
    })
    if to and #to > 0 then
      event:setCostData(self, { tos = to, policy = policy })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player)
    local cost = event:getCostData(self)
    if cost == nil then return end
    C.useVirtualCard(player.room, player, "qiao__known_both", nil, cost.tos,
      skill.name, nil, nil, cost.policy)
  end,
})

-- 4. 负面效果：成为【知己知彼】的目标后展示所有手牌（不依赖场上是否有玉玺）。
skill:addEffect(fk.TargetConfirmed, {
  anim_type = "negative",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "known_both"
      and not player:isKongcheng()
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    if not player:isKongcheng() then
      player:showCards(player:getCardIds(Player.Hand))
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "伪帝",
  [":" .. skill.name] = "锁定技，若场上没有【玉玺】，你视为装备着【玉玺】；当你成为【知己知彼】的目标后，你展示所有手牌。",
}

return skill
