local skill = fk.CreateSkill { name = "qiao__skill_wu048_2", tags = { Skill.Compulsory } }
skill:addEffect("maxcards", {
  correct_func = function(self, p)
    if not p:hasShownSkill(skill.name) then return 0 end
    local n = 0
    for _, to in ipairs(Fk:currentRoom():getPresentPlayers()) do
      if to:hasSkill("qiao__retinue_skill_danyang_qingjin", true) then n = n + #to:getCardIds("e") end
    end
    return n
  end,
})
return skill
