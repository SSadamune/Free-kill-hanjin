"""Verify that the native move animation uses the latest card-face visibility."""
from pathlib import Path
import shutil
import tempfile

from check_room_records_ui import ROOT, RUNTIME, install_card_fixture
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest


WINDOW = """
import QtQuick
import QtQuick.Controls
import LunarLtk
import LunarLtk.Components
import VisibilityFixture
import "CardMoveVisibility.js" as MoveVisibility

ApplicationWindow {
  id: fixture
  visible: true
  width: 240
  height: 220
  readonly property var areas: ({ Processing: 1, DiscardPile: 2, PlayerHand: 3, PlayerEquip: 4, PlayerJudge: 5, DrawPile: 6 })
  property int perspective: 3
  property var animatedModel: null
  property var movedModels: []
  readonly property bool showingFront: card.known
  readonly property string imageName: card.cardBg.source.toString().split("/").pop()
  readonly property string lingeringImageName: lingering.cardBg.source.toString().split("/").pop()

  CardModel { id: reused; cardId: 20; picName: "qiao__slash" }
  CardModel { id: other; cardId: 22; picName: "qiao__slash"; known: false }
  CardModel { id: tableCopy; cardId: 20; picName: "qiao__slash"; known: true }
  CardModel { id: tableOriginal; cardId: 20; picName: "qiao__slash"; known: true }
  CardItem {
    id: card
    dataModel: fixture.animatedModel ?? reused
  }
  CardItem {
    id: lingering
    x: 112
    dataModel: tableCopy
  }

  PageBase {
    id: room
    property alias dataModel: nativeRoom
    property var tablePile: null
    Component.onCompleted: {
      /* QIAO_MOVE_CALLBACK */
    }

    QtObject {
      id: nativeRoom
      property var processing: []
      property var discard: []
      property var dashboard: ({ handcards: [] })
      signal cardsMoved(var move, var models)
      onCardsMoved: (move, models) => {
        fixture.movedModels = models;
        fixture.animatedModel = models[0];
      }
      Component.onCompleted: {
        /* NATIVE_MOVE_CALLBACK */
      }
      /* NATIVE_MOVE_CARDS */
    }
  }

  function dispatch(data, pile = null) {
    room.tablePile = pile;
    room.handleCommand(null, "QiaoMoveCards", data);
  }

  function moveExisting(fromKnown, nextKnown, recipient) {
    reused.known = fromKnown;
    nativeRoom.processing = [reused];
    dispatch({ "20": nextKnown, merged: [
      { fromArea: areas.Processing, toArea: areas.PlayerHand, to: recipient, ids: [20] },
    ] });
    return animatedModel === reused;
  }

  function moveHiddenFromAnotherHand() {
    Ltk.cards[21] = { name: "qiao__slash", suit: "spade", number: 9 };
    dispatch({ "21": false, merged: [
      { fromArea: areas.PlayerHand, from: 2, toArea: areas.Processing, ids: [21] },
    ] });
    return animatedModel.cardId;
  }

  function moveMixedOldFaces() {
    reused.known = true;
    nativeRoom.processing = [reused, other];
    // Both are "未知牌" in the third seat's log for this move.
    dispatch({ "20": false, "22": false, merged: [
      { fromArea: areas.Processing, toArea: areas.PlayerHand, to: 2, ids: [20, 22] },
    ] });
    return movedModels.length;
  }

  function showMovedCard(index) {
    animatedModel = movedModels[index];
  }

  function scryFromDeck() {
    Ltk.cards[20] = { name: "qiao__slash", suit: "spade", number: 5 };
    Ltk.cards[22] = { name: "qiao__slash", suit: "spade", number: 7 };
    dispatch({ "20": false, "22": false, merged: [
      { fromArea: areas.DrawPile, toArea: areas.Processing, ids: [20, 22] },
    ] }, {
      cards: [lingering], cardMap: new Map([[tableCopy, [lingering, tableOriginal]]]),
    });
  }

  function transferFromAnotherHand() {
    lingering.dataModel = tableCopy;
    tableCopy.known = true;
    tableOriginal.known = true;
    dispatch({ "20": false, "22": true, merged: [
      { fromArea: areas.PlayerHand, from: 1, toArea: areas.PlayerHand, to: 2, ids: [20, 22] },
    ] }, { cards: [lingering], cardMap: new Map([[tableCopy, [lingering, tableOriginal]]]) });
  }

  function restoreOldTableModel() {
    lingering.dataModel = tableOriginal;
  }

  function scryReturnToDeck() {
    dispatch({ "20": false, "22": false, merged: [
      { fromArea: areas.Processing, toArea: areas.DrawPile, ids: [20, 22] },
    ] }, { cards: [lingering] });
  }
}
"""


