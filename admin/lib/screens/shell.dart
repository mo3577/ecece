import 'package:flutter/material.dart';

import '../collections.dart';
import '../pb.dart';
import '../theme.dart';
import 'admins_page.dart';
import 'logs_page.dart';
import 'records_page.dart';

class _NavItem {
  const _NavItem({
    required this.title,
    required this.icon,
    required this.builder,
    this.superOnly = false,
  });

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
      for (final c in collections)
        _NavItem(
          title: c.title,
          icon: c.icon,
          builder: (s, {required showAppBar}) => RecordsPage(
            session: s,
            def: c,
            showAppBar: showAppBar,
          ),
        ),
      _NavItem(
        title: 'المشغّلون',
        icon: Icons.manage_accounts_rounded,
        superOnly: true,
        builder: (s, {required showAppBar}) => AdminsPage(
          session: s,
          showAppBar: showAppBar,
        ),
      ),
      _NavItem(
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
        ],
      ),
    );

    if (wide) {
      return Row(
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
                  child: IconButton(
                    tooltip: 'خروج',
                    onPressed: () => widget.session.logout(),
                    icon: const Icon(Icons.logout_rounded),
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
      );
    }

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
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: EceTheme.panel,
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
    );
  }
}
