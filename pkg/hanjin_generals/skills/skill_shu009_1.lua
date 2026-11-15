-- SHU009 魏延 · 狂骨
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU009。
-- 当你对距离1以内的角色造成伤害后，你可以选择摸一张牌或回复1点体力；
-- 若选择项与本回合上次不同，你本回合使用【杀】的次数+1。
-- 每次伤害事件只发动一次（不按伤害点数逐点触发）。首次发动没有“上次”，
-- 不增加次数；次数加成写入回合标记，由公共回合效果读取，失去狂骨后仍保留。
local skill = fk.CreateSkill {
  name = "hanjin__skill_shu009_1",
}
skill.hanjinImplemented = true

local LAST = "hanjin__skill_shu009_1-last-turn"
-- utility 扩展定义的公共“使用杀次数+1”标记；本地兜底同值，避免依赖枚举
-- 是否已在当前加载顺序中赋值。
local SLASH_RESIDUE = MarkEnum.SlashResidue or "__slash_residue"
local ELIGIBLE = "hanjin__skill_shu009_1_eligible"
local OPT_DRAW = "#hanjin__skill_shu009_1-draw"
local OPT_RECOVER = "#hanjin__skill_shu009_1-recover"

-- 伤害前快照距离：濒死/死亡会改变结算后的座次距离，按造成伤害时的实际距离
-- 记录本次是否满足，DamageFinished 不再以死者或结算后距离排除。
skill:addEffect(fk.DamageCaused, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data.from == player and data.to ~= nil
      and player:distanceTo(data.to) <= 1
  end,
  on_refresh = function(self, event, target, player, data)
    data[ELIGIBLE] = true
  end,
})

skill:addEffect(fk.DamageFinished, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or data.from ~= player or data.to == nil then return false end
    return data[ELIGIBLE] == true
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu009_1-invoke",
    }) then
      return false
    end
    local choices = { OPT_DRAW }
    if player.hp < player.maxHp then table.insert(choices, OPT_RECOVER) end
    local choice = room:askToChoice(player, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu009_1-choice",
      cancelable = false,
    })
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = (event:getCostData(self) or {}).choice
    if choice == nil or player.dead then return end
    local last = player:getMark(LAST)
    if last ~= 0 and last ~= choice then
      room:addPlayerMark(player, SLASH_RESIDUE .. "-turn", 1)
    end
    room:setPlayerMark(player, LAST, choice)
    if choice == OPT_RECOVER then
      if player.hp < player.maxHp then
        room:recover {
          who = player,
          num = 1,
          recoverBy = player,
          skillName = skill.name,
        }
      end
    else
      player:drawCards(1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_shu009_1"] = "狂骨",
  [":hanjin__skill_shu009_1"] = "当你对距离1以内的角色造成伤害后，你可以选择摸一张牌或回复1点体力，若选择项与本回合上次不同，你本回合使用【杀】的次数+1。",
  ["#hanjin__skill_shu009_1-invoke"] = "狂骨：摸一张牌或回复1点体力",
  ["#hanjin__skill_shu009_1-choice"] = "狂骨：选择摸牌或回复",
  [OPT_DRAW] = "摸一张牌",
  [OPT_RECOVER] = "回复1点体力",
}

return skill
