/// Web / unsupported platforms: no UDP discovery.
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

Future<List<DiscoveredServer>> discoverServers({
  Duration timeout = const Duration(seconds: 3),
}) async {
  return const [];
}

bool get discoverySupported => false;
