import 'package:http/http.dart' as http;

/// Web: no UDP; still try localhost PocketBase for same-machine testing.
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

Future<List<DiscoveredServer>> discoverServers({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final found = <DiscoveredServer>[];
  for (final host in ['127.0.0.1', 'localhost']) {
    final url = 'http://$host:8090';
    try {
      final res = await http
          .get(Uri.parse('$url/api/health'))
          .timeout(const Duration(milliseconds: 600));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        found.add(DiscoveredServer(url: url, from: host));
      }
    } catch (_) {}
  }
  return found;
}
