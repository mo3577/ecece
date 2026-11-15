import 'package:flutter/material.dart';

import '../pb.dart';
import '../theme.dart';

/// Shown once when a PocketBase `_superusers` account signs in and no
/// `Admins` records exist yet — creates the first super admin.
class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key, required this.session});

  final PbSession session;

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  final _name = TextEditingController(text: 'Super Admin');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'البريد وكلمة المرور مطلوبان');
      return;
    }
    if (pass != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.createFirstSuperAdmin(
        email: email,
        password: pass,
        name: _name.text.trim().isEmpty ? 'Super Admin' : _name.text.trim(),
      );
    } catch (e) {
      setState(() => _error = e.toString());
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
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إنشاء سوبر أدمن',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: EceTheme.accent,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا يوجد حسابات في مجموعة Admins بعد. أنشئ أول سوبر أدمن لإدارة الشاشة والمشغّلين.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: EceTheme.sand.withValues(alpha: 0.75),
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'الاسم'),
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
                      decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: EceTheme.danger)),
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
                          : const Text('إنشاء والمتابعة'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => widget.session.logout(),
                      child: const Text('إلغاء / خروج'),
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
