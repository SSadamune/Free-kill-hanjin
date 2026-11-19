-- 晋资源类批次的公共事实层：泰然逐次记录与腹心死士的限定技历史。
--
-- 这些事实由模式级 jin_resources_rule 在正式流程中记录，不能依赖技能持有者
-- 在后续时点仍拥有该技能。标记使用 `-turn` 后缀，由引擎在回合结束时清理。
local M = {}

M.TAIRAN_RECORD = "qiao_jin002_1_records-turn"
M.TAIRAN_SKILL = "qiao__skill_jin002_1"
M.TAIRAN_LOSS = "qiao_jin002_1_actual_loss"
M.LIMITED_USED = "qiao_jin_resources_limited_used-turn"
M.RULE_SKILL = "qiao__jin_resources_rule"

--- 技能是否具有真实的“限定技”标签。
---@param skillName string
---@return boolean
local function isLimitedSkill(skillName)
  local skill = Fk.skills[skillName]
  if skill == nil then return false end
  if type(skill.hasTag) == "function" and skill:hasTag(Skill.Limited) then return true end
  local skel = type(skill.getSkeleton) == "function" and skill:getSkeleton() or nil
  return skel ~= nil and table.contains(skel.tags or {}, Skill.Limited)
end

--- 当前仍在角色技能列表中、整局尚未发动过的限定技。
---@param player Player
---@return boolean
function M.hasUnusedLimitedSkill(player)
  if player == nil or player.dead then return false end
  for _, name in ipairs(player:getSkillNameList()) do
    if isLimitedSkill(name) and player:usedSkillTimes(name, Player.HistoryGame) == 0 then
      return true
    end
  end
  return false
end

--- 本回合实际发动过的限定技名（含之后失去的技能）。
---@param player Player
---@return string[]
function M.limitedUsedThisTurn(player)
  if player == nil then return {} end
  return player:getTableMark(M.LIMITED_USED)
end

--- 记录一次限定技发动；同名去重，不写入统领“限一”记录。
---@param room Room
---@param player Player
---@param skillName string
function M.recordLimitedUse(room, player, skillName)
  if room == nil or player == nil or skillName == nil or skillName == "" then return end
  local used = player:getTableMark(M.LIMITED_USED)
  if table.contains(used, skillName) then return end
  room:addTableMark(player, M.LIMITED_USED, skillName)
end

--- 取走本次泰然实际失去的体力数（由房间规则在 HpChanged 记录）。
---@param player ServerPlayer
---@return integer
function M.takeTairanLoss(player)
  if player == nil then return 0 end
  local n = player:getMark(M.TAIRAN_LOSS)
  if n > 0 then player.room:setPlayerMark(player, M.TAIRAN_LOSS, 0) end
  return n or 0
end

--- 追加一次泰然发动记录；每次出牌阶段开始分别保留。
---@param room Room
---@param player Player
---@param record { hp: integer, cards: integer }
function M.addTairanRecord(room, player, record)
  if room == nil or player == nil or record == nil then return end
  room:addTableMark(player, M.TAIRAN_RECORD, {
    hp = math.max(0, record.hp or 0),
    cards = math.max(0, record.cards or 0),
  })
end

---@param player Player
---@return { hp: integer, cards: integer }[]
function M.tairanRecords(player)
  if player == nil then return {} end
  return player:getTableMark(M.TAIRAN_RECORD)
end

---@param room Room
---@param player Player
function M.clearTairanRecords(room, player)
  if room == nil or player == nil then return end
  room:setPlayerMark(player, M.TAIRAN_RECORD, {})
end

return M
