import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../collections.dart';
import '../filters.dart';
import '../pb.dart';
import '../theme.dart';
import '../upload.dart';

Future<void> showRecordDetailSheet({
  required BuildContext context,
  required PbSession session,
  required CollectionDef def,
  required RecordModel record,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: EceTheme.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _RecordDetailSheet(
      session: session,
      def: def,
      record: record,
      onEdit: () {
        Navigator.pop(ctx);
        onEdit();
      },
      onDelete: () {
        Navigator.pop(ctx);
        onDelete();
      },
    ),
  );
}

class _RecordDetailSheet extends StatelessWidget {
  const _RecordDetailSheet({
    required this.session,
    required this.def,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final PbSession session;
  final CollectionDef def;
  final RecordModel record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String? _fileUrl(String field) {
    final name = record.getStringValue(field);
    if (name.isEmpty) return null;
    try {
      return session.client.files.getUrl(record, name).toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = def.titleField;
    final title = titleKey == null
        ? def.title
        : (() {
            final v = record.get<dynamic>(titleKey);
            if (v == null || '$v'.isEmpty) return def.title;
            return '$v';
          })();
    final subtitle = recordSubtitle(def, record.data);
    final entries = recordDetailEntries(def, record);
    FieldDef? imageField;
    for (final f in def.fields) {
      if (f.kind == FieldKind.file) {
        imageField = f;
        break;
      }
    }
    final fileName = imageField == null ? '' : record.getStringValue(imageField.key);
    final url = imageField == null ? null : _fileUrl(imageField.key);
    final showImage = url != null && isImageFileName(fileName);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EceTheme.sand.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(def.icon, color: EceTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: EceTheme.sand.withValues(alpha: 0.65),
                    ),
              ),
            ],
            if (showImage) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: EceTheme.card,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ] else if (url != null && isVideoFileName(fileName)) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: EceTheme.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: EceTheme.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(color: EceTheme.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'التفاصيل',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        e.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: EceTheme.sand.withValues(alpha: 0.55),
                            ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        textDirection: e.key == 'المعرّف' ||
                                e.key.contains('أُنشئ') ||
                                e.key.contains('عُدّل') ||
                                e.value.contains('http')
                            ? TextDirection.ltr
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: EceTheme.danger),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
