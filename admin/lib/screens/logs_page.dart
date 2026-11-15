import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../pb.dart';
import '../theme.dart';

/// Super-only activity log from `AdminLogs`.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.session, this.showAppBar = true});

  final PbSession session;
  final bool showAppBar;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<RecordModel> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.session.client.collection('AdminLogs').getList(
            page: 1,
            perPage: 200,
            sort: '-created',
          );
      if (!mounted) return;
      setState(() {
        _rows = list.items;
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

  String _actionAr(String a) {
    switch (a) {
      case 'create':
        return 'إضافة';
      case 'update':
        return 'تعديل';
      case 'delete':
        return 'حذف';
      default:
        return a;
    }
  }

  String _when(RecordModel r) {
    final raw = r.getStringValue('created');
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('سجل النشاط'),
              actions: [
                IconButton(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh_rounded)),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: EceTheme.danger)),
                  ),
                )
              : _rows.isEmpty
                  ? const Center(child: Text('لا توجد سجلات بعد'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        final action = r.getStringValue('action');
                        final collection = r.getStringValue('collection');
                        final actor = r.getStringValue('actor_email');
                        final role = r.getStringValue('actor_role');
                        final summary = r.getStringValue('summary');
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              action == 'delete'
                                  ? Icons.delete_outline_rounded
                                  : action == 'create'
                                      ? Icons.add_circle_outline_rounded
                                      : Icons.edit_outlined,
                              color: action == 'delete' ? EceTheme.danger : EceTheme.accent,
                            ),
                            title: Text('${_actionAr(action)} · $collection'),
                            subtitle: Text(
                              [
                                actor,
                                role == 'super' ? 'سوبر' : 'أدمن',
                                if (summary.isNotEmpty) summary,
                                _when(r),
                              ].where((e) => e.isNotEmpty).join(' · '),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
