import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../collections.dart';
import '../pb.dart';
import '../theme.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.session, required this.def});

  final PbSession session;
  final CollectionDef def;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<RecordModel> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant RecordsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.def.id != widget.def.id) {
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

  String _titleOf(RecordModel r) {
    final key = widget.def.titleField;
    if (key == null) return r.id;
    final v = r.get<dynamic>(key);
    if (v == null || '$v'.isEmpty) return r.id;
    return '$v';
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
    await widget.session.client.collection(widget.def.id).delete(r.id);
    await _reload();
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
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.def.title),
        actions: [
          IconButton(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة'),
        backgroundColor: EceTheme.accent,
        foregroundColor: EceTheme.ink,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: EceTheme.danger)),
                ))
              : _rows.isEmpty
                  ? const Center(child: Text('لا توجد سجلات بعد'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return Card(
                          child: ListTile(
                            title: Text(_titleOf(r), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              r.id,
                              style: TextStyle(color: EceTheme.sand.withValues(alpha: 0.45), fontSize: 12),
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
                                  icon: const Icon(Icons.delete_outline_rounded, color: EceTheme.danger),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
          // file goes via multipart
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
        await col.create(body: body, files: files);
      } else {
        await col.update(widget.existing!.id, body: body, files: files);
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
            for (final p in periodOptions) DropdownMenuItem(value: p, child: Text(p)),
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
      title: Text(widget.existing == null ? 'سجل جديد' : 'تعديل سجل'),
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
