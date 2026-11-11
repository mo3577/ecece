import 'package:flutter/material.dart';

import '../pb.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final PbSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _url = TextEditingController(text: 'http://127.0.0.1:8090');
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _url.text = widget.session.baseUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.session.login(
        url: _url.text,
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
                      'إدارة محتوى شاشة القسم عبر PocketBase',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: EceTheme.sand.withValues(alpha: 0.75),
                          ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _url,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'عنوان السيرفر',
                        hintText: 'http://192.168.x.x:8090',
                      ),
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
                      onPressed: _busy ? null : _submit,
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
                      'استخدم حساب الـ superuser الذي أنشأته عند أول تشغيل لـ ECE-screen.',
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
    );
  }
}
