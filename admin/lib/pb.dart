import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUrl = 'ece_pb_url';
const _kToken = 'ece_pb_token';
const _kModel = 'ece_pb_model';
const _kAuthCol = 'ece_pb_auth_col';

/// PocketBase auth collection names used by the Flutter admin.
const authAdmins = 'Admins';
const authSuperusers = '_superusers';

enum AdminRole { superAdmin, admin }

class PbSession extends ChangeNotifier {
  PocketBase? _pb;
  String _baseUrl = 'http://127.0.0.1:8090';
  bool _ready = false;
  String? _error;
  String _authCollection = authAdmins;
  bool _needsBootstrap = false;

  PocketBase get client {
    final c = _pb;
    if (c == null) {
      throw StateError('PocketBase client not ready');
    }
    return c;
  }

  String get baseUrl => _baseUrl;
  bool get ready => _ready;
  bool get isAuthed => _pb?.authStore.isValid ?? false;
  String? get error => _error;
  bool get needsBootstrap => _needsBootstrap;
  String get authCollection => _authCollection;

  String? get email => _pb?.authStore.record?.getStringValue('email');
  String? get displayName {
    final r = _pb?.authStore.record;
    if (r == null) return null;
    final name = r.getStringValue('name');
    if (name.isNotEmpty) return name;
    return email;
  }

  /// `_superusers` emergency login counts as super; otherwise read `role`.
  AdminRole get role {
    if (_authCollection == authSuperusers) return AdminRole.superAdmin;
    final raw = _pb?.authStore.record?.getStringValue('role') ?? '';
    return raw == 'super' ? AdminRole.superAdmin : AdminRole.admin;
  }

  bool get isSuper => role == AdminRole.superAdmin;

  String get roleLabel => isSuper ? 'سوبر أدمن' : 'أدمن';

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kUrl) ?? _baseUrl;
    _pb = PocketBase(_baseUrl);
    _authCollection = prefs.getString(_kAuthCol) ?? authAdmins;
    final token = prefs.getString(_kToken);
    final model = prefs.getString(_kModel);
    if (token != null && token.isNotEmpty && model != null && model.isNotEmpty) {
      final map = jsonDecode(model);
      if (map is Map<String, dynamic>) {
        _pb!.authStore.save(token, RecordModel(map));
        try {
          await _pb!.collection(_authCollection).authRefresh();
        } catch (_) {
          _pb!.authStore.clear();
          await prefs.remove(_kToken);
          await prefs.remove(_kModel);
          await prefs.remove(_kAuthCol);
        }
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> login({
    required String url,
    required String email,
    required String password,
  }) async {
    _error = null;
    _needsBootstrap = false;
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = normalized.isEmpty ? 'http://127.0.0.1:8090' : normalized;
    _pb = PocketBase(_baseUrl);
    final trimmedEmail = email.trim();

    // Prefer Admins collection (role-aware). Fall back to PocketBase _superusers
    // for first-time bootstrap / recovery.
    try {
      await _pb!.collection(authAdmins).authWithPassword(trimmedEmail, password);
      await _persistAuth(authAdmins);
      notifyListeners();
      return;
    } catch (_) {
      // try superuser next
    }

    try {
      await _pb!.collection(authSuperusers).authWithPassword(trimmedEmail, password);
      await _persistAuth(authSuperusers);
      final count = await _adminsCount();
      _needsBootstrap = count == 0;
      notifyListeners();
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<int> _adminsCount() async {
    try {
      final result = await _pb!.collection(authAdmins).getList(page: 1, perPage: 1);
      return result.totalItems;
    } catch (_) {
      return -1;
    }
  }

  /// Create the first super admin while authenticated as `_superusers`.
  Future<void> createFirstSuperAdmin({
    required String email,
    required String password,
    String name = 'Super Admin',
  }) async {
    if (_authCollection != authSuperusers) {
      throw StateError('bootstrap requires _superusers session');
    }
    await client.collection(authAdmins).create(body: {
      'email': email.trim(),
      'password': password,
      'passwordConfirm': password,
      'name': name,
      'role': 'super',
      'emailVisibility': true,
      'verified': true,
    });
    // Re-login as the new Admins super so subsequent API calls use Admins rules.
    await client.collection(authAdmins).authWithPassword(email.trim(), password);
    await _persistAuth(authAdmins);
    _needsBootstrap = false;
    notifyListeners();
  }

  Future<void> _persistAuth(String collection) async {
    _authCollection = collection;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUrl, _baseUrl);
    await prefs.setString(_kToken, _pb!.authStore.token);
    await prefs.setString(_kAuthCol, collection);
    final record = _pb!.authStore.record;
    if (record != null) {
      await prefs.setString(_kModel, jsonEncode(record.toJson()));
    }
  }

  Future<void> logout() async {
    _pb?.authStore.clear();
    _needsBootstrap = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kModel);
    await prefs.remove(_kAuthCol);
    notifyListeners();
  }

  /// Best-effort activity log (ignored on failure so CRUD is not blocked).
  Future<void> logActivity({
    required String action,
    required String collection,
    String? recordId,
    String? summary,
  }) async {
    if (!isAuthed) return;
    try {
      await client.collection('AdminLogs').create(body: {
        'actor_email': email ?? '',
        'actor_role': isSuper ? 'super' : 'admin',
        'action': action,
        'collection': collection,
        'record_id': recordId ?? '',
        'summary': summary ?? '',
      });
    } catch (_) {
      // Superuser sessions may write via bypass; Admins always can create.
    }
  }

  String _friendly(Object e) {
    if (e is ClientException) {
      final msg = e.response['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      return 'فشل الدخول (${e.statusCode})';
    }
    return e.toString();
  }
}
