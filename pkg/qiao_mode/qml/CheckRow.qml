pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Fk.Widgets as W

W.ActionRow {
  id: root
  property alias value: root.checked

  suffixComponent: CheckBox {
    checked: root.checked
    onToggled: root.checked = checked
  }

  onClicked: root.checked = !root.checked
}
