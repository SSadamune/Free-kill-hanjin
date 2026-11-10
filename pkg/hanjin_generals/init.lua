local extension = Package:new("hanjin_generals")
extension.extensionName = "hanjin"

extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_generals/skills")

Fk:loadTranslationTable {
  ["hanjin_generals"] = "紫乔汉晋·武将",
}

-- 在确定武将设计后，在此使用 General:new(...) 并添加技能。
return extension
