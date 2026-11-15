import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../collections.dart';
import '../filters.dart';
import '../pb.dart';
import '../theme.dart';
import '../upload.dart';
import '../widgets/record_detail_sheet.dart';
import '../widgets/ui_states.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.session,
    required this.def,
    this.showAppBar = true,
  });

  final PbSession session;
  final CollectionDef def;
  final bool showAppBar;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _search = TextEditingController();
  List<RecordModel> _rows = [];
  bool _loading = true;
  String? _error;
  String _activeFilter = 'all';
  String _sort = '';

  @override
  void initState() {
    super.initState();
    _sort = widget.def.sort;
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.def.id != widget.def.id) {
      _search.clear();
      _activeFilter = 'all';
      _sort = widget.def.sort;
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.session.client.collection(widget.def.id).getFullList(
            sort: _sort.isEmpty ? widget.def.sort : _sort,
          );
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ClientException
            ? (e.response['message']?.toString() ?? e.toString())
            : e.toString();
      });
    }
  }

  List<RecordFilterOption> get _filterOptions => filtersFor(widget.def, _rows);

  List<RecordModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    Iterable<RecordModel> list = _rows;
    if (_activeFilter != 'all') {
      final opt = _filterOptions.where((e) => e.id == _activeFilter);
      if (opt.isNotEmpty) {
        list = list.where(opt.first.matches);
      }
    }
    if (q.isEmpty) return list.toList();
    return list.where((r) {
      final title = _titleOf(r).toLowerCase();
      final sub = recordSubtitle(widget.def, r.data).toLowerCase();
      final blob = r.data.values.map((e) => '$e').join(' ').toLowerCase();
      return title.contains(q) || sub.contains(q) || blob.contains(q) || r.id.toLowerCase().contains(q);
    }).toList();
  }

  String _titleOf(RecordModel r) {
    final key = widget.def.titleField;
    if (key == null) return r.id;
    final v = r.get<dynamic>(key);
    if (v == null || '$v'.isEmpty) return r.id;
    return '$v';
  }

  String? _fileUrl(RecordModel r, String field) {
    final name = r.getStringValue(field);
    if (name.isEmpty) return null;
    try {
      return widget.session.client.files.getUrl(r, name).toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _delete(RecordModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: Text(_titleOf(r)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EceTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.client.collection(widget.def.id).delete(r.id);
      await widget.session.logActivity(
        action: 'delete',
        collection: widget.def.id,
        recordId: r.id,
        summary: _titleOf(r),
      );
      if (mounted) showAppSnack(context, 'تم الحذف');
      await _reload();
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          e is ClientException
              ? (e.response['message']?.toString() ?? 'فشل الحذف')
              : e.toString(),
          error: true,
        );
      }
    }
  }

  Future<void> _openEditor({RecordModel? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RecordEditorDialog(
        session: widget.session,
        def: widget.def,
        existing: existing,
      ),
    );
    if (saved == true) {
      if (mounted) {
        showAppSnack(context, existing == null ? 'تمت الإضافة' : 'تم الحفظ');
      }
      await _reload();
    }
  }

  Future<void> _openDetail(RecordModel r) async {
    await showRecordDetailSheet(
      context: context,
      session: widget.session,
      def: widget.def,
      record: r,
      onEdit: () => _openEditor(existing: r),
      onDelete: () => _delete(r),
    );
  }

  Widget? _leading(RecordModel r) {
    for (final f in widget.def.fields.where((e) => e.kind == FieldKind.file)) {
      final name = r.getStringValue(f.key);
      final url = _fileUrl(r, f.key);
      if (url == null) continue;
      if (isVideoFileName(name)) {
        return CircleAvatar(
          backgroundColor: EceTheme.panel,
          child: Icon(Icons.videocam_rounded, color: EceTheme.accent.withValues(alpha: 0.9)),
        );
      }
      if (!isImageFileName(name)) {
        return CircleAvatar(
          backgroundColor: EceTheme.panel,
          child: Icon(Icons.insert_drive_file_rounded, color: EceTheme.accent.withValues(alpha: 0.9)),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: EceTheme.panel,
      child: Icon(widget.def.icon, color: EceTheme.accent, size: 22),
    );
  }

  List<PopupMenuEntry<String>> _sortItems() {
    switch (widget.def.id) {
      case 'Schedules':
        return const [
          PopupMenuItem(value: 'day,stage,start_time', child: Text('اليوم ثم المرحلة')),
          PopupMenuItem(value: 'stage,day,start_time', child: Text('المرحلة ثم اليوم')),
          PopupMenuItem(value: '-created', child: Text('الأحدث أولاً')),
          PopupMenuItem(value: 'subject', child: Text('المادة أ→ي')),
        ];
      case 'Media':
        return const [
          PopupMenuItem(value: 'display_order', child: Text('الترتيب')),
          PopupMenuItem(value: '-created', child: Text('الأحدث أولاً')),
          PopupMenuItem(value: 'main_only', child: Text('الوسط أولاً')),
        ];
      case 'Professors':
      case 'Notices':
      case 'Stages':
      case 'Sections':
        return const [
          PopupMenuItem(value: 'display_order', child: Text('الترتيب')),
          PopupMenuItem(value: '-created', child: Text('الأحدث أولاً')),
        ];
      default:
        return const [
          PopupMenuItem(value: '-created', child: Text('الأحدث أولاً')),
          PopupMenuItem(value: 'created', child: Text('الأقدم أولاً')),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final filterOpts = _filterOptions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.def.title),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'ترتيب',
                  initialValue: _sort,
                  onSelected: (v) {
                    setState(() => _sort = v);
                    _reload();
                  },
                  itemBuilder: (_) => _sortItems(),
                  icon: const Icon(Icons.sort_rounded),
                ),
                IconButton(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 8),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة'),
      ),
      body: Column(
        children: [
          if (!_loading && _error == null) ...[
            ListSearchBar(
              controller: _search,
              hint: 'بحث في ${widget.def.title}…',
              onChanged: (_) => setState(() {}),
            ),
            if (filterOpts.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: const Text('الكل'),
                        selected: _activeFilter == 'all',
                        onSelected: (_) => setState(() => _activeFilter = 'all'),
                      ),
                    ),
                    for (final f in filterOpts)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(f.label),
                          selected: _activeFilter == f.id,
                          onSelected: (_) => setState(() => _activeFilter = f.id),
                        ),
                      ),
                  ],
                ),
              ),
            if (!widget.showAppBar)
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: 'ترتيب',
                  initialValue: _sort,
                  onSelected: (v) {
                    setState(() => _sort = v);
                    _reload();
                  },
                  itemBuilder: (_) => _sortItems(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded, size: 18, color: EceTheme.sand.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          'ترتيب',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: EceTheme.sand.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    filtered.length == _rows.length
                        ? '${_rows.length} سجل'
                        : '${filtered.length} من ${_rows.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: EceTheme.sand.withValues(alpha: 0.55),
                        ),
                  ),
                ),
              ),
          ],
          Expanded(
            child: RefreshIndicator(
              color: EceTheme.accent,
              onRefresh: _reload,
              child: _loading
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error != null
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.5,
                              child: ErrorState(message: _error!, onRetry: _reload),
                            ),
                          ],
                        )
                      : _rows.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.sizeOf(context).height * 0.5,
                                  child: EmptyState(
                                    icon: widget.def.icon,
                                    title: 'لا توجد سجلات بعد',
                                    subtitle: 'أضف أول عنصر ليظهر على الشاشة.',
                                    actionLabel: 'إضافة',
                                    onAction: () => _openEditor(),
                                  ),
                                ),
                              ],
                            )
                          : filtered.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.sizeOf(context).height * 0.45,
                                      child: EmptyState(
                                        icon: Icons.filter_alt_off_rounded,
                                        title: 'لا نتائج',
                                        subtitle: 'غيّر البحث أو الفلتر.',
                                        actionLabel: 'مسح الفلتر',
                                        onAction: () => setState(() {
                                          _search.clear();
                                          _activeFilter = 'all';
                                        }),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final r = filtered[i];
                                    final sub = recordSubtitle(widget.def, r.data);
                                    return Card(
                                      child: ListTile(
                                        leading: _leading(r),
                                        title: Text(
                                          _titleOf(r),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: sub.isEmpty
                                            ? null
                                            : Text(
                                                sub,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: EceTheme.sand.withValues(alpha: 0.55),
                                                  fontSize: 12,
                                                ),
                                              ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'تفاصيل',
                                              onPressed: () => _openDetail(r),
                                              icon: const Icon(Icons.info_outline_rounded),
                                            ),
                                            IconButton(
                                              tooltip: 'تعديل',
                                              onPressed: () => _openEditor(existing: r),
                                              icon: const Icon(Icons.edit_rounded),
                                            ),
                                            IconButton(
                                              tooltip: 'حذف',
                                              onPressed: () => _delete(r),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: EceTheme.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _openDetail(r),
                                      ),
                                    );
                                  },
                                ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordEditorDialog extends StatefulWidget {
  const _RecordEditorDialog({
    required this.session,
    required this.def,
    this.existing,
  });

  final PbSession session;
  final CollectionDef def;
  final RecordModel? existing;

  @override
  State<_RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<_RecordEditorDialog> {
  final _controllers = <String, TextEditingController>{};
  final _bools = <String, bool>{};
  final _files = <String, PlatformFile?>{};
  bool _busy = false;
  String? _error;
  /// null = idle; 0–1 while a file upload is in flight.
  double? _uploadProgress;
  int _uploadPercent = 0;

  @override
  void initState() {
    super.initState();
    for (final f in widget.def.fields) {
      switch (f.kind) {
        case FieldKind.boolFlag:
          _bools[f.key] = widget.existing?.getBoolValue(f.key) ?? false;
        case FieldKind.file:
          _files[f.key] = null;
        default:
          final raw = widget.existing?.get<dynamic>(f.key);
          _controllers[f.key] = TextEditingController(text: raw == null ? '' : '$raw');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  PickKind _pickKindFor(FieldDef f) {
    if (widget.def.id == 'Media' && f.key == 'file') return PickKind.media;
    if (f.key == 'image') return PickKind.image;
    return PickKind.any;
  }

  Future<void> _pickFile(String key, FieldDef field) async {
    try {
      final picked = await pickUploadFile(kind: _pickKindFor(field));
      if (picked == null) return;
      setState(() {
        _files[key] = picked;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Map<String, dynamic> _body() {
    final body = <String, dynamic>{};
    for (final f in widget.def.fields) {
      switch (f.kind) {
        case FieldKind.boolFlag:
          body[f.key] = _bools[f.key] ?? false;
        case FieldKind.number:
          final t = _controllers[f.key]?.text.trim() ?? '';
          if (t.isEmpty) {
            if (f.required) throw 'الحقل «${f.label}» مطلوب';
            continue;
          }
          final n = num.tryParse(t);
          if (n == null) throw '«${f.label}» يجب أن يكون رقماً';
          body[f.key] = n;
        case FieldKind.file:
          continue;
        case FieldKind.day:
        case FieldKind.period:
        case FieldKind.text:
          final t = _controllers[f.key]?.text.trim() ?? '';
          if (t.isEmpty && f.required) throw 'الحقل «${f.label}» مطلوب';
          if (t.isNotEmpty) body[f.key] = t;
      }
    }
    return body;
  }

  void _reportUploadFraction(double fraction) {
    final pct = (fraction * 100).floor().clamp(0, 100);
    if (!mounted) return;
    if (_uploadProgress != null && pct == _uploadPercent) return;
    setState(() {
      _uploadProgress = fraction.clamp(0.0, 1.0);
      _uploadPercent = pct;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _uploadProgress = null;
      _uploadPercent = 0;
    });
    try {
      final body = _body();
      final pending = <MapEntry<FieldDef, PlatformFile>>[];
      for (final f in widget.def.fields.where((e) => e.kind == FieldKind.file)) {
        final picked = _files[f.key];
        if (picked != null) {
          pending.add(MapEntry(f, picked));
        } else if (f.required && widget.existing == null) {
          throw 'اختر ملفاً لـ «${f.label}»';
        }
      }

      final sizes = [
        for (final e in pending) e.value.size > 0 ? e.value.size : (e.value.bytes?.length ?? 0),
      ];
      final totalBytes = sizes.fold<int>(0, (a, b) => a + b);
      final hasUpload = pending.isNotEmpty && totalBytes > 0;
      if (hasUpload) {
        setState(() {
          _uploadProgress = 0;
          _uploadPercent = 0;
        });
      }

      final files = <http.MultipartFile>[];
      var offset = 0;
      for (var i = 0; i < pending.length; i++) {
        final entry = pending[i];
        final size = sizes[i];
        final base = offset;
        offset += size;
        files.add(await toMultipartFile(
          entry.key.key,
          entry.value,
          onProgress: hasUpload
              ? uploadProgressAt(
                  byteOffset: base,
                  totalBytes: totalBytes,
                  onFraction: _reportUploadFraction,
                )
              : null,
        ));
      }

      final col = widget.session.client.collection(widget.def.id);
      if (widget.existing == null) {
        final created = await col.create(body: body, files: files);
        if (hasUpload) _reportUploadFraction(1);
        await widget.session.logActivity(
          action: 'create',
          collection: widget.def.id,
          recordId: created.id,
          summary: widget.def.title,
        );
      } else {
        await col.update(widget.existing!.id, body: body, files: files);
        if (hasUpload) _reportUploadFraction(1);
        await widget.session.logActivity(
          action: 'update',
          collection: widget.def.id,
          recordId: widget.existing!.id,
          summary: widget.def.title,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e is ClientException
            ? (e.response['message']?.toString() ?? e.toString())
            : e.toString();
        _uploadProgress = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (_error != null) _uploadProgress = null;
        });
      }
    }
  }

  Widget _field(FieldDef f) {
    switch (f.kind) {
      case FieldKind.boolFlag:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.hint == null ? null : Text(f.hint!),
          value: _bools[f.key] ?? false,
          onChanged: (v) => setState(() => _bools[f.key] = v),
        );
      case FieldKind.day:
        return DropdownButtonFormField<String>(
          initialValue: (_controllers[f.key]?.text.isNotEmpty ?? false)
              ? _controllers[f.key]!.text
              : null,
          decoration: InputDecoration(labelText: f.label),
          items: [
            for (final d in arabicDays) DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: (v) {
            if (v == null) return;
            _controllers[f.key]!.text = v;
            setState(() {});
          },
        );
      case FieldKind.period:
        return DropdownButtonFormField<String>(
          initialValue: (_controllers[f.key]?.text.isNotEmpty ?? false)
              ? _controllers[f.key]!.text
              : 'morning',
          decoration: InputDecoration(labelText: f.label),
          items: [
            for (final p in periodOptions)
              DropdownMenuItem(value: p, child: Text(periodLabelAr(p))),
          ],
          onChanged: (v) {
            if (v == null) return;
            _controllers[f.key]!.text = v;
            setState(() {});
          },
        );
      case FieldKind.file:
        final picked = _files[f.key];
        final existingName = widget.existing?.getStringValue(f.key);
        final sizeLabel = formatBytes(picked?.size);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(f.label, style: Theme.of(context).textTheme.labelLarge),
            if (f.hint != null) ...[
              const SizedBox(height: 4),
              Text(
                f.hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: EceTheme.sand.withValues(alpha: 0.55),
                    ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pickFile(f.key, f),
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(
                picked != null
                    ? '${picked.name}${sizeLabel.isEmpty ? '' : ' ($sizeLabel)'}'
                    : (existingName != null && existingName.isNotEmpty
                        ? 'الملف الحالي: $existingName'
                        : 'اختيار ملف'),
              ),
            ),
            if (widget.def.id == 'Media') ...[
              const SizedBox(height: 6),
              Text(
                'الفيديو يُرفع بشكل متدفق (بدون تحميل كامل في الذاكرة). يُفضّل MP4 H.264.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: EceTheme.sand.withValues(alpha: 0.5),
                    ),
              ),
            ],
          ],
        );
      case FieldKind.number:
      case FieldKind.text:
        return TextField(
          controller: _controllers[f.key],
          keyboardType: f.kind == FieldKind.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.multiline,
          maxLines: f.key == 'bio' || f.key == 'text' ? 4 : 1,
          decoration: InputDecoration(labelText: f.label, hintText: f.hint),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'سجل جديد — ${widget.def.title}' : 'تعديل — ${widget.def.title}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.def.fields) ...[
                _field(f),
                const SizedBox(height: 12),
              ],
              if (_uploadProgress != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'جاري الرفع…',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: EceTheme.accent,
                            ),
                      ),
                    ),
                    Text(
                      '$_uploadPercent%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: EceTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 10,
                    backgroundColor: EceTheme.ink.withValues(alpha: 0.45),
                    color: EceTheme.accent,
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (_busy) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(minHeight: 4),
                const SizedBox(height: 8),
                Text(
                  'جاري الحفظ…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: EceTheme.sand.withValues(alpha: 0.65),
                      ),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null)
                Text(_error!, style: const TextStyle(color: EceTheme.danger)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? Text(_uploadProgress != null ? 'رفع $_uploadPercent%' : 'حفظ…')
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
