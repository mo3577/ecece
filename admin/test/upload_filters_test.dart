import 'package:ece_admin/filters.dart';
import 'package:ece_admin/upload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:ece_admin/collections.dart';

void main() {
  test('media type helpers', () {
    expect(isVideoFileName('clip.MP4'), isTrue);
    expect(isImageFileName('a.PNG'), isTrue);
    expect(mediaTypeForName('x.mov').mimeType, 'video/quicktime');
    expect(formatBytes(1500), contains('KB'));
  });

  test('upload progress offsets across files', () {
    final fracs = <double>[];
    final a = uploadProgressAt(byteOffset: 0, totalBytes: 100, onFraction: fracs.add);
    final b = uploadProgressAt(byteOffset: 40, totalBytes: 100, onFraction: fracs.add);
    a(20, 40);
    b(30, 60);
    expect(fracs[0], closeTo(0.2, 0.001));
    expect(fracs[1], closeTo(0.7, 0.001));
  });

  test('schedule filters include day and exam', () {
    final rows = [
      RecordModel({'id': '1', 'day': 'الاحد', 'stage': 1, 'is_exam': true, 'subject': 'A'}),
      RecordModel({'id': '2', 'day': 'الاثنين', 'stage': 2, 'is_exam': false, 'subject': 'B'}),
    ];
    final opts = filtersFor(collections.firstWhere((c) => c.id == 'Schedules'), rows);
    expect(opts.any((e) => e.id == 'exam'), isTrue);
    expect(opts.any((e) => e.id == 'day:الاحد'), isTrue);
    expect(opts.any((e) => e.id == 'stage:2'), isTrue);
  });

  test('media filters classify main vs side', () {
    final opts = filtersFor(collections.firstWhere((c) => c.id == 'Media'), const []);
    final main = opts.firstWhere((e) => e.id == 'main');
    final side = opts.firstWhere((e) => e.id == 'side');
    final video = RecordModel({'id': 'v', 'file': 'a.mp4', 'main_only': false});
    final sideImg = RecordModel({'id': 'i', 'file': 'b.jpg', 'main_only': false});
    expect(main.matches(video), isTrue);
    expect(side.matches(sideImg), isTrue);
    expect(side.matches(video), isFalse);
  });
}
