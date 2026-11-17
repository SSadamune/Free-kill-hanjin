-- 阵/势包新增翼从与统领来源的正式登记验收。
local S = require "packages.qiao.pkg.qiao_generals.util.retinue_instance_sources"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local QINGZHOU = "qiao_heg__retinue_qingzhou_jingrui"
local LUJIANG = "qiao_heg__retinue_lujiang_shangjia"
local BAZHEN = "qiao_heg__retinue_bazhenbing"

Testqiao_zhen_shi_registration = {
  setup = function() end,
  tearDown = function() end,
}

function Testqiao_zhen_shi_registration:testRetinuesAndPackages()
  local prefix = {
    [QINGZHOU] = "qiao_prefix_shi",
    [LUJIANG] = "qiao_prefix_shi",
    [BAZHEN] = "qiao_prefix_zhen",
  }
  for _, id in ipairs({ QINGZHOU, LUJIANG, BAZHEN }) do
    local general = assert(Fk.generals[id], "missing retinue general: " .. id)
    lu.assertEquals(general.package.name, "qiao_zhenshi")
    lu.assertEquals(general.prefix, prefix[id])
    lu.assertEquals(Fk:translate(general.prefix), id == BAZHEN and "阵" or "势")
    lu.assertTrue(Commander.isRetinue(id))
    lu.assertNotNil(S.skillFor(id), "missing instance-source mapping: " .. id)
  end
  lu.assertEquals(S.skillFor(QINGZHOU), "qiao__retinue_skill_qingzhou_jingrui")
  lu.assertEquals(S.skillFor(LUJIANG), "qiao__retinue_skill_lujiang_shangjia")
  lu.assertEquals(S.skillFor(BAZHEN), "qiao__retinue_skill_bazhenbing")
end

function Testqiao_zhen_shi_registration:testCommanders()
  for _, id in ipairs({
    "qiao_heg__wei023", "qiao_heg__wu023", "qiao_heg__shu012",
    "qiao_heg__jin023", "qiao_heg__em_qun010",
  }) do
    lu.assertTrue(Commander.isCommander(id), "missing commander source: " .. id)
  end
  lu.assertTrue(Commander.isSoldier(QINGZHOU))
  lu.assertTrue(Commander.isSoldier(LUJIANG))
  lu.assertTrue(Commander.isSoldier(BAZHEN))
end

function Testqiao_zhen_shi_registration:testLureTigerDependencyIsAvailable()
  local card = assert(Fk.all_card_types["qiao__lure_tiger"])
  -- 锁定上游的 lure_tiger_skill 已真实注册（非 inert 空壳）；八阵兵入口可复用。
  local skill = assert(Fk.skills[card.skill.name])
  lu.assertTrue(#skill:getSkeleton().effects > 0)
  lu.assertNotNil(Fk.skills["qiao__retinue_skill_bazhenbing"])
end

function Testqiao_zhen_shi_registration:testAllReviewedGeneralsRegistered()
  local expected={
    "qiao_heg__em_shu001",
    "qiao_heg__em_qun010",
    "qiao_heg__han014",
    "qiao_heg__han015",
    "qiao_heg__han019",
    "qiao_heg__han022",
    "qiao_heg__jin006",
    "qiao_heg__jin017",
    "qiao_heg__jin022b",
    "qiao_heg__jin023",
    "qiao_heg__qun006",
    "qiao_heg__qun011",
    "qiao_heg__qun024",
    "qiao_heg__qun081",
    "qiao_heg__shu012",
    "qiao_heg__shu018b",
    "qiao_heg__shu019",
    "qiao_heg__shu021",
    "qiao_heg__wei017",
    "qiao_heg__wei018",
    "qiao_heg__wei023",
    "qiao_heg__wei032",
    "qiao_heg__wu010",
    "qiao_heg__wu017",
    "qiao_heg__wu020",
    "qiao_heg__wu023",
  }
  lu.assertEquals(#expected,26)
  local zhen = {
    "qiao_heg__han014", "qiao_heg__han015", "qiao_heg__wei018", "qiao_heg__wei032",
    "qiao_heg__shu012", "qiao_heg__shu018b", "qiao_heg__wu017", "qiao_heg__wu020",
    "qiao_heg__qun011", "qiao_heg__qun081", "qiao_heg__jin006", "qiao_heg__jin023",
    "qiao_heg__em_shu001",
  }
  local shi = {
    "qiao_heg__han019", "qiao_heg__han022", "qiao_heg__wei017", "qiao_heg__wei023",
    "qiao_heg__shu019", "qiao_heg__shu021", "qiao_heg__wu010", "qiao_heg__wu023",
    "qiao_heg__qun006", "qiao_heg__qun024", "qiao_heg__jin017", "qiao_heg__jin022b",
    "qiao_heg__em_qun010",
  }
  lu.assertEquals(#zhen + #shi, 26)
  local prefix = {}
  for _, id in ipairs(zhen) do prefix[id] = "qiao_prefix_zhen" end
  for _, id in ipairs(shi) do prefix[id] = "qiao_prefix_shi" end
  local ClientUtil = require "ltk.client.util"
  for _,id in ipairs(expected) do
    local general=assert(Fk.generals[id],"missing reviewed general: "..id)
    local want=assert(prefix[id],"missing prefix expectation: "..id)
    lu.assertEquals(general.package.name,"qiao_zhenshi")
    lu.assertEquals(general.prefix, want)
    lu.assertEquals(Fk:translate(general.prefix), want == "qiao_prefix_zhen" and "阵" or "势")
    lu.assertEquals(ClientUtil:getGeneralData(id).prefix, want)
  end
  local Versions=require "packages.qiao.pkg.qiao_mode.rules.general_versions"
  lu.assertTrue(Fk.generals["qiao_heg__em_shu001"].hidden)
  lu.assertTrue(Fk.generals["qiao_heg__em_qun010"].hidden)
  lu.assertNotNil(Versions.lords["qiao_heg__em_shu001"])
  lu.assertNotNil(Versions.lords["qiao_heg__em_qun010"])

  local lords = {
    { lord = "qiao_heg__em_shu001", normal = "qiao_heg__shu001", display = "君刘备", name = "刘备" },
    { lord = "qiao_heg__em_qun010", normal = "qiao_heg__qun010", display = "君张角", name = "张角" },
  }
  for _, entry in ipairs(lords) do
    local text = Fk:translate(entry.lord)
    local visible = text:gsub("<[^>]+>", "")
    lu.assertEquals(Fk.generals[entry.lord].trueName, entry.name)
    lu.assertEquals(text, '<font color="#FFFF00">君</font>' .. entry.name)
    lu.assertEquals(visible, entry.display)
    lu.assertEquals(Fk:translate(entry.normal), entry.name)
  end
end

return { name = "qiao_zhen_shi_registration" }
