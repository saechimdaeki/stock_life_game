import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Hive 기반 로컬 세이브. 아침 시점 스냅샷(JSON)을 단일 슬롯에 저장한다.
class SaveRepository {
  static const _boxName = 'save';
  static const _slotKey = 'slot1';

  Box<String>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  bool get hasSave => _box?.containsKey(_slotKey) ?? false;

  Future<void> save(Map<String, dynamic> json) async {
    await _box?.put(_slotKey, jsonEncode(json));
  }

  Map<String, dynamic>? load() {
    final raw = _box?.get(_slotKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() async {
    await _box?.delete(_slotKey);
  }
}
