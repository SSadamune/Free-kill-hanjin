local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

-- 可复用的汉晋「傲才」。正式将池目前没有傲才武将，因此本技能只登记为
-- 可授予的独立技能，不加入任何正式武将；测试房间会授予它以验证真实
-- use/response 请求。它只允许牌堆顶两张牌，并在该受限牌集内同时提供：
--   * 直接使用/打出其中合法的牌；
--   * 按当前“只能当”来源转换为杀/闪等用途。
-- 原生 askToUseRealCard 不能转化，所以这里改为“先选择具体用途，再走
-- 实体牌或虚拟牌的真实请求”。
local skill = fk.CreateSkill {
  name = "hanjin__aocai",
}

skill:addEffect("viewas", {
  pattern = ".|.|.|.|.|basic",
  anim_type = "defensive",
  prompt = "#hanjin__aocai",
  card_filter = Util.FalseFunc,
  view_as = Util.DummyFunc,
  feasible = Util.TrueFunc,
  on_use = function(self, room, cardUseEvent, _, params)
    local player = cardUseEvent.from
    local cards = room:getNCards(2)
    local isResponse = params ~= nil and params.is_response == true
    local pattern = (params and params.pattern) or Fk.currentResponsePattern or "."
    local use = O.askRestricted(room, player, {
      cards = cards,
      pattern = pattern,
      is_response = isResponse,
      extra_data = params and params.extra_data or nil,
      skill_name = skill.name,
      prompt = "#hanjin__aocai-choose",
      cancelable = true,
    })
    if use ~= nil then return use end
    return skill.name
  end,
  enabled_at_play = Util.FalseFunc,
  enabled_at_response = function(self, player)
    local room = Fk:currentRoom()
    return room ~= nil and room:getCurrent() ~= player
  end,
})

Fk:loadTranslationTable {
  ["hanjin__aocai"] = "傲才",
  [":hanjin__aocai"] = "当你于回合外需要使用或打出基本牌时，你可以观看牌堆顶的两张牌，"
    .. "若其中有需要的牌，你可以使用或打出之；受“只能当”限制的实体牌只能按该效果提供的用途使用或打出。",
  ["#hanjin__aocai"] = "傲才：观看牌堆顶的两张牌，并可以使用或打出其中你需要的基本牌",
  ["#hanjin__aocai-choose"] = "傲才：选择要使用或打出的牌及用途",
}

return skill
