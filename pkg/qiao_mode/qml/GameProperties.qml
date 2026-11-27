import QtQuick
import Fk
import Fk.Pages.Lobby as Lobby
import Fk.Widgets as W

W.PreferenceGroup {
  id: root

  property bool selectionSettings: false
  objectName: selectionSettings ? "qiaoSelectionSettings" : "qiaoGameProperties"

  function findGameSettings(item) {
    if (item instanceof Lobby.LuaSettingsPage && item.isBoardgame) return item;
    for (const child of item.children) {
      const page = findGameSettings(child);
      if (page) return page;
    }
    return null;
  }

  Component.onCompleted: {
    if (!root.selectionSettings) return;

    let modePage = root.parent;
    while (modePage && !(modePage instanceof Lobby.LuaSettingsPage)) modePage = modePage.parent;
    let lobby = modePage?.parent;
    while (lobby && !(lobby instanceof Lobby.CreateRoom)) lobby = lobby.parent;
    if (!lobby) return;

    // Move the complete group visually. The native mode page still owns its
    // settings keys, control updates, persistence and lifetime.
    const gamePage = findGameSettings(lobby);
    const properties = gamePage?.dynamicChildObject.find(group => group?.objectName === "qiaoGameProperties");
    if (!properties) return;
    root.parent = properties;

    Qt.callLater(() => {
      if (!modePage?.dynamicChildObject?.includes(root)) return;
      const saved = Db.getModeSettings(modePage.configName);
      const current = modePage.config._mode;
      if (Object.keys(current).some(key => saved[key] === undefined)) {
        // An existing profile can lack a default that the native builder
        // added to the in-memory config but has yet to save to the database.
        Db.saveModeSettings(modePage.configName, current);
      }
    });
  }
}
