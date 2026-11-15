import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';

import '../pb.dart';
import '../theme.dart';
import '../widgets/ui_states.dart';

/// Super-only activity log from `AdminLogs`.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.session, this.showAppBar = true});

  final PbSession session;
  final bool showAppBar;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _search = TextEditingController();
  List<RecordModel> _rows = [];
  bool _loading = true;
  String? _error;
  String _actionFilter = 'all';

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

  List<RecordModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _rows.where((r) {
      final action = r.getStringValue('action');
      if (_actionFilter != 'all' && action != _actionFilter) return false;
      if (q.isEmpty) return true;
      final blob = [
        action,
        r.getStringValue('collection'),
        r.getStringValue('actor_email'),
        r.getStringValue('summary'),
      ].join(' ').toLowerCase();
      return blob.contains(q);
    }).toList();
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
    final filtered = _filtered;

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
      body: Column(
        children: [
          if (!_loading && _error == null) ...[
            ListSearchBar(
              controller: _search,
              hint: 'بحث في السجلات…',
              onChanged: (_) => setState(() {}),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const [
                    ('all', 'الكل'),
                    ('create', 'إضافة'),
                    ('update', 'تعديل'),
                    ('delete', 'حذف'),
                  ])
                    FilterChip(
                      label: Text(entry.$2),
                      selected: _actionFilter == entry.$1,
                      onSelected: (_) => setState(() => _actionFilter = entry.$1),
                    ),
                ],
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
                              children: const [
                                SizedBox(height: 120),
                                EmptyState(
                                  icon: Icons.history_rounded,
                                  title: 'لا توجد سجلات بعد',
                                  subtitle: 'ستظهر هنا عمليات الإضافة والتعديل والحذف.',
                                ),
                              ],
                            )
                          : filtered.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 120),
                                    EmptyState(
                                      icon: Icons.search_off_rounded,
                                      title: 'لا نتائج لهذا التصفية',
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final r = filtered[i];
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
                                          color: action == 'delete'
                                              ? EceTheme.danger
                                              : EceTheme.accent,
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
            ),
          ),
        ],
      ),
    );
  }
}
