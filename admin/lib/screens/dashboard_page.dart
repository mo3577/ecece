import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../collections.dart';
import '../pb.dart';
import '../theme.dart';
import '../widgets/ui_states.dart';

/// Home overview: collection counts + quick jump.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    required this.onOpenCollection,
    this.showAppBar = true,
  });

  final PbSession session;
  final void Function(String collectionId) onOpenCollection;
  final bool showAppBar;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _counts = <String, int>{};
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
      final next = <String, int>{};
      for (final c in collections) {
        try {
          final page = await widget.session.client.collection(c.id).getList(
                page: 1,
                perPage: 1,
              );
          next[c.id] = page.totalItems;
        } catch (_) {
          next[c.id] = -1;
        }
      }
      if (!mounted) return;
      setState(() {
        _counts
          ..clear()
          ..addAll(next);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('لوحة التحكم'),
              actions: [
                IconButton(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: RefreshIndicator(
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
                        height: MediaQuery.sizeOf(context).height * 0.55,
                        child: ErrorState(message: _error!, onRetry: _reload),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _WelcomeBanner(session: widget.session),
                      const SizedBox(height: 16),
                      Text(
                        'المحتوى',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 640;
                          final cross = wide ? 3 : 2;
                          return GridView.count(
                            crossAxisCount: cross,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: wide ? 1.55 : 1.35,
                            children: [
                              for (final c in collections)
                                _CountTile(
                                  def: c,
                                  count: _counts[c.id] ?? 0,
                                  onTap: () => widget.onOpenCollection(c.id),
                                ),
                            ],
                          );
                        },
                      ),
                      if (widget.session.isSuper) ...[
                        const SizedBox(height: 20),
                        Text(
                          'الإدارة',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        _AdminShortcut(
                          icon: Icons.manage_accounts_rounded,
                          title: 'المشغّلون',
                          subtitle: 'إضافة وتعديل حسابات الأدمن',
                          onTap: () => widget.onOpenCollection('__admins'),
                        ),
                        const SizedBox(height: 8),
                        _AdminShortcut(
                          icon: Icons.history_rounded,
                          title: 'سجل النشاط',
                          subtitle: 'من عدّل ماذا ومتى',
                          onTap: () => widget.onOpenCollection('__logs'),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.session});

  final PbSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            EceTheme.accent.withValues(alpha: 0.22),
            EceTheme.panel,
          ],
        ),
        border: Border.all(color: EceTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مرحباً، ${session.displayName ?? 'مشغّل'}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${session.roleLabel} · متصل بـ ${session.baseUrl}',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EceTheme.sand.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر قسماً لتعديل محتوى الشاشة. التغييرات تظهر مباشرة على اللوحة.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: EceTheme.sand.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.def,
    required this.count,
    required this.onTap,
  });

  final CollectionDef def;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count < 0 ? '—' : '$count';
    return Material(
      color: EceTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(def.icon, color: EceTheme.accent),
              const Spacer(),
              Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: EceTheme.accent,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                def.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminShortcut extends StatelessWidget {
  const _AdminShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EceTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: EceTheme.accent),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
      ),
    );
  }
}
