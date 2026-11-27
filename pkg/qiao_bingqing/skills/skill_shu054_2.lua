local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_shu054_2" }
local mark = "qiao_kangrui_first-turn"
skill:addEffect(fk.HpChanged, {
  global = true,
  can_refresh = function(self, event, target, p, data)
    return p == target and p == p.room.current and data.num < 0 and (data.reason == "damage" or data.reason == "loseHp") and p:getMark(mark) == 0
  end,
  on_refresh = function(self, event, target, p) p.room:setPlayerMark(p, mark, event.id) end,
  can_trigger = function(self, event, target, p) return target and target:getMark(mark) == event.id and S.present(target) and p:hasSkill(skill.name) end,
  on_cost = function(self, event, target, p)
    local choice = p.room:askToChoice(p, { choices = { "recover", "qiao_kangrui_damage", "Cancel" }, skill_name = skill.name })
    event:setCostData(self, { choice = choice })
    return choice ~= "Cancel"
  end,
  on_use = function(self, event, target, p)
    if event:getCostData(self).choice == "recover" then
      p.room:recover { who = target, num = 1, recoverBy = p, skillName = skill.name }
    else
      p.room:addPlayerMark(target, "qiao_kangrui_damage-turn")
    end
  end,
})
skill:addEffect(fk.DamageCaused, {
  global = true,
  can_refresh = function(self, event, target, p) return p == target and p:getMark("qiao_kangrui_damage-turn") > 0 end,
  on_refresh = function(self, event, target, p, data)
    data:changeDamage(p:getMark("qiao_kangrui_damage-turn"))
    p.room:setPlayerMark(p, "qiao_kangrui_damage-turn", 0)
    p.room:setPlayerMark(p, "qiao_kangrui_limit-turn", 1)
  end,
})
skill:addEffect("maxcards", { fixed_func = function(self, p) if p:getMark("qiao_kangrui_limit-turn") > 0 then return 0 end end })
Fk:loadTranslationTable { qiao_kangrui_damage = "下次造成伤害时伤害+1，本回合手牌上限初值改为0" }
return skill
