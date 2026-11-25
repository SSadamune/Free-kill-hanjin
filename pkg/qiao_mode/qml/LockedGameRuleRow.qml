pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Fk
import Fk.Pages.Lobby as Lobby
import Fk.Widgets as W

W.ActionRow {
  id: root

  property string value
  required property var model
  required property string modeName
  required property var roomSizes
  property Item lobby: null
  property Item playerCountRow: null
  readonly property bool locksPlayerCount: lobby?.config?.gameMode === modeName

  suffixComponent: ComboBox {
    id: choices

    model: root.model
    currentIndex: root.model.indexOf(root.value)
    displayText: Lua.tr(currentText)
    onActivated: index => root.value = root.model[index]

    background: Rectangle {
      color: "transparent"
      implicitHeight: root.height - 16
      implicitWidth: 120
    }

    delegate: ItemDelegate {
      required property int index
      required property string modelData

      width: choices.width
      text: Lua.tr(modelData)
      highlighted: index === choices.highlightedIndex
    }
  }

  onClicked: root.suffixLoader.item.popup.open()

  function findChild(item, matches) {
    if (matches(item)) return item;
    for (const child of item.children) {
      const found = findChild(child, matches);
      if (found) return found;
    }
    return null;
  }

  Component.onCompleted: {
    // The stock lobby uses its room settings page's spin row to send capacity.
    for (let item = parent; item; item = item.parent) {
      if (!(item instanceof Lobby.CreateRoom)) continue;
      lobby = item;
      const generalSettings = findChild(item, child => child instanceof Lobby.RoomGeneralSettings);
      if (generalSettings) {
        playerCountRow = findChild(generalSettings, child =>
          child instanceof W.SpinRow && child.title === Lua.tr("Player num"));
      }
      break;
    }
    Qt.callLater(updateRoomSettings);
  }

  Binding {
    target: root.playerCountRow
    property: "enabled"
    when: root.playerCountRow !== null && root.locksPlayerCount
    value: false
  }

  Connections {
    target: Config
    function onCurSchemeChanged() { Qt.callLater(root.updateRoomSettings); }
  }

  function updateRoomSettings() {
    if (locksPlayerCount && playerCountRow) {
      // CreateRoom expands these same per-package lists when it sends the request.
      lobby.config.qiaoLockedBanScheme = Config.curScheme;
      lobby.config.qiaoLockedHiddenPacks = Config.serverHiddenPacks;
      playerCountRow.value = roomSizes[value] ?? roomSizes[model[0]];
      lobby.updateFeasible();
    }
  }

  // The stock settings page saves the rule before the spin row checks capacity.
  onValueChanged: Qt.callLater(updateRoomSettings)
}
