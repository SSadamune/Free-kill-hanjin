-- JIN022B 牵弘 · 烈戎
-- 出牌阶段限一次（不是阶段开始）：失去1点体力，按此时已损体力选择
-- “本回合攻击范围至多+X”，然后视为使用火【杀】并附加〈助战→伤害+1〉。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin022b_1",
}
skill.qiaoImplemented = true

local function ensureRangeRule(room)
  local rule = Fk.skills[U.RANGE_SKILL]
  if rule ~= nil and not room:hasSkill(U.RANGE_SKILL) then room:addSkill(rule) end
end

skill:addEffect("active", {
  prompt = "#qiao__skill_jin022b_1-prompt",
  target_num = 0,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player.hp > 0 and not player.dead
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead or player.hp <= 0 then return end

    room:loseHp(player, 1, skill.name)
    if player.dead then return end

    local lost = math.max(0, player.maxHp - player.hp)
    if lost < 1 then return end
    local choices = {}
    for value = 1, lost do table.insert(choices, tostring(value)) end
    local picked
    if #choices == 1 then
      picked = choices[1]
    else
      picked = room:askToChoice(player, {
        choices = choices,
        skill_name = skill.name,
        prompt = "#qiao__skill_jin022b_1-range:::" .. lost,
        cancelable = false,
      })
    end
    local add = tonumber(picked) or 0
    ensureRangeRule(room)
    room:setPlayerMark(player, U.RANGE, add)

    local use = C.selectVirtualCard(room, player, {
      name = "qiao__fire__slash",
      skill_name = skill.name,
      prompt = "#qiao__skill_jin022b_1-use",
      cancelable = true,
    })
    if use == nil then return end
    A.addEntry(use, {
      id = "qiao__skill_jin022b_1_support",
      condition = "zhuzhan",
      effect = "damage",
    })
    C.useCard(room, player, use, C.default())
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin022b_1"] = "烈戎",
  ["#qiao__skill_jin022b_1-prompt"] = "烈戎：失去1点体力，按结算时已损失的体力增加攻击范围，视为使用火【杀】",
  ["#qiao__skill_jin022b_1-range"] = "烈戎：选择本回合攻击范围的增加量，至多 %arg",
  ["#qiao__skill_jin022b_1-use"] = "烈戎：视为使用火【杀】",
}

return skill