def room_fixture(directory):
    core = RUNTIME / "packages/freekill-core"
    module = directory / "VisibilityFixture"
    module.mkdir()
    shutil.copyfile(core / "Fk/Widgets/PageBase.qml", module / "PageBase.qml")
    (module / "qmldir").write_text("module VisibilityFixture\nPageBase 1.0 PageBase.qml\n", encoding="utf-8")

    native = (core / "LunarLtk/Models/RoomModel.qml").read_text(encoding="utf-8")
    qiao = (ROOT / "pkg/qiao_mode/qml/QiaoRoom.qml").read_text(encoding="utf-8")
    callback_start = native.index("    roomPage.addCallback(Command.MoveCards,")
    callback_end = native.index("    roomPage.addCallback(Command.SetCardFootnote,", callback_start)
    native_callback = native[callback_start:callback_end].replace("roomPage.", "room.")
    qiao_callback = next(line for line in qiao.splitlines() if "=> CardMoveVisibility.moveCards(" in line)
    start = native.index("  function moveCards(move, data) {")
    end = native.index("  function vanishDiscard(", start)
    return (WINDOW.replace("/* NATIVE_MOVE_CALLBACK */", native_callback)
            .replace("/* QIAO_MOVE_CALLBACK */", qiao_callback)
            .replace("/* NATIVE_MOVE_CARDS */", native[start:end])
            .replace("Command.MoveCards", '"MoveCards"')
            .replace("CardMoveVisibility.moveCards", "MoveVisibility.moveCards")
            .replace("Ltk.Card", "fixture.areas")
            .replace("Cpp.self.id", "fixture.perspective"))


def run():
    app = QGuiApplication([])
    engine = QQmlApplicationEngine()
    warnings = []
    engine.warnings.connect(lambda entries: warnings.extend(entry.toString() for entry in entries))
    with tempfile.TemporaryDirectory(dir=ROOT / ".dev") as directory:
        install_card_fixture(engine, Path(directory))
        source = room_fixture(Path(directory))
        url = QUrl.fromLocalFile(str(ROOT / "pkg/qiao_mode/qml/MoveVisibilityCheck.qml"))
        engine.loadData(source.encode(), url)
        assert engine.rootObjects(), warnings
        fixture = engine.rootObjects()[0]

        def assert_face(known, image):
            QTest.qWait(60)
            assert fixture.property("showingFront") == known
            assert fixture.property("imageName") == image, warnings

        assert fixture.moveExisting(True, False, 2), "The native mover must reuse the old model"
        assert_face(False, "card-back.png")
        assert fixture.moveExisting(False, True, 3)
        assert_face(True, "qiao__slash.png")
        assert fixture.moveHiddenFromAnotherHand() == 21
        assert_face(False, "card-back.png")
        assert fixture.moveMixedOldFaces() == 2
        for index in range(2):
            fixture.showMovedCard(index)
            assert_face(False, "card-back.png")
        fixture.scryFromDeck()
        assert_face(False, "card-back.png")
        assert fixture.property("lingeringImageName") == "card-back.png"
        fixture.restoreOldTableModel()
        assert fixture.property("lingeringImageName") == "card-back.png"
        fixture.scryReturnToDeck()
        for index in range(2):
            fixture.showMovedCard(index)
            assert_face(False, "card-back.png")
        fixture.transferFromAnotherHand()
        assert_face(False, "card-back.png")
        assert fixture.property("lingeringImageName") == "card-back.png"
        fixture.showMovedCard(1)
        assert_face(True, "qiao__slash.png")
        assert not warnings, warnings
        fixture.close()
        app.processEvents()
    print("PASS Han-Jin move callback: hidden swaps, private scry and mixed hand transfers show the correct faces")


if __name__ == "__main__":
    run()
