// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Fk
import LunarLtk.Pages
import "GuestIllustration.js" as GuestIllustration

Room {
  id: room
  property var mountDistanceLabels: ({})

  function refreshMountDistances() {
    const labels = Lua.ev("json.encode(ClientInstance:mountDistanceLabels())");
    mountDistanceLabels = JSON.parse(labels ?? "{}");
  }

  // 横置、势力、移出游戏与技能有效性都可以在坐骑未移动时变化。
  Timer {
    interval: 200
    repeat: true
    running: room.visible && room.photoModel.count > 0
    onTriggered: room.refreshMountDistances()
  }

  Component {
    id: mountRow
    DualMountRow {}
  }

  Component {
    id: guestPortrait
    Image {
      required property Item portrait
      required property Item photo
      required property bool deputy
      anchors.fill: portrait
      fillMode: Image.PreserveAspectCrop
      source: {
        const name = deputy ? photo.deputyGeneral : photo.general;
        if (!name || name === "anjiang") return "";
        return GuestIllustration.picture(name, GuestIllustration.enabledInRoom()) ?? "";
      }
      visible: status === Image.Ready
    }
  }

  function bindGuestPortraits(photo) {
    if (!photo) return;
    // Reuse PhotoBase's masked art layer so names, dimming and other UI stay above it.
    const art = photo.children.find(child => child.maskSource === photo.photoMask)?.source;
    if (!art || art.children.some(child => child.objectName === "qiaoGuestPortrait")) return;
    const portraits = art.children.filter(child => child instanceof Image);
    if (portraits.length !== 2) return;
    portraits.forEach((portrait, index) => guestPortrait.createObject(art, {
      objectName: "qiaoGuestPortrait", portrait, photo, deputy: index === 1,
    }));
  }

  function bindPhotoExtras() {
    for (let i = 0; i < photoModel.count; ++i) {
      const photo = photoModel.get(i).modelData.photoItem;
      bindGuestPortraits(photo);
      const area = photo?.areasSealed;
      if (!area || area.children.some(child => child.objectName === "qiaoDualMountRow"))
        continue;
      const defensive = area.items[area.subtypes.indexOf("defensive_ride")];
      const offensive = area.items[area.subtypes.indexOf("offensive_ride")];
      if (defensive && offensive) {
        mountRow.createObject(area, {
          defensiveItem: defensive,
          offensiveItem: offensive,
          distanceLabels: Qt.binding(() => room.mountDistanceLabels),
          isDualMount: name => Lua.evaluate(`Fk.packages.qiao_cards.qiao.isDualMount(${JSON.stringify(name)})`),
        });
      }
    }
    refreshMountDistances();
  }

  Connections {
    target: room.photoModel
    function onModelDataChanged() { Qt.callLater(room.bindPhotoExtras); }
  }

  Connections {
    target: room.dataModel
    function onCardsMoved() { Qt.callLater(room.bindPhotoExtras); }
  }

  Component.onCompleted: Qt.callLater(bindPhotoExtras)
}
