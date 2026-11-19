local skill = fk.CreateSkill {
  name = "qiao__black_chain_skill",
  attached_equip = "qiao__black_chain",
}

Fk:loadTranslationTable {
  ["qiao__black_chain_skill"] = "乌铁锁链",
}

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card and data.card.trueName == "slash" and not data.to.chained
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.to:setChainState(true)
  end,
})

return skill
