import 'package:pocketbase/pocketbase.dart';

import 'collections.dart';
import 'upload.dart';

class RecordFilterOption {
  const RecordFilterOption({
    required this.id,
    required this.label,
    required this.matches,
  });

  final String id;
  final String label;
  final bool Function(RecordModel r) matches;
}

/// Built-in + data-driven filter chips for a collection.
List<RecordFilterOption> filtersFor(CollectionDef def, List<RecordModel> rows) {
  switch (def.id) {
    case 'Schedules':
      return _scheduleFilters(rows);
    case 'Sections':
      return _sectionFilters(rows);
    case 'Media':
      return _mediaFilters();
    case 'Notices':
      return [
        RecordFilterOption(
          id: 'with_image',
          label: 'مع صورة',
          matches: (r) => r.getStringValue('image').isNotEmpty,
        ),
        RecordFilterOption(
          id: 'no_image',
          label: 'بدون صورة',
          matches: (r) => r.getStringValue('image').isEmpty,
        ),
      ];
    case 'Professors':
      return [
        RecordFilterOption(
          id: 'with_photo',
          label: 'مع صورة',
          matches: (r) => r.getStringValue('image').isNotEmpty,
        ),
        RecordFilterOption(
          id: 'no_photo',
          label: 'بدون صورة',
          matches: (r) => r.getStringValue('image').isEmpty,
        ),
      ];
    default:
      return const [];
  }
}

List<RecordFilterOption> _scheduleFilters(List<RecordModel> rows) {
  final out = <RecordFilterOption>[
    RecordFilterOption(
      id: 'exam',
      label: 'امتحانات',
      matches: (r) => r.getBoolValue('is_exam'),
    ),
    RecordFilterOption(
      id: 'normal',
      label: 'محاضرات',
      matches: (r) => !r.getBoolValue('is_exam'),
    ),
  ];

  final days = <String>{};
  final stages = <int>{};
  for (final r in rows) {
    final d = r.getStringValue('day');
    if (d.isNotEmpty) days.add(d);
    final stage = r.get<dynamic>('stage');
    if (stage is num) stages.add(stage.toInt());
  }
  for (final d in arabicDays.where(days.contains)) {
    out.add(RecordFilterOption(
      id: 'day:$d',
      label: d,
      matches: (r) => r.getStringValue('day') == d,
    ));
  }
  final sortedStages = stages.toList()..sort();
  for (final s in sortedStages) {
    out.add(RecordFilterOption(
      id: 'stage:$s',
      label: 'مرحلة $s',
      matches: (r) {
        final v = r.get<dynamic>('stage');
        return v is num && v.toInt() == s;
      },
    ));
  }
  return out;
}

List<RecordFilterOption> _sectionFilters(List<RecordModel> rows) {
  final out = <RecordFilterOption>[
    for (final p in periodOptions)
      RecordFilterOption(
        id: 'period:$p',
        label: periodLabelAr(p),
        matches: (r) => r.getStringValue('period') == p,
      ),
  ];
  final stages = <int>{};
  for (final r in rows) {
    final stage = r.get<dynamic>('stage');
    if (stage is num) stages.add(stage.toInt());
  }
  final sorted = stages.toList()..sort();
  for (final s in sorted) {
    out.add(RecordFilterOption(
      id: 'stage:$s',
      label: 'مرحلة $s',
      matches: (r) {
        final v = r.get<dynamic>('stage');
        return v is num && v.toInt() == s;
      },
    ));
  }
  return out;
}

List<RecordFilterOption> _mediaFilters() {
  return [
    RecordFilterOption(
      id: 'main',
      label: 'الوسط',
      matches: (r) => r.getBoolValue('main_only') || isVideoFileName(r.getStringValue('file')),
    ),
    RecordFilterOption(
      id: 'side',
      label: 'الجانب',
      matches: (r) => !r.getBoolValue('main_only') && !isVideoFileName(r.getStringValue('file')),
    ),
    RecordFilterOption(
      id: 'video',
      label: 'فيديو',
      matches: (r) => isVideoFileName(r.getStringValue('file')),
    ),
    RecordFilterOption(
      id: 'image',
      label: 'صور',
      matches: (r) => isImageFileName(r.getStringValue('file')),
    ),
  ];
}

/// Human-readable detail lines for a record sheet.
List<MapEntry<String, String>> recordDetailEntries(
  CollectionDef def,
  RecordModel r,
) {
  final out = <MapEntry<String, String>>[];
  for (final f in def.fields) {
    switch (f.kind) {
      case FieldKind.boolFlag:
        out.add(MapEntry(f.label, r.getBoolValue(f.key) ? 'نعم' : 'لا'));
      case FieldKind.period:
        final v = r.getStringValue(f.key);
        out.add(MapEntry(f.label, v.isEmpty ? '—' : periodLabelAr(v)));
      case FieldKind.file:
        final name = r.getStringValue(f.key);
        out.add(MapEntry(f.label, name.isEmpty ? '—' : name));
      default:
        final v = r.get<dynamic>(f.key);
        final t = v == null ? '' : '$v'.trim();
        out.add(MapEntry(f.label, t.isEmpty ? '—' : t));
    }
  }
  out.add(MapEntry('المعرّف', r.id));
  final created = r.getStringValue('created');
  if (created.isNotEmpty) out.add(MapEntry('أُنشئ', created));
  final updated = r.getStringValue('updated');
  if (updated.isNotEmpty) out.add(MapEntry('عُدّل', updated));
  return out;
}
