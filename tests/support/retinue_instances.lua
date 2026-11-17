-- 翼从同名实例的测试专用内容（不得发布）。
--
-- 生产目录只保留通用实例模块 pkg/hanjin_generals/util/retinue_instances.lua；
-- 这里的探测技能与外部来源标记只在 tests/retinue_instances.lua 加载时注册，
-- 使用明显的 hanjin_test__ 前缀，不进入正式包、将池或开局流程。
--
-- 探测效果故意保持简单可观察：受到1点伤害后，每份同名实例各自可选发动一次
-- 并摸一张牌。它验证的是实例机制（独立询问、独立计次、移除一份保留另一份），
-- 不是任何正式翼从的效果。
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local M = {}

M.SKILL = "hanjin_test__retinue_instance_probe"
M.EXTERNAL_SOURCE = "hanjin_test__retinue_instance_external_source"
-- 多效果代表技能：主技能 + 关联 targetmod。用于验证“外部来源仍在时，
-- 移除实例来源不得连带删除关联效果”，观察点是【杀】次数加成。
M.MULTI = "hanjin_test__retinue_instance_multi"
M.MULTI_EXTERNAL = "hanjin_test__retinue_instance_multi_external"

local function register(name, build)
  if Fk.skills[name] ~= nil then return Fk.skills[name] end
  local skeleton = fk.CreateSkill { name = name }
  if build ~= nil then build(skeleton) end
  local skill = skeleton:createSkill()
  Fk:addSkill(skill)
  return skill
end

-- 用于验证“外部独立来源”不被实例撤销误删的无效果来源技能。
register(M.EXTERNAL_SOURCE)
register(M.MULTI_EXTERNAL)

-- 主效果 + 关联 targetmod 的多效果代表技能。targetmod 以自身 effect 名判断关系
-- 是否仍在，因此可观察到“关联效果被连带删除”，而不只是读 derivative_skills 表。
register(M.MULTI, function(skill)
  skill:addEffect("active", {
    can_use = function() return false end,
    on_use = function() end,
  })
  skill:addEffect("targetmod", {
    residue_func = function(self, player, card_skill, scope, card)
      if player:hasSkill(self.name) and scope == Player.HistoryPhase
        and card ~= nil and card.trueName == "slash" then
        return 1
      end
    end,
  })
end)

register(M.SKILL, function(skill)
  skill:addEffect(fk.Damaged, {
    anim_type = "support",
    can_trigger = function(self, event, target, player, data)
      return target == player and player:hasSkill(M.SKILL)
        and R.countForSkill(player, M.SKILL) > 0
    end,
    -- 单次事件内按实例逐份 doCost；每份单独询问，拒绝一份仍会询问下一份。
    on_trigger = function(self, event, target, player, data)
      return R.triggerEach(self, event, target, player, data)
    end,
    on_use = function(self, event, target, player, data)
      local instance = R.currentForEvent(self, event)
      if instance == nil or R.get(player, instance.id) == nil then return end
      R.recordUse(instance)
      player:drawCards(1, M.SKILL)
    end,
  })
end)

Fk:loadTranslationTable {
  [M.SKILL] = "测试翼从实例",
  [":" .. M.SKILL] = "测试专用：受到1点伤害后，每份同名实例各可发动一次并摸一张牌。",
}

M.install = function() return Fk.skills[M.SKILL] end

M.install()
return M
