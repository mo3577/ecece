import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../collections.dart';
import '../pb.dart';
import '../theme.dart';
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

  @override
  void initState() {
    super.initState();
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
            sort: widget.def.sort,
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

  List<RecordModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((r) {
      final title = _titleOf(r).toLowerCase();
      final sub = recordSubtitle(widget.def, r.data).toLowerCase();
      return title.contains(q) || sub.contains(q) || r.id.toLowerCase().contains(q);
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

  Widget? _leading(RecordModel r) {
    for (final f in widget.def.fields.where((e) => e.kind == FieldKind.file)) {
      final url = _fileUrl(r, f.key);
      if (url == null) continue;
      final lower = url.toLowerCase();
      final isImage = lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif');
      if (!isImage) {
        return CircleAvatar(
          backgroundColor: EceTheme.panel,
          child: Icon(Icons.videocam_rounded, color: EceTheme.accent.withValues(alpha: 0.9)),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.def.title),
              actions: [
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
          if (!_loading && _error == null)
            ListSearchBar(
              controller: _search,
              hint: 'بحث في ${widget.def.title}…',
              onChanged: (_) => setState(() {}),
            ),
          if (!_loading && _error == null && _rows.isNotEmpty)
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
                                        icon: Icons.search_off_rounded,
                                        title: 'لا نتائج للبحث',
                                        subtitle: 'جرّب كلمة أخرى أو امسح البحث.',
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
                                        onTap: () => _openEditor(existing: r),
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

  Future<void> _pickFile(String key) async {
    final res = await FilePicker.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    setState(() => _files[key] = res.files.first);
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
          body[f.key] = num.parse(t);
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

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = _body();
      final files = <http.MultipartFile>[];
      for (final f in widget.def.fields.where((e) => e.kind == FieldKind.file)) {
        final picked = _files[f.key];
        if (picked?.bytes != null) {
          files.add(http.MultipartFile.fromBytes(
            f.key,
            picked!.bytes!,
            filename: picked.name,
          ));
        } else if (f.required && widget.existing == null) {
          throw 'اختر ملفاً لـ «${f.label}»';
        }
      }

      final col = widget.session.client.collection(widget.def.id);
      if (widget.existing == null) {
        final created = await col.create(body: body, files: files);
        await widget.session.logActivity(
          action: 'create',
          collection: widget.def.id,
          recordId: created.id,
          summary: widget.def.title,
        );
      } else {
        await col.update(widget.existing!.id, body: body, files: files);
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
      });
    } finally {
      if (mounted) setState(() => _busy = false);
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
              onPressed: () => _pickFile(f.key),
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(
                picked?.name ??
                    (existingName != null && existingName.isNotEmpty
                        ? 'الملف الحالي: $existingName'
                        : 'اختيار ملف'),
              ),
            ),
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
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
