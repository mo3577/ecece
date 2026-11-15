import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'upload_file_stub.dart' if (dart.library.io) 'upload_file_io.dart';

/// Max bytes we will load entirely into RAM (web / path-less picks).
const maxInMemoryUploadBytes = 40 * 1024 * 1024;

typedef UploadProgress = void Function(int sent, int total);

MediaType mediaTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return MediaType('image', 'jpeg');
  }
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.gif')) return MediaType('image', 'gif');
  if (lower.endsWith('.mp4')) return MediaType('video', 'mp4');
  if (lower.endsWith('.mov')) return MediaType('video', 'quicktime');
  if (lower.endsWith('.webm')) return MediaType('video', 'webm');
  if (lower.endsWith('.mkv')) return MediaType('video', 'x-matroska');
  return MediaType('application', 'octet-stream');
}

bool isVideoFileName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.avi');
}

bool isImageFileName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif');
}

String formatBytes(int? n) {
  if (n == null || n <= 0) return '';
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
}

enum PickKind { any, image, media }

/// Pick a file without forcing whole-file RAM load on mobile (avoids OOM on video).
Future<PlatformFile?> pickUploadFile({PickKind kind = PickKind.any}) async {
  FileType type;
  List<String>? exts;
  switch (kind) {
    case PickKind.image:
      type = FileType.image;
      exts = null;
    case PickKind.media:
      type = FileType.custom;
      exts = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'mov', 'webm', 'mkv', 'm4v'];
    case PickKind.any:
      type = FileType.any;
      exts = null;
  }

  // Web: bytes. Mobile: prefer path + optional readStream for progress.
  final res = await FilePicker.pickFiles(
    type: type,
    allowedExtensions: exts,
    withData: kIsWeb,
    withReadStream: !kIsWeb,
  );
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  if (kIsWeb && (f.bytes == null || f.bytes!.isEmpty)) {
    throw 'تعذر قراءة الملف في المتصفح';
  }
  if (!kIsWeb &&
      (f.path == null || f.path!.isEmpty) &&
      f.readStream == null &&
      f.bytes == null) {
    throw 'تعذر الوصول لمسار الملف';
  }
  if (kIsWeb && f.size > maxInMemoryUploadBytes) {
    throw 'الملف أكبر من ${(maxInMemoryUploadBytes / (1024 * 1024)).round()} MB للرفع من المتصفح';
  }
  return f;
}

Stream<List<int>> _progressStream(
  Stream<List<int>> source,
  int total,
  UploadProgress? onProgress,
) async* {
  var sent = 0;
  await for (final chunk in source) {
    sent += chunk.length;
    if (onProgress != null && total > 0) {
      onProgress(sent > total ? total : sent, total);
    }
    yield chunk;
  }
  if (onProgress != null && total > 0) {
    onProgress(total, total);
  }
}

Stream<List<int>> _chunkedBytes(List<int> bytes, {int chunkSize = 64 * 1024}) async* {
  for (var i = 0; i < bytes.length; i += chunkSize) {
    final end = i + chunkSize > bytes.length ? bytes.length : i + chunkSize;
    yield bytes.sublist(i, end);
  }
}

/// Build a multipart part; [onProgress] reports bytes of this file as they are sent.
Future<http.MultipartFile> toMultipartFile(
  String field,
  PlatformFile file, {
  UploadProgress? onProgress,
}) async {
  final contentType = mediaTypeForName(file.name);
  final total = file.size > 0 ? file.size : (file.bytes?.length ?? 0);

  final readStream = file.readStream;
  if (readStream != null && total > 0) {
    final tracked = _progressStream(readStream, total, onProgress);
    return http.MultipartFile(
      field,
      http.ByteStream(tracked),
      total,
      filename: file.name,
      contentType: contentType,
    );
  }

  final path = file.path;
  if (!kIsWeb && path != null && path.isNotEmpty && total > 0) {
    final tracked = _progressStream(openFileByteStream(path), total, onProgress);
    return http.MultipartFile(
      field,
      http.ByteStream(tracked),
      total,
      filename: file.name,
      contentType: contentType,
    );
  }

  final bytes = file.bytes;
  if (bytes == null) {
    throw 'لا توجد بيانات للملف «${file.name}»';
  }
  final len = bytes.length;
  final tracked = _progressStream(_chunkedBytes(bytes), len, onProgress);
  return http.MultipartFile(
    field,
    http.ByteStream(tracked),
    len,
    filename: file.name,
    contentType: contentType,
  );
}

/// Progress callback for one file within a multi-file upload totaling [totalBytes].
UploadProgress uploadProgressAt({
  required int byteOffset,
  required int totalBytes,
  required void Function(double fraction) onFraction,
}) {
  return (sent, _) {
    if (totalBytes <= 0) {
      onFraction(0);
      return;
    }
    onFraction(((byteOffset + sent) / totalBytes).clamp(0.0, 1.0));
  };
}
