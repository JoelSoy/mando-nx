// What the host sends: the session's own messages (welcome, ack, reject, kick, bye), game rumble, and the game's feed (info, roster, race, the game's keyboard,
// icon pieces).
import 'dart:typed_data';

sealed class HostMessage {
  const HostMessage();
}

class Welcome extends HostMessage {
  const Welcome(this.sid, this.player, this.timeoutMs);
  final String sid;
  final int player, timeoutMs;
}

class Reject extends HostMessage {
  const Reject(this.reason);
  final String reason; // code, full, busy, version
}

class Ack extends HostMessage {
  const Ack(this.sid, this.seq, this.player, this.ms);
  final String sid;
  final int seq, player;
  final int? ms;
}

class Kick extends HostMessage {
  const Kick(this.reason);
  final String reason; // session, timeout
}

class HostBye extends HostMessage {
  const HostBye(this.reason);
  final String reason; // left, host
}

class Rumble extends HostMessage {
  const Rumble(this.sid, this.seq, this.intensity, this.sharpness, this.ms);
  final String sid;
  final int seq, ms;
  final double intensity, sharpness;
}

/// What the game makes of this phone's player: own (the game reads it as a player of its own), p1 (a one-player screen: it feeds player 1, with the others),
/// off (the game takes fewer players now: not used), pause (the game window on the Mac is not in front: released).
enum PlayerUse { own, p1, off, pause }

/// info: the game's name and icon (CRC and size; null when it has none), what it makes of this player, whether it is reading its controller now, the players it takes
/// (seats, 1-8) and which players have a controller (taken: bit n, player n + 1). Sent when it changes and renewed every 2 s; seq orders them.
class GameInfo extends HostMessage {
  const GameInfo(
    this.sid,
    this.seq,
    this.player,
    this.game,
    this.use,
    this.seats,
    this.taken, {
    this.reading = false,
    this.iconHash,
    this.iconSize = 0,
  });
  final String sid, game;
  final int seq, player, seats, taken, iconSize;
  final PlayerUse use;
  final bool reading;
  final String? iconHash;
  bool holds(int p) => taken >> (p - 1) & 1 == 1;
}

/// roster: who holds each player (player number → "keyboard", a controller's name, a phone's name); seq orders them.
class Roster extends HostMessage {
  const Roster(this.sid, this.seq, this.names);
  final String sid;
  final int seq;
  final Map<int, String> names;
}

/// race: the course this player races on, as the game files it ("Gu_WaterPark"; empty in the menus or when unknown) and, when known, their place and lap (both from 1)
/// and coins, their character and kart, their items. Only from a game build the host knows; seq orders them.
class RaceInfo extends HostMessage {
  const RaceInfo(
    this.sid,
    this.seq,
    this.course, {
    this.place,
    this.lap,
    this.coins,
    this.driver,
    this.body,
    this.tires,
    this.glider,
    this.item,
    this.item2,
  });
  final String sid, course;
  final int seq;
  final int? place, lap, coins;
  final int? driver, body, tires, glider; // the game's ids for the character and the kart's parts (games/mk8_*.dart)
  final int? item, item2; // the two item slots: the game's item id, -1 empty; null when not known
  bool get racing => place != null;
  bool get hasKart => driver != null;
}

/// kbd: the game's keyboard waits for text (title, initial text, at most max characters), or (done) the request id is over: answered or closed on the Mac.
class KeyboardRequest extends HostMessage {
  const KeyboardRequest(
    this.sid,
    this.id, {
    this.done = false,
    this.max = 32,
    this.title = '',
    this.initial = '',
  });
  final String sid, title, initial;
  final int id, max;
  final bool done;
}

/// iconpart: bytes of the game's icon from off; hash says which icon.
class IconPart extends HostMessage {
  const IconPart(this.sid, this.hash, this.off, this.bytes);
  final String sid, hash;
  final int off;
  final Uint8List bytes;
}
