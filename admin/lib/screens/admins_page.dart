import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../pb.dart';
import '../theme.dart';
import '../widgets/ui_states.dart';

/// Super-only: list / create / edit / delete Admins operators.
class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key, required this.session, this.showAppBar = true});

  final PbSession session;
  final bool showAppBar;

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
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

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.session.client.collection(authAdmins).getFullList(
            sort: 'role,email',
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
      final blob = '${r.getStringValue('name')} ${r.getStringValue('email')} ${r.getStringValue('role')}'
          .toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  Future<void> _delete(RecordModel r) async {
    final email = r.getStringValue('email');
    final role = r.getStringValue('role');
    if (role == 'super') {
      final supers = _rows.where((e) => e.getStringValue('role') == 'super').length;
      if (supers <= 1) {
        showAppSnack(context, 'لا يمكن حذف آخر سوبر أدمن', error: true);
        return;
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المشغّل؟'),
        content: Text(email),
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
      await widget.session.client.collection(authAdmins).delete(r.id);
      await widget.session.logActivity(
        action: 'delete',
        collection: authAdmins,
        recordId: r.id,
        summary: email,
      );
      if (mounted) showAppSnack(context, 'تم حذف المشغّل');
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
      builder: (ctx) => _AdminEditorDialog(session: widget.session, existing: existing),
    );
    if (saved == true) {
      if (mounted) {
        showAppSnack(context, existing == null ? 'تمت إضافة المشغّل' : 'تم الحفظ');
      }
      await _reload();
    }
  }

  String _roleLabel(String role) => role == 'super' ? 'سوبر أدمن' : 'أدمن';

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('المشغّلون'),
              actions: [
                IconButton(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 8),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إضافة مشغّل'),
      ),
      body: Column(
        children: [
          if (!_loading && _error == null)
            ListSearchBar(
              controller: _search,
              hint: 'بحث بالاسم أو البريد…',
              onChanged: (_) => setState(() {}),
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
                                    icon: Icons.manage_accounts_rounded,
                                    title: 'لا يوجد مشغّلون',
                                    subtitle: 'أضف سوبر أدمن أو أدمن لإدارة الشاشة.',
                                    actionLabel: 'إضافة مشغّل',
                                    onAction: () => _openEditor(),
                                  ),
                                ),
                              ],
                            )
                          : filtered.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 120),
                                    EmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: 'لا نتائج',
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final r = filtered[i];
                                    final role = r.getStringValue('role');
                                    final name = r.getStringValue('name');
                                    final email = r.getStringValue('email');
                                    return Card(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: role == 'super'
                                              ? EceTheme.accent.withValues(alpha: 0.25)
                                              : EceTheme.panel,
                                          child: Icon(
                                            role == 'super'
                                                ? Icons.shield_rounded
                                                : Icons.person_rounded,
                                            color: EceTheme.accent,
                                          ),
                                        ),
                                        title: Text(name.isEmpty ? email : name),
                                        subtitle: Text('$email · ${_roleLabel(role)}'),
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

class _AdminEditorDialog extends StatefulWidget {
  const _AdminEditorDialog({required this.session, this.existing});

  final PbSession session;
  final RecordModel? existing;

  @override
  State<_AdminEditorDialog> createState() => _AdminEditorDialogState();
}

class _AdminEditorDialogState extends State<_AdminEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'admin';
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.getStringValue('name') ?? '');
    _email = TextEditingController(text: e?.getStringValue('email') ?? '');
    _role = e?.getStringValue('role') ?? 'admin';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final pass = _password.text;
      if (email.isEmpty) throw 'البريد مطلوب';
      if (widget.existing == null && pass.length < 8) {
        throw 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
      }
      if (pass.isNotEmpty && pass != _confirm.text) {
        throw 'كلمتا المرور غير متطابقتين';
      }

      final body = <String, dynamic>{
        'email': email,
        'name': _name.text.trim(),
        'role': _role,
        'emailVisibility': true,
        'verified': true,
      };
      if (pass.isNotEmpty) {
        body['password'] = pass;
        body['passwordConfirm'] = pass;
      }

      final col = widget.session.client.collection(authAdmins);
      if (widget.existing == null) {
        final created = await col.create(body: body);
        await widget.session.logActivity(
          action: 'create',
          collection: authAdmins,
          recordId: created.id,
          summary: '$email ($_role)',
        );
      } else {
        await col.update(widget.existing!.id, body: body);
        await widget.session.logActivity(
          action: 'update',
          collection: authAdmins,
          recordId: widget.existing!.id,
          summary: '$email ($_role)',
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'مشغّل جديد' : 'تعديل مشغّل'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'البريد'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'الدور'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('أدمن — كل المحتوى بلا مشغّلين/سجلات')),
                  DropdownMenuItem(value: 'super', child: Text('سوبر أدمن — صلاحيات كاملة')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _role = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: widget.existing == null ? 'كلمة المرور' : 'كلمة مرور جديدة (اختياري)',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: EceTheme.danger)),
              ],
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
