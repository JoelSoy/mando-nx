// Wi-Fi controller protocol, version 1 (docs/protocol.md; the host side is nxnative's dm/host/remote_proto.h and its parts). One JSON object per UDP datagram, at most
// 512 bytes. The phone sends hello until it gets a welcome, then its whole state 50-60 times a second; the host acks, and sends rumble and the game's feed.
export 'protocol/decode.dart';
export 'protocol/encode.dart';
export 'protocol/host_messages.dart';
export 'protocol/pad_state.dart';
export 'protocol/validate.dart';
