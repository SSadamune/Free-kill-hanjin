// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
.import Fk.Base 1.0 as Fk

function picture(name, guest) {
  return guest && name ? Fk.SkinBank.getGeneralExtraPic(name, "guest/") : undefined;
}

function enabledInRoom() {
  return Fk.Lua.ev("ClientInstance:guestIllustrationsEnabled()");
}
