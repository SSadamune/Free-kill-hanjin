local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__retinue_skill_suwei_zhongjun" }
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local function used(p)
  return #p.room.logic:getEventsOfScope(GameEvent.UseCard, math.huge, function(e) return e.data.from == p end, Player.HistoryTurn)
end
skill:addEffect(fk.TurnEnd, {
  on_trigger = S.each,
  can_trigger = function(self, event, target, p)
    return p:hasSkill(skill.name) and S.present(target) and not S.allies(p, target) and used(p) > 0
  end,
  on_use = function(self, event, target, p)
    local colors = {}
    for i = 1, used(p) do
      if not S.present(p) then return end
      local judge = { who = p, reason = skill.name }
      p.room:judge(judge)
      if judge.card.color ~= Card.NoColor then table.insertIfNeed(colors, judge.card.color) end
    end
    for _ = 1, #colors do
      if S.present(p) and S.present(target) then C.useVirtualCard(p.room, p, "qiao__slash", {}, { target }, skill.name, true, nil, C.bypassDistance()) end
    end
  end,
})
return skill
