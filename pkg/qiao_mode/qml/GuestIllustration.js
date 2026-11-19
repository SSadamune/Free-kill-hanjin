// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
.import Fk.Base 1.0 as Fk

function picture(name, guest) {
  return guest && name ? Fk.SkinBank.getGeneralExtraPic(name, "guest/") : undefined;
}

function inRoom(name) {
  return name && name !== "anjiang"
    && Fk.Lua.ev(`ClientInstance:isGuestPortrait(${JSON.stringify(name)})`);
}
