-- HAN004 张让 · 滔乱
--
-- 规则依据：rules/generals/han004-zhangrang.md（同一回合无论发动几次，回合结束只
-- 进行一次结算；候选取本回合以此法使用牌指定过的角色的并集）。
--
-- 统一使用 ViewAs：正常出牌阶段和合法的「使用」窗口（含使用闪/无懈）都走
-- 同一入口；不接纯打出。view_as 在仍暗置时记录来源武将；room:useSkill 在
-- before_use 之前按技能名自动明置该武将，before_use 只消费来源并核对，不再
-- 要求其暗置。明置后技能被武将替换也不影响本次使用。
--
-- 记录与回合末结算是首次发动时建立的房间级延迟效果，不依赖张让当前技能。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han004_1",
}
skill.hanjinImplemented = true

local Reuse = require "packages.hanjin.pkg.hanjin_cards.data.reuse"

local ACT_MARK = "hanjin__skill_han004_1-activations-turn"
local TARGET_MARK = "hanjin__skill_han004_1-targets-turn"
local SETTLING_TAG = "hanjin_skill_han004_1_settling"
local DELAY_SKILL_NAME = "#hanjin_skill_han004_1_delay"

local delay_skill
local settle

--- 已实装、非衍生、非空壳的基本牌/普通锦囊牌名。
---@return string[]
local function availableNames()
  local names = {}
  for name, card in pairs(Fk.all_card_types) do
    local rec = Reuse.cards[name]
    if name:startsWith("hanjin__") and rec ~= nil and rec.status == "reused"
      and not card.is_derived and not card.shell
      and (card.type == Card.TypeBasic
        or (card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick)) then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

--- 承载本技能的暗置武将（客户端只读自身可见武将/标记）；nil 不可发动。
---@param player ServerPlayer | ClientPlayer
---@return boolean?
local function hiddenSource(player)
  local function hasGeneral(general)
    return general ~= nil and general ~= "anjiang" and Fk.generals[general] ~= nil
      and table.contains(Fk.generals[general]:getSkillNameList(true), skill.name)
  end
  if player.general == "anjiang" and hasGeneral(player:getMark("__heg_general"))
    and not player:prohibitReveal(false) then
    return false
  end
  if player.deputyGeneral == "anjiang" and hasGeneral(player:getMark("__heg_deputy"))
    and not player:prohibitReveal(true) then
    return true
  end
end

---@param player ServerPlayer
local function ensureDelaySkill(player)
  local room = player.room
  if room == nil then return end
  if delay_skill == nil then delay_skill = Fk.skills[DELAY_SKILL_NAME] end
  if delay_skill == nil then
    local skel = fk.CreateSkill { name = DELAY_SKILL_NAME }

    -- 只有实际指定目标的牌才记录；按 data.from（唯一 owner）处理，不按
    -- 候选玩家重复变更。
    skel:addEffect(fk.TargetSpecified, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        local from = data.from
        return from ~= nil and data.card ~= nil and data.to ~= nil
          and table.contains(data.card.skillNames or {}, skill.name)
      end,
      on_refresh = function(self, event, target, player, data)
        local from = data.from
        from.room:addTableMarkIfNeed(from, TARGET_MARK, data.to.id)
      end,
    })

    -- 每个回合结束扫描一次所有仍持有发动记录的玩家；用房间 tag 防止
    -- 对每名候选重复触发。每名角色至多结算一次（发动次数不决定轮数），
    -- 结算前清空待结算记录，同一次回合结束不会重复收牌。结算必须自动
    -- 发生，用 refresh 而非需要询问发动的 trigger；房间级同名触发器也无需
    -- 再登记 Fk.skills。
    skel:addEffect(fk.TurnEnd, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        local room = player.room
        if target ~= player or room == nil or room:getTag(SETTLING_TAG) then return false end
        for _, p in ipairs(room.players) do
          if p:getMark(ACT_MARK) > 0 then return true end
        end
        return false
      end,
      on_refresh = function(self, event, target, player, data)
        local room = player.room
        room:setTag(SETTLING_TAG, true)
        for _, p in ipairs(room.players) do
          -- 同一角色同一回合至多结算一次：发动次数只用于判断是否有待结算记录，
          -- 不决定结算轮数；结算前清空记录，避免同一次回合结束重复收牌。
          if p:getMark(ACT_MARK) > 0 then
            room:setPlayerMark(p, ACT_MARK, 0)
            if not p.dead then settle(room, p) end
          end
        end
        room:setTag(SETTLING_TAG, false)
      end,
    })
    delay_skill = skel:createSkill()
    Fk.skills[DELAY_SKILL_NAME] = delay_skill
  end
  if not room:hasSkill(DELAY_SKILL_NAME) then
    room:addSkill(delay_skill)
  end
end

