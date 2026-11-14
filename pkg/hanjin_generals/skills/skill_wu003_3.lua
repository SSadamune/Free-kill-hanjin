-- WU003 吕蒙 · 涉猎（后天技能）
--
-- 摸牌阶段，你可以改为亮出牌堆顶的五张牌，然后获得其中任意张花色各不
-- 相同的牌。
--
-- 涉猎不是吕蒙的天生技能，只能由谋断获得；本文件只实现技能本身。
-- 用阶段开始事件替换正常摸牌（data.phase_end），亮牌后由公共整理界面选牌，
-- 服务端再次按每花色至多一张复核，避免异常回复取得重复花色。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu003_3",
}
skill.hanjinImplemented = true

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player.phase == Player.Draw and not data.phase_end
  end,
  on_cost = function(self, event, target, player)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu003_3-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    data.phase_end = true
    local room = player.room
    local ids = room:getNCards(5)
    if #ids == 0 then return end
    room:moveCards({
      ids = ids,
      toArea = Card.Processing,
      moveReason = fk.ReasonJustMove,
      skillName = skill.name,
      proposer = player.id,
    })
    room:showCards(ids, player)

    local distinct, seen = {}, {}
    for _, id in ipairs(ids) do
      local suit = Fk:getCardById(id).suit
      if suit ~= Card.NoSuit and not seen[suit] then
        seen[suit] = true
        table.insert(distinct, id)
      end
    end
    -- 五张牌已在处理区并公开；使用正式整理界面（poxi_type="shelie"）
    -- 让客户端直接表达“每花色至多一张”的合法选择，而不是先选重复花色
    -- 再由服务端悄悄丢弃。服务端仍复核牌确属本次亮出的五张。
    local result = room:askToArrangeCards(player, {
      skill_name = skill.name,
      card_map = ids,
      prompt = "#hanjin__skill_wu003_3-choose:" .. #distinct,
      free_arrange = false,
      box_size = 0,
      max_limit = { #ids, #distinct },
      min_limit = { 0, 0 },
      poxi_type = "hanjin_shelie",
      default_choice = { {}, distinct },
    })
    local chosen = result and result[2] or {}
    -- 服务端复核：只保留仍在处理区、且每花色至多一张的牌。
    local paid, usedSuits, valid = {}, {}, true
    for _, id in ipairs(chosen) do
      -- 必须确属本次亮出的五张，且仍在处理区；不能只验证“还在处理区”。
      if not table.contains(ids, id) or room:getCardArea(id) ~= Card.Processing then
        valid = false
        break
      end
      local suit = Fk:getCardById(id).suit
      if suit == Card.NoSuit or usedSuits[suit] then
        valid = false
        break
      end
      usedSuits[suit] = true
      table.insert(paid, id)
    end
    -- 非法回复整项不执行，不做“悄悄丢选”后的部分获得。
    if valid and #paid > 0 then
      room:obtainCard(player, paid, true, fk.ReasonPrey, player, skill.name)
    end
    room:cleanProcessingArea(ids, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu003_3"] = "涉猎",
  ["#hanjin__skill_wu003_3-invoke"] = "涉猎：改为亮出牌堆顶五张牌，获得任意张花色各不相同的牌",
  ["#hanjin__skill_wu003_3-choose"] = "涉猎：选择获得其中任意张花色各不相同的牌",
}

return skill
