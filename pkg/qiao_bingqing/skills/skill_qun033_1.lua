local skill = fk.CreateSkill { name = "qiao__skill_qun033_1" }
local H = require "packages.hegemony.util"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local function canTake(owner, cai, id)
  return table.contains(owner:getCardIds("e"), id) and not Wu.isPubliclyProtectedTreasure(owner, cai, id)
    and owner:canMoveCardInBoardTo(cai, id)
end
local MARK = "qiao_qieting_foreign-turn"
-- 锁定成为目标时的公开势力，等目标确认成功后才计入用牌历史。
skill:addEffect(fk.TargetConfirming, {
  global = true,
  can_refresh = function(self, event, target, p, data)
    return target == p and data.from == p.room.current and data.from:getMark(MARK) == 0
  end,
  on_refresh = function(self, event, target, p, data)
    data.qiao_qieting_foreign = H.compareKingdomWith(data.from, p, true)
  end,
})
skill:addEffect(fk.TargetConfirmed, {
  global = true,
  can_refresh = function(self, event, target, p, data)
    return target == p and data.qiao_qieting_foreign and data.from:getMark(MARK) == 0
      and table.find(data.use.subcardsFromInfo or {}, function(i)
        return i.from == data.from and i.fromArea == Card.PlayerHand
      end)
  end,
  on_refresh = function(self, event, target, p, data) p.room:setPlayerMark(data.from, MARK, 1) end,
})
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, p, data)
    return data.phase == Player.Finish and target ~= p and p:hasSkill(skill.name) and target:getMark(MARK) == 0
  end,
  on_use = function(self, event, target, p)
    local room = p.room
    local legal = table.filter(target:getCardIds("e"), function(id) return canTake(target, p, id) end)
    if #legal > 0 and room:askToChoice(p, { choices = { "draw1", "qiao_qieting_equip" }, skill_name = skill.name }) == "qiao_qieting_equip" then
      local id = room:askToChooseCard(p, { target = target, flag = { card_data = {{ "$Equip", legal }} }, skill_name = skill.name })
      if table.contains(legal, id) and canTake(target, p, id) then
        room:moveCardTo(id, Card.PlayerEquip, p, fk.ReasonPut, skill.name, nil, true, p)
      end
    else
      p:drawCards(1, skill.name)
    end
  end,
})
Fk:loadTranslationTable { ["qiao_qieting_equip"] = "将其装备移动到你的装备区" }
return skill
