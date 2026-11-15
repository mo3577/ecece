import 'dart:async';
import 'dart:io';

/// UDP LAN discovery for ECE-screen PocketBase (must match Go `internal/discovery`).
const discoveryPort = 28090;
const discoveryProbe = 'ECE-SCREEN-DISCOVER';
const discoveryReplyPrefix = 'ECE-SCREEN ';

class DiscoveredServer {
  const DiscoveredServer({required this.url, required this.from});

  final String url;
  final InternetAddress from;

  @override
  String toString() => url;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

bool get discoverySupported => true;

/// Broadcast a probe and collect replies for [timeout].
Future<List<DiscoveredServer>> discoverServers({
  Duration timeout = const Duration(seconds: 3),
}) async {
  RawDatagramSocket? socket;
  final found = <String, DiscoveredServer>{};
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.readEventsEnabled = true;

    final probe = discoveryProbe.codeUnits;
    void sendTo(InternetAddress addr) {
      try {
        socket!.send(probe, addr, discoveryPort);
      } catch (_) {}
    }

    sendTo(InternetAddress('255.255.255.255'));
    for (final b in await _subnetBroadcasts()) {
      sendTo(b);
    }

    final done = Completer<void>();
    late final StreamSubscription<RawSocketEvent> sub;
    sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket!.receive();
      if (dg == null) return;
      final text = String.fromCharCodes(dg.data).trim();
      if (!text.startsWith(discoveryReplyPrefix)) return;
      final url = text.substring(discoveryReplyPrefix.length).trim();
      if (url.isEmpty) return;
      found[url] = DiscoveredServer(url: url, from: dg.address);
    });

    Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await sub.cancel();
  } catch (_) {
    // Permission / socket failure — caller shows manual fallback.
  } finally {
    socket?.close();
  }
  final list = found.values.toList()..sort((a, b) => a.url.compareTo(b.url));
  return list;
}

Future<List<InternetAddress>> _subnetBroadcasts() async {
  final out = <InternetAddress>[];
  try {
    for (final iface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    )) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length != 4) continue;
        // Assume /24 for typical campus Wi‑Fi (good enough for discovery).
        out.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
      }
    }
  } catch (_) {}
  // Fallbacks when interface listing is empty/restricted.
  if (out.isEmpty) {
    for (var i = 0; i < 8; i++) {
      out.add(InternetAddress('192.168.$i.255'));
    }
  }
  return out;
}
