import 'package:flutter/material.dart';

import '../collections.dart';
import '../pb.dart';
import '../theme.dart';
import 'admins_page.dart';
import 'dashboard_page.dart';
import 'logs_page.dart';
import 'records_page.dart';

class _NavItem {
  const _NavItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.superOnly = false,
  });

  final String id;
  final String title;
  final IconData icon;
  final Widget Function(PbSession session, {required bool showAppBar}) builder;
  final bool superOnly;
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.session});

  final PbSession session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  int _refreshTick = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_NavItem> get _items {
    final items = <_NavItem>[
      _NavItem(
        id: '__home',
        title: 'الرئيسية',
        icon: Icons.dashboard_rounded,
        builder: (s, {required showAppBar}) => DashboardPage(
          session: s,
          showAppBar: showAppBar,
          onOpenCollection: _openById,
        ),
      ),
      for (final c in collections)
        _NavItem(
          id: c.id,
          title: c.title,
          icon: c.icon,
          builder: (s, {required showAppBar}) => RecordsPage(
            session: s,
            def: c,
            showAppBar: showAppBar,
          ),
        ),
      _NavItem(
        id: '__admins',
        title: 'المشغّلون',
        icon: Icons.manage_accounts_rounded,
        superOnly: true,
        builder: (s, {required showAppBar}) => AdminsPage(
          session: s,
          showAppBar: showAppBar,
        ),
      ),
      _NavItem(
        id: '__logs',
        title: 'السجلات',
        icon: Icons.history_rounded,
        superOnly: true,
        builder: (s, {required showAppBar}) => LogsPage(
          session: s,
          showAppBar: showAppBar,
        ),
      ),
    ];
    if (widget.session.isSuper) return items;
    return items.where((e) => !e.superOnly).toList();
  }

  /// Compact bottom destinations for phones (home + common edits + more drawer).
  List<_NavItem> get _mobilePrimary {
    final items = _items;
    final ids = {'__home', 'Schedules', 'Notices', 'Media'};
    return items.where((e) => ids.contains(e.id)).toList();
  }

  void _openById(String id) {
    final items = _items;
    final i = items.indexWhere((e) => e.id == id);
    if (i >= 0) setState(() => _index = i);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text('ستحتاج لتسجيل الدخول مرة أخرى لإدارة المحتوى.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_index >= items.length) _index = 0;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = KeyedSubtree(
      key: ValueKey('$_index-$_refreshTick'),
      child: items[_index].builder(widget.session, showAppBar: wide),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tv_rounded, color: EceTheme.accent, size: 28),
          const SizedBox(height: 8),
          Text(
            'ECE Admin',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EceTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.session.displayName ?? ''} · ${widget.session.roleLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EceTheme.sand.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.session.baseUrl,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: EceTheme.sand.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: header,
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تحديث',
                          onPressed: () => setState(() => _refreshTick++),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          tooltip: 'خروج',
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(icon: Icon(item.icon), label: Text(item.title)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    final primary = _mobilePrimary;
    final primaryIndex = () {
      final id = items[_index].id;
      final i = primary.indexWhere((e) => e.id == id);
      return i < 0 ? 0 : i;
    }();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(items[_index].title),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(() => _refreshTick++),
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                widget.session.roleLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: EceTheme.accent),
              ),
            ),
          ),
          IconButton(
            tooltip: 'خروج',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      ListTile(
                        selected: i == _index,
                        selectedTileColor: EceTheme.accent.withValues(alpha: 0.12),
                        leading: Icon(items[i].icon),
                        title: Text(items[i].title),
                        onTap: () {
                          setState(() => _index = i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: primaryIndex,
        onDestinationSelected: (i) {
          final id = primary[i].id;
          _openById(id);
        },
        destinations: [
          for (final item in primary)
            NavigationDestination(icon: Icon(item.icon), label: item.title),
        ],
      ),
    );
  }
}
