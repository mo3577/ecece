import 'dart:io';

/// Open a local file as a byte stream (IO platforms only).
Stream<List<int>> openFileByteStream(String path) => File(path).openRead();
