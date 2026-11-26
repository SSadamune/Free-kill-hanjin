// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

function moveCards(roomModel, data, areas, selfId, tablePile) {
  for (const move of data.merged) {
    // Native RoomModel only applies the notification's visibility when it
    // creates a model. An existing model also drives the moving CardItem.
    let from;
    switch (move.fromArea) {
    case areas.Processing: from = roomModel.processing; break;
    case areas.DiscardPile: from = roomModel.discard; break;
    case areas.PlayerHand:
      if (move.from === selfId) from = roomModel.dashboard.handcards;
      break;
    case areas.PlayerEquip: from = roomModel.getPhoto(move.from)?.equips; break;
    case areas.PlayerJudge: from = roomModel.getPhoto(move.from)?.delayedTricks; break;
    }
    if (from) {
      for (const id of move.ids) {
        const card = from.find(model => model.uniqueId === id);
        if (card) card.known = !!data[id.toString()];
      }
    }
    roomModel.moveCards(move, data);
    // The table may still render a detached copy of the old model while
    // waiting to fade previously displayed cards.
    const hidden = new Set(move.ids.filter(id => data[id.toString()] === false));
    if (hidden.size) {
      for (const card of tablePile?.cards ?? []) {
        const model = card.dataModel;
        if (!hidden.has(model?.cardId)) continue;
        model.known = false;
        const original = tablePile.cardMap?.get(model)?.[1];
        if (original) original.known = false;
      }
    }
  }
}
