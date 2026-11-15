import 'package:flutter/material.dart';

import 'pb.dart';
import 'screens/bootstrap_page.dart';
import 'screens/login_page.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EceAdminApp());
}

class EceAdminApp extends StatefulWidget {
  const EceAdminApp({super.key});

  @override
  State<EceAdminApp> createState() => _EceAdminAppState();
}

class _EceAdminAppState extends State<EceAdminApp> {
  final _session = PbSession();

  @override
  void initState() {
    super.initState();
    _session.bootstrap();
    _session.addListener(_onSession);
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!_session.ready) {
      home = Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF0B1614), Color(0xFF0F1C1A), Color(0xFF122824)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tv_rounded, color: Color(0xFF2BBBAD), size: 40),
                SizedBox(height: 16),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    } else if (!_session.isAuthed) {
      home = LoginPage(session: _session);
    } else if (_session.needsBootstrap) {
      home = BootstrapPage(session: _session);
    } else {
      home = AdminShell(session: _session);
    }

    return MaterialApp(
      title: 'ECE Admin',
      debugShowCheckedModeBanner: false,
      theme: EceTheme.dark(),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    );
  }
}
