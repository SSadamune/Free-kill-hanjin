-- HAN005 何进 · 构难
--
-- 规则基线：rules/standard-generals.md 汉区 HAN005、rulebook/events/death.md、
-- rulebook/events/damage.md。锁定技：你死亡后，来源本局因普通【杀】造成或
-- 受到伤害时，此伤害+1。
--
-- 来源在死亡结算中按公共死亡数据确定；无来源则不建立印记，来源已死也照常
-- 记录（死亡通则下不再结算，但本局印记保留）。印记不随何进失技、暗置、移将
-- 或死亡清标记而消失，因此使用房间级监听器与 "-noclear" 常驻标记。
--
-- 普通【杀】按牌名识别：只认正式普通杀牌名，排除火/雷/冰杀；不以普通伤害
-- 属性代替牌名判断。造成与受到两个方向都监听。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han005_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local NORMAL_SLASH = "hanjin__slash"
local MARK = "hanjin_skill_han005_2_source-noclear"
local DELAY_SKILL_NAME = "#hanjin_skill_han005_2_delay"

local delay_skill

--- 安装/复用房间级普通杀加伤监听器；保留到整局结束。
---@param room Room
local function ensureDelaySkill(room)
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }
    skel:addEffect(fk.DamageInflicted, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        if data.damage <= 0 or data.card == nil or data.card.name ~= NORMAL_SLASH then
          return false
        end
        if data.hanjin_skill_han005_2_boosted then return false end
        local from, to = data.from, data.to
        return (from ~= nil and from:getMark(MARK) > 0)
          or (to ~= nil and to:getMark(MARK) > 0)
      end,
      on_refresh = function(self, event, target, player, data)
        data:changeDamage(1)
        data.hanjin_skill_han005_2_boosted = true
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY_SKILL_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_SKILL_NAME) then
    room:addSkill(delay_skill)
  end
end

skill:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player
      and player:hasSkill(skill.name, false, true)
      and data.killer ~= nil
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureDelaySkill(room)
    room:setPlayerMark(data.killer, MARK, 1)
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureDelaySkill(player.room)
end)

Fk:loadTranslationTable {
  ["hanjin__skill_han005_2"] = "构难",
  [":hanjin__skill_han005_2"] = "锁定技，你死亡后，来源本局因普通【杀】造成或受到伤害时，此伤害+1。",
}

return skill
