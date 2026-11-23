-- EM(WU001) 孙权 · 缘江烽火图（持旗者本体）
-- 君主拥有的旗：烽火牌置于此私人牌堆；持旗者攻击范围 + 烽火数。
-- 第二段：每名吴势力角色自己的准备阶段，可按当前烽火数选择本回合获得的技能。
-- 第三段：持旗者受到牌的伤害后移去一张烽火，然后建立本回合下次受到的伤害-1。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"

local skill = fk.CreateSkill {
  name = P.FLAG,
  derived_piles = P.PILE,
}
skill.qiaoImplemented = true

skill:addAcquireEffect(function(self, player) Flags.refresh(player, self.name) end)
skill:addLoseEffect(function(self, player) Flags.refresh(player, self.name) end)

skill:addEffect("atkrange", {
  correct_func = function(self, from)
    if not P.flagActive(from) then return 0 end
    return P.count(from)
  end,
})

--- 逐档累积候选：1 英姿、2 好施、3 攻心、4 度势。
local CANDIDATES = {
  { id = P.YINGZI, need = 1 },
  { id = P.HAOSHI, need = 2 },
  { id = P.GONGXIN, need = 3 },
  { id = P.DUSHI, need = 4 },
}

---@param count integer
---@return string[]
local function candidates(count)
  local list = {}
  for _, candidate in ipairs(CANDIDATES) do
    if count >= candidate.need and Fk.skills[candidate.id] ~= nil then
      list[#list + 1] = candidate.id
    end
  end
  return list
end

-- 供实现与测试核对候选档位；实际候选仍按结算时的烽火数计算。
skill.qiaoTiers = CANDIDATES

--- 当前烽火数下的最多可选技能数：达到 5 时可多选一个不同技能。
---@param count integer
---@return integer
local function maxPick(count)
  return count >= 5 and 2 or 1
end

skill.qiaoMaxPick = maxPick

skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or target == nil then return false end
    if target.dead or target:isRemoved() or target.phase ~= Player.Start then return false end
    if target.kingdom ~= "wu" then return false end
    local room = target.room
    if room == nil then return false end
    local lord = P.lord(room)
    if lord == nil then return false end
    return #candidates(P.count(lord)) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = target.room
    local lord = P.lord(room)
    if lord == nil then return false end
    local count = P.count(lord)
    local list = candidates(count)
    if #list == 0 then return false end
    local limit = math.min(maxPick(count), #list)
    local chosen = room:askToChoices(target, {
      choices = list,
      min_num = 1,
      max_num = limit,
      skill_name = skill.name,
      prompt = "#qiao__skill_em_wu001_flag-grant:::" .. count .. ":" .. limit,
      cancelable = true,
      -- 确认前按技能 ID 显示正式技能说明（':'..id），候选数与多选上限不变。
      detailed = true,
    })
    if chosen == nil or #chosen == 0 then return false end
    event:setCostData(self, chosen)
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = target.room
    local chosen = event:getCostData(self) or {}
    if target.dead or target:isRemoved() then return end
    for _, skillName in ipairs(chosen) do
      P.addTempSkill(room, target, skillName)
    end
  end,
})

-- 第三段：锁定技。持旗者受到牌的伤害后，实际移去一张烽火，然后建立
-- “本回合下次受到的伤害-1”。此次伤害已经结算，不回溯减免；没有烽火时
-- 无法跳过移去而取得减伤。已建立的减伤由 P.RULE 独立执行，不依赖本旗。
skill:addEffect(fk.Damaged, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or data == nil then return false end
    if not P.flagActive(player) then return false end
    -- 伤害渠道必须是牌：不含单纯失去体力，铁索传导沿用原伤害的牌渠道。
    if data.card == nil or data.prevented or (data.damage or 0) < 1 then return false end
    return P.count(player) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if not P.removeOneFenghuo(room, player) then return end
    P.addPending(room, player)
  end,
})

Fk:loadTranslationTable {
  [P.FLAG] = "缘江烽火图",
  [":" .. P.FLAG] = "吴势力角色出牌阶段限一次，其可以将一张装备牌置于此牌上，称为“烽火”。你的攻击范围+X（X为“烽火”数）。\n吴势力角色的准备阶段，其可以根据“烽火”数于本回合获得以下一个技能：1或以上～“英姿”；2或以上～“好施”；3或以上～“攻心”；4或以上～“度势”；5或以上～可多选择一个技能。\n锁定技，当你受到牌的伤害后，你移去一张“烽火”，然后令你本回合下次受到的伤害-1。",
  [P.PILE] = "烽火",
  ["#qiao__skill_em_wu001_flag-grant"] = "缘江烽火图：烽火%arg，可选择至多%arg2项技能，本回合获得之",
  ["#qiao__skill_em_wu001_flag-remove"] = "缘江烽火图：选择一张“烽火”移去",
}

return skill
