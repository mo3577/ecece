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
  bool _obscure = true;
  String? _localError;
  String? _status;
  List<DiscoveredServer> _servers = [];

  @override
  void initState() {
    super.initState();
    _url.text = widget.session.baseUrl;
    _email.text = widget.session.lastEmail;
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
        _status = 'أدخل عنوان السيرفر يدوياً';
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
        _status =
            'ما لكينا سيرفر. تأكد أن ECE-screen شغّال، نفس الـ Wi‑Fi، '
            'وشغّل مرة: scripts\\\\windows\\\\allow-firewall.ps1 كـ Administrator. '
            'أو أدخل العنوان يدوياً: http://IP-الكمبيوتر:8090';
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
      await widget.session.rememberEmail(_email.text);
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
    final foundOk = _servers.isNotEmpty && !_searching;

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
                      const Icon(Icons.tv_rounded, color: EceTheme.accent, size: 40),
                      const SizedBox(height: 12),
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
                        'إدارة محتوى شاشة القسم — نفس شبكة الـ Wi‑Fi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: EceTheme.sand.withValues(alpha: 0.75),
                            ),
                      ),
                      const SizedBox(height: 20),
                      _DiscoveryBanner(
                        searching: _searching,
                        found: foundOk,
                        status: _status,
                        servers: _servers,
                        selectedUrl: _url.text,
                        onSelect: (url) => setState(() => _url.text = url),
                        onRetry: _searching ? null : _search,
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => setState(() => _showManualUrl = !_showManualUrl),
                          child: Text(_showManualUrl ? 'إخفاء العنوان اليدوي' : 'إدخال العنوان يدوياً'),
                        ),
                      ),
                      if (_showManualUrl) ...[
                        TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'عنوان السيرفر',
                            hintText: 'http://192.168.x.x:8090',
                            prefixIcon: Icon(Icons.link_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'البريد',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        onSubmitted: (_) => _busy ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'إظهار' : 'إخفاء',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
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
                        'الافتراضي أول مرة: admin@ece.local / admin12345\n'
                        'غيّر كلمة المرور بعد أول دخول.',
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

class _DiscoveryBanner extends StatelessWidget {
  const _DiscoveryBanner({
    required this.searching,
    required this.found,
    required this.status,
    required this.servers,
    required this.selectedUrl,
    required this.onSelect,
    required this.onRetry,
  });

  final bool searching;
  final bool found;
  final String? status;
  final List<DiscoveredServer> servers;
  final String selectedUrl;
  final ValueChanged<String> onSelect;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final border = found
        ? EceTheme.accent.withValues(alpha: 0.45)
        : searching
            ? EceTheme.sand.withValues(alpha: 0.2)
            : EceTheme.danger.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EceTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (searching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  found ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: found ? EceTheme.accent : EceTheme.danger,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: EceTheme.sand.withValues(alpha: 0.85),
                      ),
                ),
              ),
              IconButton(
                tooltip: 'إعادة البحث',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          if (servers.length == 1) ...[
            const SizedBox(height: 8),
            Text(
              servers.first.url,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: EceTheme.accent, fontWeight: FontWeight.w600),
            ),
          ],
          if (servers.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in servers)
                  ChoiceChip(
                    label: Text(s.url, textDirection: TextDirection.ltr),
                    selected: selectedUrl == s.url,
                    onSelected: (_) => onSelect(s.url),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