--- 一次回合末结算。
---@param room Room
---@param player ServerPlayer
settle = function(room, player)
  local ids = player:getTableMark(TARGET_MARK)
  local targets = {}
  for _, p in ipairs(room.alive_players) do
    if p ~= player and table.contains(ids, p.id) then table.insert(targets, p) end
  end
  room:sortByAction(targets)
  if #targets == 0 then return end

  local chosen = room:askToChoosePlayers(player, {
    min_num = 0,
    max_num = math.min(3, #targets),
    targets = targets,
    skill_name = skill.name,
    prompt = "#hanjin__skill_han004_1-choose",
    cancelable = true,
  })
  if chosen == nil or #chosen == 0 then return end
  room:sortByAction(chosen)

  local red, black = 0, 0
  for _, to in ipairs(chosen) do
    if to:isAlive() and not to:isRemoved() and #to:getCardIds(Player.Hand) > 0 then
      local cards = room:askToCards(to, {
        min_num = 1,
        max_num = 1,
        include_equip = false,
        skill_name = skill.name,
        prompt = "#hanjin__skill_han004_1-give",
        cancelable = false,
      })
      local id = cards and cards[1]
      if id ~= nil and table.contains(to:getCardIds(Player.Hand), id) then
        room:showCards({ id }, to)
        local card = room:filterCard(id, to) or Fk:getCardById(id, true)
        if card.color == Card.Red then red = red + 1
        elseif card.color == Card.Black then black = black + 1 end
        room:moveCardTo({ id }, Card.PlayerHand, player, fk.ReasonGive,
          skill.name, nil, true, to)
      end
    end
  end

  if red <= black then return end
  local choices = {}
  if player.general ~= "anjiang" then table.insert(choices, "m") end
  if player.deputyGeneral ~= "anjiang" then table.insert(choices, "d") end
  if #choices == 0 then return end
  local choice = choices[1]
  if #choices > 1 then
    choice = room:askToChoice(player, {
      choices = choices,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han004_1-hide",
      cancelable = false,
    })
  end
  if choice == "d" then player:hideGeneral(true) else player:hideGeneral(false) end
end

-- ViewAs 统一入口：选牌名（客户端公开项），无实体子牌，正常目标规则。
skill:addEffect("viewas", {
  pattern = ".",
  interaction = function(self, player)
    local names = availableNames()
    local choices = player:getViewAsCardNames(self.name, names)
    if #choices == 0 then return nil end
    return UI.CardNameBox { choices = choices, all_choices = names }
  end,
  -- 客户端纯函数：只读自身可见武将/标记，不访问 player.room；来源编号写进
  -- 本次克隆牌的字段，供服务端 before_use 消费。
  view_as = function(self, player, cards)
    local name = self.interaction and self.interaction.data
    if name == nil or not table.contains(availableNames(), name) then return nil end
    local source = hiddenSource(player)
    if source == nil then return nil end
    local card = Fk:cloneCard(name)
    card.hanjinTaoluanSource = source and 2 or 1
    card.skillName = skill.name
    return card
  end,
  enabled_at_play = function(self, player)
    return hiddenSource(player) ~= nil
  end,
  -- ReqUseCard（使用窗口，包括回合外使用【闪】/【无懈】）以 false 调用；
  -- 纯打出请求（ReqResponseCard）以 true 调用，必须返回 false。
  enabled_at_response = function(self, player, cardResponsing)
    return not cardResponsing and hiddenSource(player) ~= nil
  end,
  -- 服务端消费 view_as 写入的来源编号。room:useSkill 在本回调之前已经按
  -- 技能名自动明置来源武将，所以这里不能再要求其仍暗置；但必须核对编号对应
  -- 的武将确实已明置且承载本技能，不能无条件放行伪造的亮将发动。
  before_use = function(self, player, use)
    local source = use.card and use.card.hanjinTaoluanSource
    if source ~= 1 and source ~= 2 then return skill.name end
    local generalName = source == 1 and player.general or player.deputyGeneral
    if generalName == nil or generalName == "anjiang" then return skill.name end
    local general = Fk.generals[generalName]
    if general == nil
      or not table.contains(general:getSkillNameList(true), skill.name) then
      return skill.name
    end
    ensureDelaySkill(player)
  end,
})

skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and data.card ~= nil
      and (data.card.skillName == skill.name
        or table.contains(data.card.skillNames or {}, skill.name))
  end,
  on_refresh = function(self, event, target, player, data)
    -- 来源明置已由 room:useSkill 在本技能实际发动时完成（before_use 之前），
    -- 这里只确保延迟记录存在并计一次发动。
    ensureDelaySkill(player)
    player.room:addPlayerMark(player, ACT_MARK, 1)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han004_1"] = "滔乱",
  [":hanjin__skill_han004_1"] = "当你需要使用任意一种基本或普通锦囊牌时，你可以明置此武将牌并视为使用之。当前回合结束时，你选择本回合以此法使用牌指定过的至多三名其他角色，其依次展示并交给你一张手牌，若红色牌多于黑色，你暗置一张武将牌。",
  ["#hanjin__skill_han004_1-choose"] = "滔乱：选择至多三名本回合以此法指定过的角色",
  ["#hanjin__skill_han004_1-give"] = "滔乱：展示并交给张让一张手牌",
  ["#hanjin__skill_han004_1-hide"] = "滔乱：红色牌多于黑色，暗置一张武将牌",
}

return skill
