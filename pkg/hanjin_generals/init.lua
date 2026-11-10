local extension = Package:new("hanjin_generals")
extension.extensionName = "hanjin"
extension.game_modes_whitelist = { "new_heg_mode" }
Fk:addWhiteListPack("new_heg_mode", extension.name)

extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_generals/skills")

Fk:loadTranslationTable {
  ["hanjin_generals"] = "紫乔汉晋·武将",
}

-- 在确定武将设计后，在此使用 General:new(...) 并添加技能。
return extension
