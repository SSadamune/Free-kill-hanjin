// SPDX-License-Identifier: GPL-3.0-or-later
import "../../../../utility/qml/models" as Utility

Utility.ChooseGeneralsAndChoiceModel {
  function initialize() { syncOkEnabled(); }

  // A previously selected card may have scrolled out of the GridView.
  onRequestGeneralUnselect: name => toggleGeneral(name, false)
}
