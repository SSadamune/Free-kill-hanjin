// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

const closingQuote = { "【": "】", "〖": "〗", "“": "”", "「": "」", "『": "』", "《": "》" };
const skillContext = /(?:发动|习得|失效的|技能[为是]?)$/;
const possessionContext = /(?:拥有|获得|失去)$/;
const markContext = /(?:[枚个]|消耗|补充|移去|弃去|获得|持有)$/;
const cardContext = /(?:张|使用|打出|当作|响应|转化为|牌名[为是]?)$/;

function escapeText(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function createCatalog(raw) {
  const names = new Map();
  const skills = new Map();
  for (const entry of [...raw.skills, ...(raw.generals ?? [])]) {
    skills.set(entry.id, entry);
    for (const name of [entry.title, ...(entry.aliases ?? [])]) {
      if (!names.has(name)) names.set(name, []);
      names.get(name).push(entry);
    }
  }
  const variants = raw.variants ?? {};
  const words = Array.from(new Set([...names.keys(), ...Object.keys(raw.cards), ...Object.keys(variants)]));
  words.sort((a, b) => b.length - a.length);
  const pattern = words.map(word => word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
  return { names, skills, cards: raw.cards, variants, omissions: raw.omissions ?? {},
    pattern: pattern ? new RegExp(pattern, "g") : null };
}

function target(catalog, name, source, before, after) {
  const opener = before.slice(-1);
  const quoted = !!closingQuote[opener] && closingQuote[opener] === after[0];
  const left = quoted ? before.slice(0, -1) : before;
  const right = quoted ? after.slice(1) : after;
  const isSkill = /^技能/.test(right) || skillContext.test(left);
  const isCard = cardContext.test(left) || /^牌(?:名|面)/.test(right);
  const entries = catalog.names.get(name) ?? [];
  const card = Object.prototype.hasOwnProperty.call(catalog.cards, name) || !!catalog.variants[name];

  if (card && (isCard || (quoted && opener === "【" && !isSkill))) return "qiao-card";

  const matched = entries.filter(entry => (
    quoted || entry.bare || isSkill || possessionContext.test(left)
    || (entry.term && (markContext.test(left) || /^标记/.test(right)))
  ));
  const exact = matched.filter(entry => entry.title === name);
  const candidates = exact.length > 0 ? exact : matched;
  if (candidates.length > 0) {
    const pages = candidates.filter(entry => entry.page);
    const tips = candidates.filter(entry => !entry.page);
    if (pages.length > 0 && (!isSkill || tips.length === 0)) {
      if (pages.some(entry => entry.id === source)) return null;
      return "qiao-page";
    }
    if (tips.some(entry => entry.id === source)) return null;
    return "qiao-tip";
  }
  if (card && quoted && entries.length === 0) return "qiao-card";
  return null;
}

function renderLinks(catalog, description, source, theme) {
  if (!catalog.pattern) return description;
  // Process visible text only. Existing Qt rich text and anchors retain their
  // formatting, including descriptions that already support native links.
  const tags = /(<\/?(?:a|b|br|em|font|i|img|li|ol|p|span|strong|style|sub|sup|u|ul)\b[^>]*>)/ig;
  let protectedText = false;
  return description.split(tags).map((part, index) => {
    if (index % 2) {
      if (/^<\/?(?:a|style)\b/i.test(part)) protectedText = part[1] !== "/";
      return part;
    }
    if (protectedText) return part;
    return part.replace(catalog.pattern, (name, offset) => {
      const before = part.slice(0, offset);
      const kind = target(catalog, name, source, before, part.slice(offset + name.length));
      if (!kind) return name;
      let targetName = name;
      if (kind === "qiao-card") {
        const qualifier = before.match(/(应变|合纵)[【〖]?$/)?.[1];
        const variant = (qualifier ? name + "·" + qualifier : name).replace(/·合$/, "·合纵");
        if (catalog.variants[variant]) targetName = variant;
      }
      const href = kind + ":" + encodeURIComponent(targetName) + ":" + encodeURIComponent(source);
      const color = kind === "qiao-page" ? theme.page : theme.tip;
      return '<a href="' + href + '" style="color:' + color + ';">' + escapeText(name) + "</a>";
    }).replace(/\r?\n/g, "<br/>");
  }).join("");
}

function render(catalog, description, source, theme) {
  const omission = catalog.omissions[source];
  const target = omission && catalog.skills.get(omission.target);
  if (target && lookup(catalog, target.title, source, false).some(entry => entry.id === target.id)) {
    const shortened = omission.fragments.reduce((text, fragment) => text.replace(fragment, ""), description);
    const rendered = renderLinks(catalog, shortened, source, theme);
    const href = "qiao-tip:" + encodeURIComponent(target.title) + ":" + encodeURIComponent(source);
    if (rendered.includes('href="' + href + '"')) return rendered;
  }
  return renderLinks(catalog, description, source, theme);
}

function lookup(catalog, name, source, page) {
  const eligible = (catalog.names.get(name) ?? []).filter(entry => entry.id !== source && !!entry.page === page);
  const exact = eligible.filter(entry => entry.title === name);
  const candidates = exact.length > 0 ? exact : eligible;
  const related = Array.from(catalog.skills.get(source)?.related ?? []);
  const linked = candidates.filter(entry => related.includes(entry.id));
  const results = linked.length > 0 ? linked : candidates;
  return results.filter((entry, index) => (
    !entry.description || results.findIndex(other => other.description === entry.description) === index
  ));
}

function entriesText(catalog, theme, entries) {
  return entries.map(entry => {
    const title = entry.variant && entries.length > 1 ? entry.variant + " " + entry.title : entry.title;
    const heading = title ? "<b>" + escapeText(title) + "</b><br/>" : "";
    return heading + render(catalog, entry.description, entry.id, theme);
  }).join("<br/><br/>");
}

function findChild(item, predicate) {
  for (const child of item?.children ?? []) {
    if (predicate(child)) return child;
    const match = findChild(child, predicate);
    if (match) return match;
  }
  return null;
}

function playerText(catalog, theme, visibleSkills, tr, describe) {
  const names = new Set(visibleSkills.map(skill => skill.orig_name));
  const rows = [];
  for (const skill of visibleSkills) {
    const invalid = skill.name.endsWith(tr("skill_invalidity"));
    const color = invalid ? "grey" : "#9FD49C";
    const heading = '<font color="' + color + '" size="5"><b>' + escapeText(skill.name) + "</b></font> ";
    const body = render(catalog, skill.description, skill.orig_name, theme);
    rows.push(heading + (invalid ? '<font color="grey">' + body + "</font>" : body));
    for (const related of skill.related_skills) {
      if (names.has(related)) continue;
      rows.push('<font color="pink"><b>' + escapeText(tr(related)) + "</b> "
        + render(catalog, describe(related), related, theme) + "</font>");
    }
  }
  return rows.join("<br/>");
}

function generalText(catalog, theme, groups, tr, showSummary) {
  const rows = [];
  for (const { name, detail, title, factions } of groups) {
    if (showSummary) {
      const hegemony = name.startsWith("hs__") || name.startsWith("ld__") || name.includes("heg__");
      let hp = detail.hp + "/" + detail.maxHp;
      if (detail.hp === detail.maxHp) {
        hp = detail.hp;
        if (hegemony) {
          hp = detail.mainMaxHp || detail.deputyMaxHp
            ? (detail.hp + detail.mainMaxHp) / 2 + "/" + (detail.hp + detail.deputyMaxHp) / 2
            : detail.hp / 2;
        }
      }
      const kingdoms = (factions?.length ? factions : [detail.kingdom]).map(tr).join("／");
      rows.push(escapeText(kingdoms + " " + (title ?? tr(name)) + " " + hp));
    }
    if (detail.headnote) rows.push('<font color="lightslategrey">' + tr(detail.headnote) + "</font>");
    if (detail.companions.length > 0) {
      rows.push('<font color="slategrey"><b>' + escapeText(tr("Companions")) + "</b> "
        + Array.from(detail.companions, value => escapeText(tr(value))).join(" ") + "</font>");
    }
    for (const skill of detail.skill) {
      if (!showSummary && skill.name.startsWith("#")) continue;
      const body = "<b>" + escapeText(tr(skill.name)) + "</b> "
        + render(catalog, skill.description, skill.name, theme);
      rows.push(skill.is_related_skill ? '<font color="#BD8BDE">' + body + "</font>" : body);
    }
    if (detail.endnote) rows.push('<font color="lightslategrey">' + tr(detail.endnote) + "</font>");
    if (showSummary) rows.push("");
  }
  return rows.join("<br/>");
}

function replaceText(component, viewport, original, properties) {
  if (!viewport || !original) return;
  const replacement = component.createObject(viewport.contentItem, Object.assign({
    viewport,
    width: Qt.binding(() => original.width),
    x: original.x,
    textColor: original.color,
  }, properties));
  if (!replacement) return;
  original.visible = false;
  viewport.contentHeight = Qt.binding(() => replacement.height);
}
