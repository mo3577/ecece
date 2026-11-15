import 'package:flutter/material.dart';

import '../discovery.dart';
import '../pb.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final PbSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _searching = false;
  bool _showManualUrl = false;
  String? _localError;
  String? _status;
  List<DiscoveredServer> _servers = [];

  @override
  void initState() {
    super.initState();
    _url.text = widget.session.baseUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!discoverySupported) {
      setState(() {
        _showManualUrl = true;
        _status = 'أدخل عنوان السيرفر يدوياً (هذا الجهاز لا يدعم البحث التلقائي)';
      });
      return;
    }
    setState(() {
      _searching = true;
      _localError = null;
      _status = 'جاري البحث عن شاشة ECE على الشبكة…';
      _servers = [];
    });
    final found = await discoverServers();
    if (!mounted) return;
    setState(() {
      _searching = false;
      _servers = found;
      if (found.isEmpty) {
        _status = 'ما لكينا سيرفر. تأكد أن الشاشة شغّالة وأن الموبايل على نفس الـ Wi‑Fi.';
        _showManualUrl = true;
      } else if (found.length == 1) {
        _url.text = found.first.url;
        _status = 'تم العثور على السيرفر';
        _showManualUrl = false;
      } else {
        _url.text = found.first.url;
        _status = 'وُجد أكثر من سيرفر — اختر واحداً';
        _showManualUrl = false;
      }
    });
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _localError = 'انتظر البحث أو أدخل عنوان السيرفر');
      return;
    }
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.session.login(
        url: url,
        email: _email.text,
        password: _password.text,
      );
    } catch (_) {
      setState(() => _localError = widget.session.error ?? 'تعذر تسجيل الدخول');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0B1614), EceTheme.ink, Color(0xFF122824)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ECE Admin',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: EceTheme.accent,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة محتوى الشاشة — نفس شبكة الـ Wi‑Fi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: EceTheme.sand.withValues(alpha: 0.75),
                            ),
                      ),
                      const SizedBox(height: 20),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_status != null) ...[
                        Text(
                          _status!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: EceTheme.sand.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_servers.length > 1) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final s in _servers)
                              ChoiceChip(
                                label: Text(s.url, textDirection: TextDirection.ltr),
                                selected: _url.text == s.url,
                                onSelected: (_) => setState(() => _url.text = s.url),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_servers.length == 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: EceTheme.panel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: EceTheme.accent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            _servers.first.url,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: EceTheme.accent),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: _searching ? null : _search,
                          icon: const Icon(Icons.wifi_find_rounded, size: 18),
                          label: const Text('إعادة البحث'),
                        ),
                      ),
                      if (_showManualUrl) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'عنوان السيرفر (يدوي)',
                            hintText: 'http://192.168.x.x:8090',
                          ),
                        ),
                      ] else
                        TextButton(
                          onPressed: () => setState(() => _showManualUrl = true),
                          child: const Text('إدخال العنوان يدوياً'),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(labelText: 'البريد'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        onSubmitted: (_) => _busy ? null : _submit(),
                        decoration: const InputDecoration(labelText: 'كلمة المرور'),
                      ),
                      if (_localError != null) ...[
                        const SizedBox(height: 12),
                        Text(_localError!, style: const TextStyle(color: EceTheme.danger)),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy || _searching ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('دخول'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'التطبيق يبحث تلقائياً عن الشاشة على نفس الشبكة.\n'
                        'حساب Admins (سوبر/أدمن). أول مرة: PocketBase superuser.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: EceTheme.sand.withValues(alpha: 0.55),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
