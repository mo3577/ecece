import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUrl = 'ece_pb_url';
const _kToken = 'ece_pb_token';
const _kModel = 'ece_pb_model';

class PbSession extends ChangeNotifier {
  PocketBase? _pb;
  String _baseUrl = 'http://127.0.0.1:8090';
  bool _ready = false;
  String? _error;

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
  String? get email => _pb?.authStore.record?.getStringValue('email');

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kUrl) ?? _baseUrl;
    _pb = PocketBase(_baseUrl);
    final token = prefs.getString(_kToken);
    final model = prefs.getString(_kModel);
    if (token != null && token.isNotEmpty && model != null && model.isNotEmpty) {
      final map = jsonDecode(model);
      if (map is Map<String, dynamic>) {
        _pb!.authStore.save(token, RecordModel(map));
        try {
          await _pb!.collection('_superusers').authRefresh();
        } catch (_) {
          _pb!.authStore.clear();
          await prefs.remove(_kToken);
          await prefs.remove(_kModel);
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
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    _baseUrl = normalized.isEmpty ? 'http://127.0.0.1:8090' : normalized;
    _pb = PocketBase(_baseUrl);
    try {
      await _pb!.collection('_superusers').authWithPassword(email.trim(), password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUrl, _baseUrl);
      await prefs.setString(_kToken, _pb!.authStore.token);
      final record = _pb!.authStore.record;
      if (record != null) {
        await prefs.setString(_kModel, jsonEncode(record.toJson()));
      }
      notifyListeners();
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _pb?.authStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kModel);
    notifyListeners();
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
