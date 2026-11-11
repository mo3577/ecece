import 'package:flutter/material.dart';

import 'pb.dart';
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
    return MaterialApp(
      title: 'ECE Admin',
      debugShowCheckedModeBanner: false,
      theme: EceTheme.dark(),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: !_session.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _session.isAuthed
              ? AdminShell(session: _session)
              : LoginPage(session: _session),
    );
  }
}
