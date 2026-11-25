// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
.import Fk.Base 1.0 as Fk

function picture(name, guest) {
  return guest && name && name !== "anjiang" ? Fk.SkinBank.getGeneralExtraPic(name, "guest/") : undefined;
}

function roomFactions(factions) {
  const result = Array.from(factions ?? []);
  if (result.length > 2) {
    const order = ["han", "wei", "shu", "wu", "qun", "jin"];
    result.sort((a, b) => order.indexOf(a) - order.indexOf(b));
  }
  return result;
}

function enabledInRoom() {
  return Fk.Lua.ev("ClientInstance:guestIllustrationsEnabled()");
}
