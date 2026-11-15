import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// UDP LAN discovery for ECE-screen PocketBase (must match Go `internal/discovery`).
const discoveryPort = 28090;
const discoveryProbe = 'ECE-SCREEN-DISCOVER';
const discoveryReplyPrefix = 'ECE-SCREEN ';

class DiscoveredServer {
  const DiscoveredServer({required this.url, required this.from});

  final String url;
  final String from;

  @override
  String toString() => url;

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

bool get discoverySupported => true;

/// Find ECE-screen on the LAN: UDP beacon + localhost HTTP health check.
Future<List<DiscoveredServer>> discoverServers({
  Duration timeout = const Duration(seconds: 4),
}) async {
  final found = <String, DiscoveredServer>{};

  // Same-machine / emulator: PocketBase health on loopback.
  for (final host in ['127.0.0.1', 'localhost']) {
    final url = 'http://$host:8090';
    if (await _pocketBaseUp(url)) {
      found[url] = DiscoveredServer(url: url, from: host);
    }
  }

  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    socket.readEventsEnabled = true;

    final probe = utf8.encode(discoveryProbe);
    void sendTo(InternetAddress addr) {
      try {
        socket!.send(probe, addr, discoveryPort);
      } catch (_) {}
    }

    final targets = <InternetAddress>[
      InternetAddress('255.255.255.255'),
      ...await _subnetBroadcasts(),
    ];

    late final StreamSubscription<RawSocketEvent> sub;
    sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket!.receive();
      if (dg == null) return;
      final text = utf8.decode(dg.data, allowMalformed: true).trim();
      if (!text.startsWith(discoveryReplyPrefix)) return;
      final url = text.substring(discoveryReplyPrefix.length).trim();
      if (url.isEmpty) return;
      found[url] = DiscoveredServer(url: url, from: dg.address.address);
    });

    // Retransmit — many APs drop the first broadcast.
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final t in targets) {
        sendTo(t);
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    await sub.cancel();
  } catch (_) {
    // Permission / socket failure — still return any localhost hits.
  } finally {
    socket?.close();
  }

  final list = found.values.toList()..sort((a, b) => a.url.compareTo(b.url));
  return list;
}

Future<bool> _pocketBaseUp(String base) async {
  try {
    final res = await http
        .get(Uri.parse('$base/api/health'))
        .timeout(const Duration(milliseconds: 600));
    return res.statusCode >= 200 && res.statusCode < 300;
  } catch (_) {
    return false;
  }
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
        out.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
      }
    }
  } catch (_) {}
  if (out.isEmpty) {
    for (var i = 0; i < 8; i++) {
      out.add(InternetAddress('192.168.$i.255'));
    }
    out.add(InternetAddress('10.0.0.255'));
  }
  return out;
}
