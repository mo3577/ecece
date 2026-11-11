import 'package:flutter/material.dart';

import '../collections.dart';
import '../pb.dart';
import '../theme.dart';
import 'records_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.session});

  final PbSession session;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final def = collections[_index];

    final rail = NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      labelType: wide ? NavigationRailLabelType.all : NavigationRailLabelType.selected,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Icon(Icons.tv_rounded, color: EceTheme.accent, size: 28),
            const SizedBox(height: 8),
            Text(
              'ECE',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: EceTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
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
        for (final c in collections)
          NavigationRailDestination(icon: Icon(c.icon), label: Text(c.title)),
      ],
    );

    final body = RecordsPage(
      key: ValueKey(def.id),
      session: widget.session,
      def: def,
    );

    if (wide) {
      return Row(
        children: [
          rail,
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final c in collections)
            NavigationDestination(icon: Icon(c.icon), label: c.title),
        ],
      ),
    );
  }
}
