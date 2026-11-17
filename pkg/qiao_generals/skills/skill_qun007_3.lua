-- QUN007 贾诩 · 帷幕
--
-- 锁定技，你成为黑色锦囊牌的目标时，取消之。
-- 只在成为目标的确认时点取消该目标，不把技能改成“不能被选为目标”，也不
-- 额外拦截黑色延时锦囊移入判定区：未被取消的黑色延时锦囊仍按普通牌移动。
-- 取消目标沿用锁定上游 weimu 的 TargetConfirming + cancelTarget；其额外的
-- BeforeCardsMove 段不采用。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun007_3",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

skill:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil
      and data.card.type == Card.TypeTrick
      and data.card.color == Card.Black
  end,
  -- 锁定技，不询问是否发动。
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data:cancelTarget(player)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun007_3"] = "帷幕",
  [":qiao__skill_qun007_3"] = "锁定技，你成为黑色锦囊牌的目标时，取消之。",
}

return skill
