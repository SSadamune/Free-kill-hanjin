-- 晋资源类批次的房间级事实层。
--
-- 安装后与具体武将是否已选、明置或之后失去技能无关：
--   * 记录每名角色本回合实际发动过的限定技，供腹心死士检查；
--   * 在回合结束时逐条结算泰然的记录，先回复该次失去的体力，再按该次实际
--     弃牌数摸牌。每条记录分别结算，不合并为一个总值。
local R = require "packages.qiao.pkg.qiao_generals.util.jin_resources"

local skill = fk.CreateSkill {
  name = R.RULE_SKILL,
}

skill:addEffect(fk.SkillEffect, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if data == nil or data.who == nil or data.skill == nil then return false end
    local used = data.skill
    if type(used.hasTag) == "function" and used:hasTag(Skill.Limited) then return true end
    local skel = type(used.getSkeleton) == "function" and used:getSkeleton() or nil
    return skel ~= nil and table.contains(skel.tags or {}, Skill.Limited)
  end,
  on_refresh = function(self, event, target, player, data)
    local used = data.skill
    local skel = type(used.getSkeleton) == "function" and used:getSkeleton() or nil
    local name = (skel and skel.name) or used.name
    R.recordLimitedUse(data.who.room, data.who, name)
  end,
})

-- 泰然实际失去量：取本次 LoseHp/ChangeHp 的实际负 num，而不是事后体力差。
-- HpChanged 在濒死求桃之前触发，后续插入回复不会污染该值；未防止才记录。
skill:addEffect(fk.HpChanged, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return data ~= nil and data.reason == "loseHp" and not data.prevented
      and (data.num or 0) < 0 and data.hpLostEvent ~= nil
      and data.hpLostEvent.skillName == R.TAIRAN_SKILL
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(data.who, R.TAIRAN_LOSS, -data.num)
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target ~= nil and not target.dead and #R.tairanRecords(target) > 0
  end,
  on_refresh = function(self, event, target, player)
    local room = target.room
    local records = R.tairanRecords(target)
    for _, record in ipairs(records) do
      if target.dead then break end
      if (record.hp or 0) > 0 then
        room:recover {
          who = target,
          num = record.hp,
          recoverBy = target,
          skillName = R.RULE_SKILL,
        }
      end
      if not target.dead and (record.cards or 0) > 0 then
        target:drawCards(record.cards, R.RULE_SKILL)
      end
    end
    R.clearTairanRecords(room, target)
  end,
})

return skill
