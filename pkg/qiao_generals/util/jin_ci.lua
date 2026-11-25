-- “赐”的公开持有记录。出牌阶段的消耗权限只取决于自己的标记。
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {
  SKILL = "qiao__skill_em_jin001_banner",
  CONSUME = "qiao__skill_em_jin001_consume",
  MARK = "@[qiao_ci]",
  SPENT = "qiao_jin001_ci_spent-phase",
  CHANGED = "qiao_jin001_change_used",
}

function M.cards(holder)
  local mark = holder:getMark(M.MARK)
  if type(mark) == "table" then return table.simpleClone(mark) end
  -- 旧房间的公开标记只保存数量，实体将牌名单存在持有人身上的旗名标记里。
  return holder:getTableMark(M.SKILL)
end

function M.canSpend(player)
  return player ~= nil and not player.dead and not player:isRemoved() and player.phase == Player.Play
    and player:getMark(M.SPENT) == 0 and #M.cards(player) > 0
end

function M.canChoose(player, general)
  return type(general) == "string" and M.canSpend(player)
    and table.contains(M.cards(player), general)
end

local function positionName(player, deputy)
  local name = deputy and player.deputyGeneral or player.general
  if name == "anjiang" or name == "" then
    return player:getMark(deputy and "__heg_deputy" or "__heg_general")
  end
  return name
end

function M.actionsFor(player, name, room)
  local general = Fk.generals[name]
  if not general then return {} end
  local actions = { general.maxHp <= 3 and "maxcards" or "draw" }
  if room == nil then
    local current = Fk:currentRoom()
    local available = current and current.qiaoCiActions
    return available and available[name] or actions
  end
  if player:getMark(M.CHANGED) ~= 0 then return actions end
  for _, deputy in ipairs({ false, true }) do
    local current = positionName(player, deputy)
    local card = Fk.generals[current]
    if card and card.maxHp == general.maxHp and not Commander.isSoldier(current)
      and #Change.candidates(room, player, deputy) > 0 then
      table.insert(actions, deputy and "deputy" or "main")
    end
  end
  return actions
end

local installed = false

function M.installPlayRequest()
  if installed then return end
  installed = true
  local ask = Request.ask
  function Request:ask()
    if not self._asked and self.command == "PlayCard" and Modes.inRoom(self.room) then
      -- Send legal actions only to the player operating the request.
      for _, player in ipairs(self.players) do
        if M.canSpend(player) then
          local actions = {}
          for _, name in ipairs(M.cards(player)) do actions[name] = M.actionsFor(player, name, self.room) end
          local data = self.data[player.id] or {}
          data.qiaoCiActions = actions
          self:setData(player, data)
        end
      end
    end
    return ask(self)
  end
end

function M.validAction(player, choice, room)
  return type(choice) == "table" and M.canChoose(player, choice.general)
    and table.contains(M.actionsFor(player, choice.general, room), choice.action)
end

function M.ask(room, player, mode, prompt, groups, groupOrder)
  local reply = room:askToCustomDialog(player, {
    skill_name = M.SKILL,
    component = {
      url = "packages/qiao/pkg/qiao_mode/qml/CiDialog.qml",
      prop = {
        mode = mode, prompt = prompt, cardNames = M.cards(player),
        groups = groups or {}, groupOrder = groupOrder or {},
      },
    },
  })
  return type(reply) == "table" and reply or {}
end

function M.save(room, holder, list)
  -- 1 仅表示持旗者可查看空册。所有实体牌直接保存在各持有者的“赐”标记上。
  local value = #list > 0 and list or (holder:isAlive() and holder:hasShownSkill(M.SKILL, true) and 1 or 0)
  if holder:getMark(M.SKILL) ~= 0 then room:setPlayerMark(holder, M.SKILL, 0) end
  if holder:getMark(M.MARK) ~= value then room:setPlayerMark(holder, M.MARK, value) end
  local hasCards = #list > 0
  if hasCards ~= holder:hasSkill(M.CONSUME, true) then
    room:handleAddLoseSkills(holder, hasCards and M.CONSUME or "-" .. M.CONSUME, nil, false, true)
  end
end

function M.refreshMark(room, holder)
  M.save(room, holder, M.cards(holder))
end

function M.consume(room, holder, chosen)
  local remaining = M.cards(holder)
  if not table.removeOne(remaining, chosen) then return false end
  Discard.add(room, { chosen })
  M.save(room, holder, remaining)
  return true
end

return M
